import Foundation
import Observation
import AVFoundation

/// Drives the Merge Audio screen.
@Observable
@MainActor
final class MergeAudioViewModel {

    // MARK: - Selection
    var firstRecording: Recording?
    var secondRecording: Recording?

    var canMerge: Bool { firstRecording != nil && secondRecording != nil }

    // MARK: - Merge State
    enum MergeState {
        case idle
        case merging
        case success(Recording)
        case failure(String)
    }

    var mergeState: MergeState = .idle
    var mergeProgress: Double = 0

    // MARK: - All recordings (for picker)
    var allRecordings: [Recording] = []

    // MARK: - Dependencies
    private let repository: RecordingRepository

    init(repository: RecordingRepository) {
        self.repository = repository
    }

    func loadRecordings() {
        allRecordings = (try? repository.fetchAll()) ?? []
        // Exclude draft entries and merged entries from being merge candidates
        allRecordings = allRecordings.filter { $0.draftSessionId == nil && !$0.isMerged }
    }

    // MARK: - Toggle selection

    func select(_ recording: Recording, slot: Int) {
        if slot == 1 {
            // Prevent selecting same as second slot
            if secondRecording?.id == recording.id { return }
            firstRecording = (firstRecording?.id == recording.id) ? nil : recording
        } else {
            if firstRecording?.id == recording.id { return }
            secondRecording = (secondRecording?.id == recording.id) ? nil : recording
        }
    }

    func isSelected(_ recording: Recording) -> Bool {
        firstRecording?.id == recording.id || secondRecording?.id == recording.id
    }

    func selectionLabel(for recording: Recording) -> String? {
        if firstRecording?.id == recording.id { return "1st" }
        if secondRecording?.id == recording.id { return "2nd" }
        return nil
    }

    // MARK: - Perform Merge

    func performMerge() {
        guard let first = firstRecording, let second = secondRecording else { return }

        mergeState   = .merging
        mergeProgress = 0

        let firstName  = first.title
        let secondName = second.title
        let outputTitle = "Merged - \(firstName)"

        Task {
            do {
                let outputURL = try await AudioMergeManager.shared.merge(
                    first: first.fileURL,
                    second: second.fileURL,
                    outputTitle: outputTitle,
                    onProgress: { [weak self] p in
                        self?.mergeProgress = p
                    }
                )

                // Compute duration
                let asset = AVURLAsset(url: outputURL)
                let dur = try await asset.load(.duration)
                let duration = CMTimeGetSeconds(dur)

                let size = (try? outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0

                let rec = Recording(
                    title: outputTitle,
                    filePath: outputURL.path,
                    duration: duration.isFinite ? duration : 0,
                    isMerged: true,
                    fileSize: size,
                    audioFormat: "AAC",
                    bitRate: 128_000
                )
                repository.insert(rec)

                mergeState = .success(rec)
            } catch {
                mergeState = .failure(error.localizedDescription)
            }
        }
    }

    func reset() {
        firstRecording  = nil
        secondRecording = nil
        mergeState      = .idle
        mergeProgress   = 0
    }
}
