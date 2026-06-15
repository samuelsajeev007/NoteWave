import SwiftData
import Foundation

@Model
final class Recording {
    var id: UUID
    var title: String
    var filePath: String
    var duration: Double
    var createdDate: Date
    var updatedDate: Date
    var isStarred: Bool
    var isShared: Bool
    var sharedDate: Date?
    var sharedMedium: String?
    var isImported: Bool
    var isMerged: Bool
    var transcript: String?
    var fileSize: Int64
    var audioFormat: String
    var bitRate: Int
    var draftSessionId: String?

    // MARK: - AI-generated fields
    var summary: String?
    var aiTitle: String?
    var tasks: [String]
    var tags: [String]

    init(
        id: UUID = UUID(),
        title: String,
        filePath: String,
        duration: Double = 0,
        createdDate: Date = Date(),
        updatedDate: Date = Date(),
        isStarred: Bool = false,
        isShared: Bool = false,
        sharedDate: Date? = nil,
        sharedMedium: String? = nil,
        isImported: Bool = false,
        isMerged: Bool = false,
        transcript: String? = nil,
        fileSize: Int64 = 0,
        audioFormat: String = "AAC",
        bitRate: Int = 128000,
        draftSessionId: String? = nil,
        summary: String? = nil,
        aiTitle: String? = nil,
        tasks: [String] = [],
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.filePath = filePath
        self.duration = duration
        self.createdDate = createdDate
        self.updatedDate = updatedDate
        self.isStarred = isStarred
        self.isShared = isShared
        self.sharedDate = sharedDate
        self.sharedMedium = sharedMedium
        self.isImported = isImported
        self.isMerged = isMerged
        self.transcript = transcript
        self.fileSize = fileSize
        self.audioFormat = audioFormat
        self.bitRate = bitRate
        self.draftSessionId = draftSessionId
        self.summary = summary
        self.aiTitle = aiTitle
        self.tasks = tasks
        self.tags = tags
    }


    var fileURL: URL {
        let stored = URL(fileURLWithPath: filePath)

        // Fast path: stored absolute path is still valid.
        if FileManager.default.fileExists(atPath: stored.path) {
            return stored
        }

        // The iOS app-container UUID rotates on reinstall / Xcode rebuild.
        // The full path (e.g. /var/mobile/…/XXXXXXXX-.../Documents/Recordings/foo.m4a)
        // becomes stale while the file itself still exists under the NEW container UUID.
        // Reconstruct from the filename alone so all existing recordings stay playable.
        let filename = stored.lastPathComponent
        guard !filename.isEmpty else { return stored }

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let reconstructed = docs
            .appendingPathComponent("Recordings", isDirectory: true)
            .appendingPathComponent(filename)

        return reconstructed
    }

    var formattedDuration: String {
        let total = Int(duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    var formattedFileSize: String {
        let fmt = ByteCountFormatter()
        fmt.allowedUnits = [.useMB, .useKB]
        fmt.countStyle = .file
        return fmt.string(fromByteCount: fileSize)
    }

    var formattedCreatedDate: String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        let tf = DateFormatter()
        tf.dateFormat = "h:mm a"
        return "\(df.string(from: createdDate)) · \(tf.string(from: createdDate))"
    }
}
