import SwiftData
import Foundation

/// CRUD abstraction over the SwiftData ModelContext for Recording objects.
@MainActor
final class RecordingRepository {

    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Create

    func insert(_ recording: Recording) {
        context.insert(recording)
        save()
    }

    // MARK: - Read

    func fetchAll() throws -> [Recording] {
        let descriptor = FetchDescriptor<Recording>(
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchStarred() throws -> [Recording] {
        let descriptor = FetchDescriptor<Recording>(
            predicate: #Predicate { $0.isStarred },
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchShared() throws -> [Recording] {
        let descriptor = FetchDescriptor<Recording>(
            predicate: #Predicate { $0.isShared },
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchImported() throws -> [Recording] {
        let descriptor = FetchDescriptor<Recording>(
            predicate: #Predicate { $0.isImported },
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchMerged() throws -> [Recording] {
        let descriptor = FetchDescriptor<Recording>(
            predicate: #Predicate { $0.isMerged },
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchByDateRange(from start: Date, to end: Date) throws -> [Recording] {
        let descriptor = FetchDescriptor<Recording>(
            predicate: #Predicate { $0.createdDate >= start && $0.createdDate <= end },
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    // MARK: - Update

    func update(_ recording: Recording, title: String? = nil, isStarred: Bool? = nil) {
        if let title { recording.title = title }
        if let isStarred { recording.isStarred = isStarred }
        recording.updatedDate = Date()
        save()
    }

    func markShared(_ recording: Recording, medium: String) {
        recording.isShared = true
        recording.sharedDate = Date()
        recording.sharedMedium = medium
        recording.updatedDate = Date()
        save()
    }

    func saveTranscript(_ recording: Recording, transcript: String) {
        recording.transcript = transcript
        recording.updatedDate = Date()
        save()
    }

    // MARK: - Delete

    func delete(_ recording: Recording) {
        // Remove audio file from disk
        let url = recording.fileURL
        try? FileManager.default.removeItem(at: url)
        context.delete(recording)
        save()
    }

    // MARK: - Persist

    func save() {
        try? context.save()
    }
}
