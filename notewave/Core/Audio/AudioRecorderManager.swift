import AVFoundation
import Foundation
import Observation

/// Wraps AVAudioRecorder. Publishes live waveform samples and recording state.
@Observable
final class AudioRecorderManager: NSObject {

    // MARK: - Observable State
    var waveformSamples: [Float] = Array(repeating: 0.05, count: 60)
    var isRecording = false
    var isPaused = false
    var recordingDuration: TimeInterval = 0
    var currentTempURL: URL?
    var draftSessionId: String?

    // MARK: - Private
    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var durationTimer: Timer?
    private let sampleCount = 60

    // CAF + Linear PCM: crash-safe draft format.
    // CAF writes its file header at the START (not the end like M4A/MOV), so a
    // force-killed recording is STILL a fully-valid, immediately-playable file.
    // AVAudioPlayer reads .caf natively — no repair or conversion step needed.
    private let draftSettings: [String: Any] = [
        AVFormatIDKey:            Int(kAudioFormatLinearPCM),
        AVSampleRateKey:          44100.0,
        AVNumberOfChannelsKey:    1,
        AVLinearPCMBitDepthKey:   16,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsFloatKey:    false
    ]

    // MARK: - Start

    @discardableResult
    func startRecording() async throws -> URL {
        let sid = UUID().uuidString
        let url = FileManagerExtensions.tempRecordingURL(sessionId: sid)

        try await AudioSessionManager.shared.configureForRecording()

        let rec = try AVAudioRecorder(url: url, settings: draftSettings)
        rec.delegate = self
        rec.isMeteringEnabled = true
        rec.record()

        recorder = rec
        currentTempURL = url
        draftSessionId = sid
        isRecording = true
        isPaused = false
        recordingDuration = 0

        UserDefaults.standard.set(url.path, forKey: "nw_draftPath")
        UserDefaults.standard.set(sid,      forKey: "nw_draftSid")
        UserDefaults.standard.set(0.0,      forKey: "nw_draftDuration")

        startTimers()
        return url
    }

    // MARK: - Pause / Resume

    func pause() {
        recorder?.pause()
        isPaused = true
        stopTimers()
    }

    func resume() {
        recorder?.record()
        isPaused = false
        startTimers()
    }

    // MARK: - Stop (returns final temp URL)

    func stop() -> URL? {
        stopTimers()
        recorder?.stop()
        recorder = nil
        isRecording = false
        isPaused = false
        recordingDuration = 0
        waveformSamples = Array(repeating: 0.05, count: sampleCount)

        clearDraftDefaults()

        let url = currentTempURL
        currentTempURL = nil
        draftSessionId = nil
        return url
    }

    // MARK: - Cancel

    func cancel() {
        stopTimers()
        recorder?.stop()
        recorder?.deleteRecording()
        recorder = nil
        isRecording = false
        isPaused = false
        recordingDuration = 0
        waveformSamples = Array(repeating: 0.05, count: sampleCount)

        if let url = currentTempURL { try? FileManager.default.removeItem(at: url) }
        clearDraftDefaults()
        currentTempURL = nil
        draftSessionId = nil
    }

    // MARK: - Recovery

    var hasDraftRecording: Bool {
        guard let path = UserDefaults.standard.string(forKey: "nw_draftPath") else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    var draftURL: URL? {
        guard let path = UserDefaults.standard.string(forKey: "nw_draftPath") else { return nil }
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func discardDraft() {
        if let url = draftURL { try? FileManager.default.removeItem(at: url) }
        clearDraftDefaults()
    }

    private func clearDraftDefaults() {
        UserDefaults.standard.removeObject(forKey: "nw_draftPath")
        UserDefaults.standard.removeObject(forKey: "nw_draftSid")
        UserDefaults.standard.removeObject(forKey: "nw_draftDuration")
    }

    // MARK: - Timers & Metering

    private func startTimers() {
        meterTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.current.add(meterTimer!, forMode: .common)

        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.recordingDuration += 1
            // Persist live duration so recovery has an accurate fallback
            // even when the app is force-killed before the file is finalised.
            UserDefaults.standard.set(self.recordingDuration, forKey: "nw_draftDuration")
        }
        RunLoop.current.add(durationTimer!, forMode: .common)
    }

    private func stopTimers() {
        meterTimer?.invalidate(); meterTimer = nil
        durationTimer?.invalidate(); durationTimer = nil
    }

    private func tick() {
        guard let rec = recorder, rec.isRecording else { return }
        rec.updateMeters()
        let db = rec.averagePower(forChannel: 0) // -160 … 0
        let normalized = Float(max(0.03, min(1.0, (db + 60.0) / 60.0)))
        waveformSamples.removeFirst()
        waveformSamples.append(normalized)
    }
}

// MARK: - Delegate

extension AudioRecorderManager: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            Task { @MainActor in self.isRecording = false }
        }
    }
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in self.isRecording = false }
    }
}
