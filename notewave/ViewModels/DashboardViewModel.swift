import Foundation
import SwiftData
import Observation
import AVFoundation
import UniformTypeIdentifiers

enum RecordingFilter: String, CaseIterable, Identifiable {
    case all      = "All"
    case shared   = "Shared"
    case starred  = "Starred"
    case device   = "Device"
    var id: String { rawValue }
}

@Observable
@MainActor
final class DashboardViewModel {

    // MARK: - State
    var recordings: [Recording] = []
    var searchQuery: String = ""
    var activeFilter: RecordingFilter = .all
    var dateRangeStart: Date? = nil
    var dateRangeEnd: Date? = nil
    var showDateFilter = false
    var showSettings = false
    var showImportPicker = false
    var errorMessage: String? = nil
    var showDeleteConfirm = false
    var recordingToDelete: Recording? = nil
    var recordingToRename: Recording? = nil
    var renameText: String = ""
    var showRenameAlert = false
    var showDetailsSheet: Recording? = nil

    // MARK: - Dependencies
    private let repository: RecordingRepository

    init(repository: RecordingRepository) {
        self.repository = repository
    }

    // MARK: - Fetch

    func loadRecordings() {
        do {
            recordings = try repository.fetchAll()
            // Heal stale paths in the background to avoid blocking the main thread.
            Task.detached(priority: .background) { [weak self] in
                await self?.healStalePaths()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func healStalePaths() async {
        var staleIDs: [(id: PersistentIdentifier, newPath: String)] = []
        let snapshot = await MainActor.run { recordings }
        // Check file existence off-main-thread to avoid blocking UI.
        for rec in snapshot {
            let resolved = rec.fileURL
            if resolved.path != rec.filePath,
               FileManager.default.fileExists(atPath: resolved.path) {
                staleIDs.append((id: rec.persistentModelID, newPath: resolved.path))
            }
        }
        guard !staleIDs.isEmpty else { return }
        await MainActor.run {
            for entry in staleIDs {
                if let rec = recordings.first(where: { $0.persistentModelID == entry.id }) {
                    rec.filePath = entry.newPath
                }
            }
            repository.save()
        }
    }

    // MARK: - Filtered List

    var filteredRecordings: [Recording] {
        var list: [Recording]
        switch activeFilter {
        case .all:     list = recordings
        case .shared:  list = recordings.filter { $0.isShared }
        case .starred: list = recordings.filter { $0.isStarred }
        case .device:  list = recordings.filter { $0.isImported }
        }

        // Hide in-progress draft recordings (they will appear once finalised).
        list = list.filter { $0.draftSessionId == nil }

        // Date range
        if let start = dateRangeStart, let end = dateRangeEnd {
            list = list.filter { $0.createdDate >= start && $0.createdDate <= end }
        }

        // Search
        if !searchQuery.isEmpty {
            list = list.filter { $0.title.localizedCaseInsensitiveContains(searchQuery) }
        }

        return list
    }

    // MARK: - Actions

    func toggleStar(_ recording: Recording) {
        repository.update(recording, isStarred: !recording.isStarred)
        loadRecordings()
    }

    func renameRecording(_ recording: Recording, to name: String) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        repository.update(recording, title: name)
        loadRecordings()
    }

    func deleteRecording(_ recording: Recording) {
        repository.delete(recording)
        loadRecordings()
    }

    func markShared(_ recording: Recording, medium: String) {
        repository.markShared(recording, medium: medium)
        loadRecordings()
    }

    func saveTranscript(for recording: Recording, text: String) {
        repository.saveTranscript(recording, transcript: text)
        loadRecordings()
    }

    func applyDateFilter(start: Date, end: Date) {
        dateRangeStart = start
        dateRangeEnd = end
    }

    func clearDateFilter() {
        dateRangeStart = nil
        dateRangeEnd = nil
    }

    // MARK: - Import

    func importRecording(from url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        do {
            let title = url.deletingPathExtension().lastPathComponent
            let dest = try FileManagerExtensions.copyToRecordings(from: url, title: title)
            let size = FileManagerExtensions.fileSize(at: dest)
            // Use AVAudioPlayer to read duration synchronously (reliable for local files)
            let dur: Double
            if let player = try? AVAudioPlayer(contentsOf: dest) {
                dur = player.duration
            } else {
                dur = 0
            }

            let rec = Recording(
                title: title,
                filePath: dest.path,
                duration: dur,
                isImported: true,
                fileSize: size
            )
            repository.insert(rec)
            loadRecordings()
        } catch {
            errorMessage = "Failed to import: \(error.localizedDescription)"
        }
    }

    // MARK: - Add recorded file from RecordingViewModel

    /// Called the moment recording STARTS. Immediately inserts a draft Recording
    /// into the DB so the entry survives an app crash.
    func handleDraftStarted(sessionId: String, tempURL: URL, title: String) {
        let size = FileManagerExtensions.fileSize(at: tempURL)
        let fmt = audioFormatDescription(for: tempURL)
        let rec = Recording(
            title: title,
            filePath: tempURL.path,
            duration: 0,
            fileSize: size,
            audioFormat: fmt.format,
            bitRate: fmt.bitRate,
            draftSessionId: sessionId
        )
        repository.insert(rec)
        loadRecordings()
    }

    /// Called when recording is finalised (stopped or recovered).
    /// If a matching draft entry already exists in the DB (by `draftSid`),
    /// it is updated in-place; otherwise a fresh record is created.
    func addRecording(title: String, url: URL, duration: TimeInterval, draftSid: String? = nil) {
        let size = FileManagerExtensions.fileSize(at: url)
        // Prefer duration read from the finalised file for accuracy.
        let fileDuration: TimeInterval
        if let player = try? AVAudioPlayer(contentsOf: url), player.duration > 0 {
            fileDuration = player.duration
        } else {
            fileDuration = duration
        }
        let fmt = audioFormatDescription(for: url)

        // Update the pre-existing draft entry when we have a matching session ID.
        if let sid = draftSid,
           let draft = recordings.first(where: { $0.draftSessionId == sid }) {
            draft.filePath    = url.path
            draft.duration    = fileDuration
            draft.title       = title
            draft.fileSize    = size
            draft.audioFormat = fmt.format
            draft.bitRate     = fmt.bitRate
            draft.draftSessionId = nil
            draft.updatedDate    = Date()
            repository.save()
            loadRecordings()
            convertDraftToAACIfNeeded(recording: draft)
            return
        }

        // No pre-existing draft — create a brand-new record.
        let rec = Recording(
            title: title, filePath: url.path, duration: fileDuration,
            fileSize: size, audioFormat: fmt.format, bitRate: fmt.bitRate
        )
        repository.insert(rec)
        loadRecordings()
        convertDraftToAACIfNeeded(recording: rec)
    }

    // MARK: - Helpers

    /// Returns human-readable format name and bit-rate for display in Details.
    private func audioFormatDescription(for url: URL) -> (format: String, bitRate: Int) {
        switch url.pathExtension.lowercased() {
        case "caf":
            // CAF/LPCM: 44100 Hz × 16 bit × 1 channel = 705600 bps
            return ("LPCM", 705_600)
        default:
            return ("AAC", 128_000)
        }
    }

    /// Removes the draft DB entry when the user discards or cancels a recording.
    func deleteDraftEntry(sessionId: String) {
        guard let draft = recordings.first(where: { $0.draftSessionId == sessionId }) else { return }
        // The audio file was already deleted by the recorder.
        // repository.delete() tries FileManager.removeItem too — that will fail silently
        // since the file is already gone, which is the correct behaviour here.
        repository.delete(draft)
        loadRecordings()
    }

    /// Spawns a background task to silently convert a .caf draft to .m4a using
    /// the user's preferred bitrate. The recording is already visible in the list
    /// before this runs — if conversion fails, the .caf file is kept and remains playable.
    private func convertDraftToAACIfNeeded(recording: Recording) {
        // Skip merged recordings and anything that isn't a .caf
        guard !recording.isMerged else { return }
        let cafURL = recording.fileURL
        guard cafURL.pathExtension.lowercased() == "caf",
              FileManager.default.fileExists(atPath: cafURL.path) else { return }

        let bitRate = AppSettings.shared.recordingQualityKbps
        let safeName = recording.title
            .components(separatedBy: .init(charactersIn: "/\\:"))
            .joined(separator: "_")
        let m4aDest = FileManagerExtensions.recordingsDirectory
            .appendingPathComponent("\(safeName).m4a")

        // Capture the persistent ID so we can look up the object after the async gap.
        let recordingID = recording.persistentModelID

        Task {
            do {
                let finalM4a = try await AudioConverter.convertToAAC(
                    sourceURL: cafURL,
                    destinationURL: m4aDest,
                    bitRate: bitRate * 1000
                )
                await MainActor.run {
                    // Re-fetch by ID so we always operate on the live model object.
                    guard let live = recordings.first(where: { $0.persistentModelID == recordingID }) else { return }
                    let newSize = FileManagerExtensions.fileSize(at: finalM4a)
                    live.filePath    = finalM4a.path
                    live.fileSize    = newSize
                    live.audioFormat = "AAC"
                    live.bitRate     = bitRate * 1000
                    try? FileManager.default.removeItem(at: cafURL)
                    repository.save()
                    // Refresh the list once after conversion — no further cascade.
                    if let updated = try? repository.fetchAll() {
                        recordings = updated
                    }
                }
            } catch {
                print("[AudioConverter] CAF→AAC failed for '\(recording.title)': \(error.localizedDescription)")
            }
        }
    }
}
