import SwiftData
import Foundation

/// Persisted AI chat session entry.
/// One AIChat represents one complete prompt → response exchange.
@Model
final class AIChat {

    var id: UUID
    var prompt: String
    var response: String
    /// Which AI tool was used (raw value of AITool, or "freeform" for typed prompts).
    var toolType: String
    var createdDate: Date
    /// IDs of recordings used as context for this chat.
    var recordingIDs: [String]

    init(
        id: UUID = UUID(),
        prompt: String,
        response: String,
        toolType: String = "freeform",
        createdDate: Date = Date(),
        recordingIDs: [String] = []
    ) {
        self.id = id
        self.prompt = prompt
        self.response = response
        self.toolType = toolType
        self.createdDate = createdDate
        self.recordingIDs = recordingIDs
    }

    /// A short display title derived from the prompt (first 50 chars).
    var displayTitle: String {
        prompt.count > 50 ? String(prompt.prefix(50)) + "…" : prompt
    }

    var relativeDate: String {
        let cal = Calendar.current
        if cal.isDateInToday(createdDate) {
            let mins = Int(-createdDate.timeIntervalSinceNow / 60)
            if mins < 60 { return "\(mins) min ago" }
            let hrs = mins / 60
            return "\(hrs) hour\(hrs == 1 ? "" : "s") ago"
        } else if cal.isDateInYesterday(createdDate) {
            return "Yesterday"
        } else {
            let df = DateFormatter()
            df.dateFormat = "MMM d"
            return df.string(from: createdDate)
        }
    }
}
