import AVFoundation
import Foundation

/// Merges two audio files sequentially using AVMutableComposition.
/// Exports the result as AAC .m4a to the Recordings folder.
actor AudioMergeManager {

    static let shared = AudioMergeManager()
    private init() {}

    // MARK: - Merge

    /// Merges `firstURL` and `secondURL` sequentially (first plays, then second plays).
    /// Reports progress [0.0 … 1.0] via the `onProgress` closure (called on the main actor).
    /// Returns the output URL on success.
    func merge(
        first firstURL: URL,
        second secondURL: URL,
        outputTitle: String,
        onProgress: @escaping @MainActor (Double) -> Void
    ) async throws -> URL {

        let composition = AVMutableComposition()

        // --- Load first asset ---
        let firstAsset = AVURLAsset(url: firstURL)
        let firstTracks = try await firstAsset.loadTracks(withMediaType: .audio)
        guard let firstSourceTrack = firstTracks.first else {
            throw MergeError.noAudioTrack(firstURL)
        }
        // Load duration via the track's time range for accuracy (works for both .caf and .m4a)
        let firstTrackTimeRanges = try await firstSourceTrack.load(.timeRange)
        let firstDuration = firstTrackTimeRanges.duration

        // --- Load second asset ---
        let secondAsset = AVURLAsset(url: secondURL)
        let secondTracks = try await secondAsset.loadTracks(withMediaType: .audio)
        guard let secondSourceTrack = secondTracks.first else {
            throw MergeError.noAudioTrack(secondURL)
        }
        let secondTrackTimeRanges = try await secondSourceTrack.load(.timeRange)
        let secondDuration = secondTrackTimeRanges.duration

        // Validate durations
        let firstSecs = CMTimeGetSeconds(firstDuration)
        let secondSecs = CMTimeGetSeconds(secondDuration)
        guard firstSecs > 0 else { throw MergeError.zeroDuration(firstURL) }
        guard secondSecs > 0 else { throw MergeError.zeroDuration(secondURL) }

        // --- Create a single composition track ---
        guard let compositionTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw MergeError.cannotCreateTrack
        }

        // Insert first clip starting at time zero
        try compositionTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: firstDuration),
            of: firstSourceTrack,
            at: .zero
        )

        // Insert second clip right after the first
        try compositionTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: secondDuration),
            of: secondSourceTrack,
            at: firstDuration
        )

        // Expected total: firstDuration + secondDuration
        let expectedTotal = firstSecs + secondSecs

        // --- Export ---
        let outputURL = recordingsDirectory()
            .appendingPathComponent("\(outputTitle)_\(UUID().uuidString.prefix(8)).m4a")

        // Remove stale file if it exists
        try? FileManager.default.removeItem(at: outputURL)

        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw MergeError.cannotCreateExportSession
        }
        session.outputURL      = outputURL
        session.outputFileType = .m4a

        // Poll progress
        let progressTask = Task { @MainActor in
            while !Task.isCancelled {
                let rawProgress = Double(session.progress)
                await onProgress(rawProgress)
                try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
            }
        }
        defer { progressTask.cancel() }

        await session.export()

        await MainActor.run { onProgress(1.0) }

        if let error = session.error { throw error }
        guard session.status == .completed else {
            throw MergeError.exportFailed(session.status)
        }

        // Verify the exported file has roughly the right duration
        let exportedAsset = AVURLAsset(url: outputURL)
        let exportedDur = CMTimeGetSeconds(try await exportedAsset.load(.duration))
        if exportedDur < (expectedTotal * 0.5) {
            // Something went very wrong — exported file is less than half expected
            try? FileManager.default.removeItem(at: outputURL)
            throw MergeError.durationMismatch(expected: expectedTotal, got: exportedDur)
        }

        return outputURL
    }

    // MARK: - Helpers

    private func recordingsDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir  = docs.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Error

    enum MergeError: LocalizedError {
        case cannotCreateTrack
        case noAudioTrack(URL)
        case zeroDuration(URL)
        case cannotCreateExportSession
        case exportFailed(AVAssetExportSession.Status)
        case durationMismatch(expected: Double, got: Double)

        var errorDescription: String? {
            switch self {
            case .cannotCreateTrack:
                return "Could not create audio composition track."
            case .noAudioTrack(let url):
                return "No audio track found in \(url.lastPathComponent)."
            case .zeroDuration(let url):
                return "Audio file has zero duration: \(url.lastPathComponent)."
            case .cannotCreateExportSession:
                return "Could not create export session."
            case .exportFailed(let s):
                return "Export failed with status: \(s.rawValue)."
            case .durationMismatch(let expected, let got):
                return "Merged audio duration mismatch — expected \(String(format: "%.1f", expected))s, got \(String(format: "%.1f", got))s."
            }
        }
    }
}
