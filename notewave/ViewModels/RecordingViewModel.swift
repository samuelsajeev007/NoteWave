import Foundation
import Observation
import AVFoundation
import CoreMedia

/// Drives the recording bottom panel.
@Observable
@MainActor
final class RecordingViewModel {

    // MARK: - State
    var isShowingPanel = false
    var showRecoveryPrompt = false
    var errorMessage: String? = nil
    var defaultTitle: String { "Recording \(Date().formattedNewRecordingTitle)" }

    // MARK: - Recorder (forwarded properties)
    var waveformSamples: [Float] { recorder.waveformSamples }
    var isRecording: Bool { recorder.isRecording }
    var isPaused: Bool { recorder.isPaused }
    var duration: TimeInterval { recorder.recordingDuration }

    // MARK: - Dependencies
    let recorder: AudioRecorderManager

    // Called the moment a recording starts so the DB can persist a draft entry
    // immediately — the recording survives an app crash.
    private var onDraftStarted: ((String, URL, String) -> Void)?

    // Called when the recording is finalised (stopped normally or recovered).
    // Parameters: finalURL, duration, title, optional draftSessionId
    private var onFinished: ((URL, TimeInterval, String, String?) -> Void)?

    // Called when a draft is discarded (Delete in recovery prompt or Cancel
    // during active recording). Lets the caller clean up the DB entry.
    private var onDraftDiscarded: ((String) -> Void)?

    init(recorder: AudioRecorderManager) {
        self.recorder = recorder
    }

    func configure(
        onDraftStarted: @escaping (String, URL, String) -> Void,
        onFinished: @escaping (URL, TimeInterval, String, String?) -> Void,
        onDraftDiscarded: @escaping (String) -> Void
    ) {
        self.onDraftStarted = onDraftStarted
        self.onFinished = onFinished
        self.onDraftDiscarded = onDraftDiscarded
    }

    // MARK: - Microphone Permission

    func requestPermissionAndStart() async {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            await startRecording()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if granted { await startRecording() }
        default:
            errorMessage = "Microphone access denied. Please enable it in Settings."
        }
    }

    // MARK: - Control

    private func startRecording() async {
        let title = defaultTitle
        do {
            let tempURL = try await recorder.startRecording()
            let sid = recorder.draftSessionId ?? UUID().uuidString
            isShowingPanel = true
            onDraftStarted?(sid, tempURL, title)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func pause() { recorder.pause() }
    func resume() { recorder.resume() }

    func finish() {
        let dur = recorder.recordingDuration
        // Capture the session ID BEFORE stop() clears it from the recorder.
        let sid = recorder.draftSessionId
        if let url = recorder.stop() {
            let title = defaultTitle
            do {
                let finalURL = try FileManagerExtensions.moveToRecordings(from: url, title: title)
                onFinished?(finalURL, dur, title, sid)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        isShowingPanel = false
    }

    func cancel() {
        // Capture sid before cancel() clears it.
        let sid = recorder.draftSessionId
        recorder.cancel()
        isShowingPanel = false
        if let sid { onDraftDiscarded?(sid) }
    }

    // MARK: - Recovery
    //
    // Because we now record drafts in CAF/LPCM format, a force-killed recording
    // is ALWAYS a valid, playable file — no repair step needed.
    // Recovery is simply: read duration → move file → update DB.

    func checkForDraftRecording() {
        if recorder.hasDraftRecording {
            showRecoveryPrompt = true
        }
    }

    func recoverDraft() {
        guard let url = recorder.draftURL else {
            showRecoveryPrompt = false
            return
        }
        // Capture the session ID BEFORE discardDraft() clears UserDefaults.
        let savedSid = UserDefaults.standard.string(forKey: "nw_draftSid")
        let title = defaultTitle
        showRecoveryPrompt = false

        // Read duration from the file — the CAF/LPCM file is always valid and
        // fully readable, so AudioDurationHelper will return the correct value.
        var dur = AudioDurationHelper.duration(of: url)
        if dur <= 0 {
            // Fallback: use the last live-timer value persisted to UserDefaults.
            dur = UserDefaults.standard.double(forKey: "nw_draftDuration")
        }

        do {
            let finalURL = try FileManagerExtensions.moveToRecordings(from: url, title: title)
            onFinished?(finalURL, dur, title, savedSid)
        } catch {
            errorMessage = "Recovery failed: \(error.localizedDescription)"
        }

        // discardDraft() clears UserDefaults and tries to delete the file
        // from its old temp location — safe to call since the file is already moved.
        recorder.discardDraft()
    }

    func discardDraft() {
        let sid = UserDefaults.standard.string(forKey: "nw_draftSid")
        recorder.discardDraft()
        showRecoveryPrompt = false
        if let sid { onDraftDiscarded?(sid) }
    }
}

// MARK: - Helpers

private extension Date {
    var formattedNewRecordingTitle: String {
        let df = DateFormatter()
        df.dateFormat = "MMM d, h:mm a"
        return df.string(from: self)
    }
}

enum AudioDurationHelper {
    /// Returns the audio duration of a local file.
    ///
    /// Supports both .caf (new draft format) and .m4a (legacy / properly-stopped).
    static func duration(of url: URL) -> TimeInterval {
        guard FileManager.default.fileExists(atPath: url.path) else { return 0 }

        // Primary: AVAudioPlayer — fast and works for both .caf and finalised .m4a.
        if let player = try? AVAudioPlayer(contentsOf: url), player.duration > 0 {
            return player.duration
        }

        // Fallback: AVURLAsset — handles edge cases.
        let asset = AVURLAsset(url: url)
        let seconds = CMTimeGetSeconds(asset.duration)
        if seconds.isFinite && seconds > 0 { return seconds }

        return 0
    }
}
