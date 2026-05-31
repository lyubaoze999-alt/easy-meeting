import Foundation

/// 单声道 Float32 采样的线程安全环形缓冲区。
///
/// 用途：系统声音 Tap 的实时回调线程把采集到的单声道样本写入此缓冲，
/// `AVAudioSourceNode` 的渲染回调从中读取，从而把 Core Audio Tap 这一路
/// 接入 `AVAudioEngine` 的混音图（设计文档「两路接入 AVAudioMixerNode」）。
///
/// 采用定容覆盖策略：写满时丢弃最旧样本，保证实时回调永不阻塞。
/// 读取不足时以静音（0）补齐，保证渲染回调始终拿到完整帧。
final class AudioRingBuffer {
    private var storage: [Float]
    private let capacity: Int
    private var writeIndex = 0
    private var readIndex = 0
    private var availableCount = 0
    private let lock = NSLock()

    /// - Parameter capacity: 缓冲容量（样本数）。默认约 1 秒 @48kHz 的余量。
    init(capacity: Int = 48_000) {
        self.capacity = max(1, capacity)
        self.storage = [Float](repeating: 0, count: self.capacity)
    }

    /// 写入一段单声道样本（实时回调线程调用）。写满时覆盖最旧数据。
    func write(_ samples: UnsafePointer<Float>, count: Int) {
        guard count > 0 else { return }
        lock.lock()
        defer { lock.unlock() }
        for i in 0..<count {
            storage[writeIndex] = samples[i]
            writeIndex = (writeIndex + 1) % capacity
            if availableCount == capacity {
                // 缓冲已满：推进读指针，丢弃最旧样本。
                readIndex = (readIndex + 1) % capacity
            } else {
                availableCount += 1
            }
        }
    }

    /// 读取最多 `count` 个样本到目标缓冲；不足部分以 0 补齐。
    /// - Returns: 实际读取到的有效样本数（不含补零）。
    @discardableResult
    func read(into destination: UnsafeMutablePointer<Float>, count: Int) -> Int {
        guard count > 0 else { return 0 }
        lock.lock()
        defer { lock.unlock() }
        let readable = min(count, availableCount)
        for i in 0..<readable {
            destination[i] = storage[readIndex]
            readIndex = (readIndex + 1) % capacity
        }
        availableCount -= readable
        if readable < count {
            // 数据不足，剩余补静音，避免渲染回调出现未初始化内存。
            for i in readable..<count {
                destination[i] = 0
            }
        }
        return readable
    }

    /// 清空缓冲（重新开始采集前调用）。
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        writeIndex = 0
        readIndex = 0
        availableCount = 0
    }
}
