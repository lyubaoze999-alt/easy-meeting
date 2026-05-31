import AVFoundation
import CoreAudio
import Foundation

/// 系统声音采集：基于 Core Audio Process Tap（macOS 14.4+）。
///
/// 工作原理（设计文档「系统声音用 AudioHardwareCreateProcessTap」）：
/// 1. 用 `CATapDescription`（全局混音、排除空进程列表 = 采集所有进程输出）创建进程 Tap；
/// 2. 把该 Tap 包进一个私有聚合设备（aggregate device）；
/// 3. 在聚合设备上注册 IO Block，回调里拿到系统混音 PCM，转交给上层（写入环形缓冲）。
///
/// 该能力要求真实硬件 + 屏幕录制权限，且仅 macOS 14.4+ 可用。在不满足条件时
/// `start` 抛出 `AudioCaptureError.systemTapUnavailable`，由上层决定是否降级为仅麦克风。
///
/// - Note: 真机相关的权限链与硬件采集无法在无人值守环境验证，属设计文档「手动验证」范围。
@available(macOS 14.4, *)
final class SystemAudioTap {

    /// 系统声音 PCM 回调：参数为 Tap 输出的原生格式与对应的 AudioBufferList。
    typealias SampleHandler = (_ buffers: UnsafePointer<AudioBufferList>, _ frames: AVAudioFrameCount, _ format: AVAudioFormat) -> Void

    private var tapID: AudioObjectID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateDeviceID: AudioObjectID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var tapStreamFormat: AVAudioFormat?
    private let ioQueue = DispatchQueue(label: "com.meetingnotes.systemtap.io")
    private var sampleHandler: SampleHandler?

    /// Tap 输出的音频格式（创建成功后可用），供上层构造转换器。
    var streamFormat: AVAudioFormat? { tapStreamFormat }

    /// 创建并启动系统声音 Tap。
    /// - Parameter onSamples: 每个 IO 周期回调一次，提供系统混音 PCM。
    /// - Throws: `AudioCaptureError.systemTapUnavailable`，当 Tap 或聚合设备创建失败时。
    func start(onSamples: @escaping SampleHandler) throws {
        self.sampleHandler = onSamples

        // 1) 创建全局进程 Tap：排除进程列表为空 => 采集所有正在播放的进程输出。
        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        description.isPrivate = true
        description.muteBehavior = .unmuted

        var newTapID = AudioObjectID(kAudioObjectUnknown)
        let tapStatus = AudioHardwareCreateProcessTap(description, &newTapID)
        guard tapStatus == noErr else {
            throw AudioCaptureError.systemTapUnavailable(status: tapStatus)
        }
        tapID = newTapID

        // 读取 Tap 的输出格式，供上层做重采样转换。
        if let format = readTapStreamFormat(tapID: newTapID) {
            tapStreamFormat = format
        }

        // 2) 把 Tap 包进一个私有聚合设备。
        do {
            aggregateDeviceID = try createAggregateDevice(wrapping: newTapID)
        } catch {
            cleanupTap()
            throw error
        }

        // 3) 在聚合设备上注册 IO Block 并启动。
        do {
            try startIO(on: aggregateDeviceID)
        } catch {
            cleanup()
            throw error
        }
    }

    /// 停止并销毁 Tap 与聚合设备，释放所有 Core Audio 资源。
    func stop() {
        cleanup()
    }

    // MARK: - 私有：Tap 输出格式

    private func readTapStreamFormat(tapID: AudioObjectID) -> AVAudioFormat? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var asbd = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let status = AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &asbd)
        guard status == noErr else { return nil }
        return AVAudioFormat(streamDescription: &asbd)
    }

    // MARK: - 私有：聚合设备

    private func createAggregateDevice(wrapping tapID: AudioObjectID) throws -> AudioObjectID {
        // 读取 Tap UID（聚合设备用它登记子 Tap）。
        guard let tapUID = readTapUID(tapID: tapID) else {
            throw AudioCaptureError.systemTapUnavailable(status: kAudioHardwareUnspecifiedError)
        }

        let aggregateUID = "com.meetingnotes.aggregate.\(UUID().uuidString)"
        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey as String: "MeetingNotes System Capture",
            kAudioAggregateDeviceUIDKey as String: aggregateUID,
            kAudioAggregateDeviceIsPrivateKey as String: true,
            kAudioAggregateDeviceIsStackedKey as String: false,
            kAudioAggregateDeviceTapAutoStartKey as String: true,
            kAudioAggregateDeviceSubDeviceListKey as String: [],
            kAudioAggregateDeviceTapListKey as String: [
                [
                    kAudioSubTapDriftCompensationKey as String: true,
                    kAudioSubTapUIDKey as String: tapUID
                ]
            ]
        ]

        var deviceID = AudioObjectID(kAudioObjectUnknown)
        let status = AudioHardwareCreateAggregateDevice(description as CFDictionary, &deviceID)
        guard status == noErr else {
            throw AudioCaptureError.systemTapUnavailable(status: status)
        }
        return deviceID
    }

    private func readTapUID(tapID: AudioObjectID) -> CFString? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &uid) { ptr -> OSStatus in
            AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, ptr)
        }
        return status == noErr ? uid : nil
    }

    // MARK: - 私有：IO

    private func startIO(on deviceID: AudioObjectID) throws {
        let format = tapStreamFormat
        var procID: AudioDeviceIOProcID?
        let status = AudioDeviceCreateIOProcIDWithBlock(&procID, deviceID, ioQueue) {
            [weak self] _, inInputData, _, _, _ in
            guard let self, let format else { return }
            let frames = AVAudioFrameCount(
                inInputData.pointee.mBuffers.mDataByteSize / max(1, format.streamDescription.pointee.mBytesPerFrame)
            )
            self.sampleHandler?(inInputData, frames, format)
        }
        guard status == noErr, let procID else {
            throw AudioCaptureError.systemTapUnavailable(status: status)
        }
        ioProcID = procID

        let startStatus = AudioDeviceStart(deviceID, procID)
        guard startStatus == noErr else {
            throw AudioCaptureError.systemTapUnavailable(status: startStatus)
        }
    }

    // MARK: - 私有：清理

    private func cleanup() {
        if aggregateDeviceID != AudioObjectID(kAudioObjectUnknown) {
            if let procID = ioProcID {
                AudioDeviceStop(aggregateDeviceID, procID)
                AudioDeviceDestroyIOProcID(aggregateDeviceID, procID)
                ioProcID = nil
            }
            AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
        }
        cleanupTap()
    }

    private func cleanupTap() {
        if tapID != AudioObjectID(kAudioObjectUnknown) {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
        tapStreamFormat = nil
    }
}
