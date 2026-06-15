import Foundation
import Observation

/// Drives the audio player sheet, including captions and speed control.
@Observable
@MainActor
final class PlayerViewModel {

    // MARK: - State forwarded from AudioPlayerManager
    var isPlaying: Bool { player.isPlaying }
    var currentTime: TimeInterval { player.currentTime }
    var duration: TimeInterval { player.duration }
    var playbackSpeed: Float { player.playbackSpeed }
    var isRepeatEnabled: Bool { player.isRepeatEnabled }

    // MARK: - Caption / Transcript State
    var showCaptions = false
    var segments: [TranscriptSegment] = []
    var isTranscribing = false
    var transcriptError: String? = nil

    /// Tracks which recording is currently loaded — used to guard stale caption results.
    private(set) var loadedRecordingID: UUID? = nil

    // MARK: - Speed picker
    let availableSpeeds: [Float] = [0.5, 1.0, 1.25, 1.5, 2.0]

    // MARK: - Current caption segment
    var currentSegmentIndex: Int? {
        guard !segments.isEmpty else { return nil }
        return segments.lastIndex { $0.timestamp <= currentTime }
    }

    // MARK: - Dependencies
    let player: AudioPlayerManager
    private let transcriptionService: TranscriptionService

    init(player: AudioPlayerManager, transcriptionService: TranscriptionService = TranscriptionService.shared) {
        self.player = player
        self.transcriptionService = transcriptionService
    }

    // MARK: - Controls

    func load(url: URL, title: String, recordingID: UUID) {
        // Reset caption state so a newly opened recording never shows
        // segments or captions that belong to the previously played recording.
        resetCaptionState()
        loadedRecordingID = recordingID

        // Check file existence before handing off to AVAudioPlayer so we can
        // show a meaningful error instead of silently failing.
        guard FileManager.default.fileExists(atPath: url.path) else {
            player.lastError = "Audio file not found on this device. It may have been deleted."
            return
        }

        do {
            try player.loadAndPlay(url: url, title: title)
        } catch {
            player.lastError = "Could not load audio: \(error.localizedDescription)"
        }
    }

    private func resetCaptionState() {
        showCaptions = false
        segments = []
        isTranscribing = false
        transcriptError = nil
    }

    func togglePlay() {
        if player.isPlaying { player.pause() } else { player.play() }
    }

    func seek(to fraction: Double) {
        let t = fraction * player.duration
        player.seek(to: t)
    }

    func seekAbsolute(to time: TimeInterval) {
        player.seek(to: time)
    }

    func setSpeed(_ speed: Float) {
        player.setSpeed(speed)
    }

    func toggleRepeat() {
        player.toggleRepeat()
    }

    func stop() {
        player.stop()
    }

    // MARK: - Transcript

    func toggleCaptions(for recording: Recording) {
        if showCaptions {
            showCaptions = false
            return
        }
        showCaptions = true
        
        // If we already have timed segments, we don't need to re-transcribe.
        if segments.count > 1 {
            return
        }
        
        // If we have a saved transcript but no segments yet, show the plain text
        // immediately while we re-transcribe in the background to get word-level timing back.
        if let existing = recording.transcript, !existing.isEmpty, segments.isEmpty {
            segments = [TranscriptSegment(text: existing, timestamp: 0, duration: recording.duration)]
        }
        
        Task { await generateTranscript(for: recording) }
    }

    private func generateTranscript(for recording: Recording) async {
        let expectedID = recording.id
        isTranscribing = true
        transcriptError = nil
        do {
            let result = try await transcriptionService.transcribe(url: recording.fileURL)
            // Guard: only apply results if this is still the active recording.
            guard loadedRecordingID == expectedID else { return }
            segments = result.segments
            showCaptions = true
        } catch {
            guard loadedRecordingID == expectedID else { return }
            transcriptError = error.localizedDescription
        }
        isTranscribing = false
    }
}
