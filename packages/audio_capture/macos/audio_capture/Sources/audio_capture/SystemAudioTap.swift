import AVFoundation
import CoreAudio
import Foundation

@available(macOS 14.4, *)
final class SystemAudioTap {
  typealias SampleHandler = (UnsafePointer<AudioBufferList>, AVAudioFrameCount, AVAudioFormat) -> Void

  private var tapID = AudioObjectID(kAudioObjectUnknown)
  private var aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
  private var ioProcID: AudioDeviceIOProcID?
  private let queue = DispatchQueue(label: "com.meetingnotes.audio.system-tap")
  private var handler: SampleHandler?
  private(set) var streamFormat: AVAudioFormat?

  func start(handler: @escaping SampleHandler) throws {
    self.handler = handler
    let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
    description.isPrivate = true
    description.muteBehavior = .unmuted
    var newTap = AudioObjectID(kAudioObjectUnknown)
    let status = AudioHardwareCreateProcessTap(description, &newTap)
    guard status == noErr else { throw MacAudioError.systemAudioUnavailable(status) }
    tapID = newTap
    streamFormat = readFormat(newTap)
    aggregateDeviceID = try createAggregateDevice(newTap)
    try startIO(aggregateDeviceID)
  }

  func stop() {
    if aggregateDeviceID != AudioObjectID(kAudioObjectUnknown) {
      if let ioProcID {
        AudioDeviceStop(aggregateDeviceID, ioProcID)
        AudioDeviceDestroyIOProcID(aggregateDeviceID, ioProcID)
      }
      AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
    }
    if tapID != AudioObjectID(kAudioObjectUnknown) { AudioHardwareDestroyProcessTap(tapID) }
    tapID = AudioObjectID(kAudioObjectUnknown)
    aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
    ioProcID = nil
    streamFormat = nil
  }

  private func readFormat(_ id: AudioObjectID) -> AVAudioFormat? {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioTapPropertyFormat,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var value = AudioStreamBasicDescription()
    var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else { return nil }
    return AVAudioFormat(streamDescription: &value)
  }

  private func createAggregateDevice(_ id: AudioObjectID) throws -> AudioObjectID {
    guard let uid = readUID(id) else { throw MacAudioError.systemAudioUnavailable(kAudioHardwareUnspecifiedError) }
    let dictionary: [String: Any] = [
      kAudioAggregateDeviceNameKey as String: "Easy Meeting System Capture",
      kAudioAggregateDeviceUIDKey as String: "com.meetingnotes.aggregate.\(UUID().uuidString)",
      kAudioAggregateDeviceIsPrivateKey as String: true,
      kAudioAggregateDeviceIsStackedKey as String: false,
      kAudioAggregateDeviceTapAutoStartKey as String: true,
      kAudioAggregateDeviceSubDeviceListKey as String: [],
      kAudioAggregateDeviceTapListKey as String: [[
        kAudioSubTapDriftCompensationKey as String: true,
        kAudioSubTapUIDKey as String: uid
      ]]
    ]
    var device = AudioObjectID(kAudioObjectUnknown)
    let status = AudioHardwareCreateAggregateDevice(dictionary as CFDictionary, &device)
    guard status == noErr else { throw MacAudioError.systemAudioUnavailable(status) }
    return device
  }

  private func readUID(_ id: AudioObjectID) -> CFString? {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioTapPropertyUID,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var uid: CFString = "" as CFString
    var size = UInt32(MemoryLayout<CFString>.size)
    let status = withUnsafeMutablePointer(to: &uid) {
      AudioObjectGetPropertyData(id, &address, 0, nil, &size, $0)
    }
    return status == noErr ? uid : nil
  }

  private func startIO(_ device: AudioObjectID) throws {
    let format = streamFormat
    var callback: AudioDeviceIOProcID?
    let status = AudioDeviceCreateIOProcIDWithBlock(&callback, device, queue) {
      [weak self] _, input, _, _, _ in
      guard let self, let format else { return }
      let bytesPerFrame = max(1, format.streamDescription.pointee.mBytesPerFrame)
      let frames = AVAudioFrameCount(input.pointee.mBuffers.mDataByteSize / bytesPerFrame)
      self.handler?(input, frames, format)
    }
    guard status == noErr, let callback else { throw MacAudioError.systemAudioUnavailable(status) }
    ioProcID = callback
    let startStatus = AudioDeviceStart(device, callback)
    guard startStatus == noErr else { throw MacAudioError.systemAudioUnavailable(startStatus) }
  }

  deinit { stop() }
}
