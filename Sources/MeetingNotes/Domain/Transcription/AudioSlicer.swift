import AVFoundation
import Foundation

/// 一个音频切片（需求 9.1）。
///
/// 切片按录音原始时间顺序排列，`index` 从 0 递增，供后续逐片转写与按序合并使用
/// （任务 8.2 / Property 2「切片转写顺序一致」）。
struct AudioSlice: Equatable {
    /// 切片序号，从 0 开始，与录音时间轴顺序一致。
    let index: Int
    /// 切片对应的 WAV 文件地址。单切片场景下即原始音频地址。
    let url: URL
    /// 切片时长（秒）。
    let duration: TimeInterval
}

/// 音频切片能力协议（需求 9.1）。
///
/// 当录音时长超过转写服务单次处理上限时，按时长阈值把音频切分为多个有序切片；
/// 未超限时返回单个切片（即原始音频本身，不做无谓拷贝）。
protocol AudioSlicing {
    /// 按单片时长上限切分音频。
    ///
    /// - Parameters:
    ///   - audioURL: 待切分的 WAV 音频地址（16kHz / 单声道 / 16bit PCM）。
    ///   - maxSliceDuration: 单片时长上限（秒），默认 `AudioSlicer.defaultMaxSliceDuration`。
    /// - Returns: 按原始时间顺序排列的切片数组，`index` 从 0 递增。
    ///   时长在上限以内时返回单元素数组（原始音频）。
    /// - Throws: `AudioSlicingError` 描述阈值非法、读写失败等异常。
    func slice(_ audioURL: URL, maxSliceDuration: TimeInterval) throws -> [AudioSlice]
}

extension AudioSlicing {
    /// 便捷重载：使用默认单片时长上限切分。
    func slice(_ audioURL: URL) throws -> [AudioSlice] {
        try slice(audioURL, maxSliceDuration: AudioSlicer.defaultMaxSliceDuration)
    }
}

/// 音频切片过程中可能抛出的错误（需求 9.1）。
enum AudioSlicingError: Error, Equatable {
    /// 单片时长上限非法（必须为正数）。
    case invalidThreshold
    /// 打开源音频文件失败，附带底层错误描述。
    case cannotOpenSource(reason: String)
    /// 创建切片输出目录失败，附带底层错误描述。
    case cannotCreateOutputDirectory(reason: String)
    /// 写入切片文件失败，附带底层错误描述。
    case sliceWriteFailed(reason: String)
    /// 无法分配音频缓冲区（理论上不应发生，属环境异常）。
    case bufferAllocationFailed
}

/// 基于 `AVAudioFile` 的音频切片实现（需求 9.1）。
///
/// 设计要点：
/// - 时长在单片上限以内（含恰好相等）时返回单切片，直接复用原始文件，不产生拷贝。
/// - 超限时按 PCM 帧范围切分，逐片以原文件格式写出为独立且有效的 WAV 文件，
///   保持每片时长 ≤ 上限，最后一片承载余量。
/// - 切分以帧数为基准比较而非浮点时长，规避「恰好等于上限」处的浮点误差。
final class AudioSlicer: AudioSlicing {
    /// 默认单片时长上限：20 分钟（设计文档：可配置的时长阈值）。
    static let defaultMaxSliceDuration: TimeInterval = 20 * 60

    /// 单次读写的分块帧数上限，用于约束内存占用（约 1 秒音频一块）。
    /// 与切片边界无关，仅影响每次读入缓冲区的大小。
    private let readChunkSeconds: Double

    /// - Parameter readChunkSeconds: 单次读写分块对应的秒数，默认 1 秒。
    init(readChunkSeconds: Double = 1.0) {
        self.readChunkSeconds = max(0.1, readChunkSeconds)
    }

    func slice(_ audioURL: URL, maxSliceDuration: TimeInterval) throws -> [AudioSlice] {
        guard maxSliceDuration > 0, maxSliceDuration.isFinite else {
            throw AudioSlicingError.invalidThreshold
        }

        let inputFile: AVAudioFile
        do {
            inputFile = try AVAudioFile(forReading: audioURL)
        } catch {
            throw AudioSlicingError.cannotOpenSource(reason: error.localizedDescription)
        }

        let format = inputFile.processingFormat
        let sampleRate = format.sampleRate
        let totalFrames = inputFile.length

        guard sampleRate > 0, totalFrames > 0 else {
            // 空音频或采样率异常：作为单切片返回原始文件，交由上层判断。
            let duration = sampleRate > 0 ? Double(totalFrames) / sampleRate : 0
            return [AudioSlice(index: 0, url: audioURL, duration: duration)]
        }

        // 以帧数为基准比较，避免浮点时长在边界处的误差。
        let framesPerSlice = AVAudioFramePosition((maxSliceDuration * sampleRate).rounded())
        guard framesPerSlice > 0 else {
            throw AudioSlicingError.invalidThreshold
        }

        // 时长在上限以内（含恰好相等）→ 单切片，直接复用原始文件。
        if totalFrames <= framesPerSlice {
            return [AudioSlice(index: 0, url: audioURL, duration: Double(totalFrames) / sampleRate)]
        }

        let outputDirectory = try makeOutputDirectory(for: audioURL)
        return try writeSlices(
            from: inputFile,
            format: format,
            sampleRate: sampleRate,
            totalFrames: totalFrames,
            framesPerSlice: framesPerSlice,
            into: outputDirectory
        )
    }

    // MARK: - 私有实现

    /// 在源文件同目录下创建切片输出目录：`<源文件名>-slices/`。
    private func makeOutputDirectory(for audioURL: URL) throws -> URL {
        let baseName = audioURL.deletingPathExtension().lastPathComponent
        let directory = audioURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(baseName)-slices", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            throw AudioSlicingError.cannotCreateOutputDirectory(reason: error.localizedDescription)
        }
        return directory
    }

    /// 按帧范围逐片读取并写出独立 WAV 文件。
    private func writeSlices(
        from inputFile: AVAudioFile,
        format: AVAudioFormat,
        sampleRate: Double,
        totalFrames: AVAudioFramePosition,
        framesPerSlice: AVAudioFramePosition,
        into outputDirectory: URL
    ) throws -> [AudioSlice] {
        // 沿用源文件的编码设置（16bit PCM WAV），保证每片仍是有效 WAV。
        let outputSettings = inputFile.fileFormat.settings
        let chunkCapacity = AVAudioFrameCount(max(1, Int((Double(sampleRate) * readChunkSeconds).rounded())))

        var slices: [AudioSlice] = []
        var sliceIndex = 0
        var framePosition: AVAudioFramePosition = 0

        while framePosition < totalFrames {
            let sliceBudget = min(framesPerSlice, totalFrames - framePosition)
            let sliceURL = outputDirectory.appendingPathComponent(
                String(format: "slice-%03d.wav", sliceIndex)
            )
            if FileManager.default.fileExists(atPath: sliceURL.path) {
                try? FileManager.default.removeItem(at: sliceURL)
            }

            let outputFile: AVAudioFile
            do {
                outputFile = try AVAudioFile(
                    forWriting: sliceURL,
                    settings: outputSettings,
                    commonFormat: format.commonFormat,
                    interleaved: format.isInterleaved
                )
            } catch {
                throw AudioSlicingError.sliceWriteFailed(reason: error.localizedDescription)
            }

            let written = try copyFrames(
                from: inputFile,
                to: outputFile,
                format: format,
                startFrame: framePosition,
                frameBudget: sliceBudget,
                chunkCapacity: chunkCapacity
            )

            // 写入 0 帧属异常，跳出避免死循环。
            guard written > 0 else { break }

            slices.append(
                AudioSlice(
                    index: sliceIndex,
                    url: sliceURL,
                    duration: Double(written) / sampleRate
                )
            )
            framePosition += written
            sliceIndex += 1
        }

        return slices
    }

    /// 从源文件指定位置起，分块读取 `frameBudget` 帧写入目标文件，返回实际写入帧数。
    private func copyFrames(
        from inputFile: AVAudioFile,
        to outputFile: AVAudioFile,
        format: AVAudioFormat,
        startFrame: AVAudioFramePosition,
        frameBudget: AVAudioFramePosition,
        chunkCapacity: AVAudioFrameCount
    ) throws -> AVAudioFramePosition {
        var written: AVAudioFramePosition = 0
        while written < frameBudget {
            let remaining = frameBudget - written
            let toRead = AVAudioFrameCount(min(AVAudioFramePosition(chunkCapacity), remaining))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: toRead) else {
                throw AudioSlicingError.bufferAllocationFailed
            }
            inputFile.framePosition = startFrame + written
            do {
                try inputFile.read(into: buffer, frameCount: toRead)
            } catch {
                throw AudioSlicingError.sliceWriteFailed(reason: error.localizedDescription)
            }
            let frameLength = AVAudioFramePosition(buffer.frameLength)
            guard frameLength > 0 else { break }
            do {
                try outputFile.write(from: buffer)
            } catch {
                throw AudioSlicingError.sliceWriteFailed(reason: error.localizedDescription)
            }
            written += frameLength
            // 读到的帧少于请求帧，说明已到文件尾，结束。
            if buffer.frameLength < toRead { break }
        }
        return written
    }
}
