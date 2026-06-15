import Foundation
import SwiftData

// MARK: - AI Tool Enum

enum AITool: String, CaseIterable, Identifiable {
    case summarize      = "summarize"
    case generateTitle  = "generate_title"
    case extractTasks   = "extract_tasks"
    case generateTags   = "generate_tags"
    case search         = "ai_search"
    case askAbout       = "ask_about"
    case insights       = "insights"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .summarize:     return "Summarize"
        case .generateTitle: return "Generate Title"
        case .extractTasks:  return "Extract Tasks"
        case .generateTags:  return "Generate Tags"
        case .search:        return "AI Search"
        case .askAbout:      return "Ask About"
        case .insights:      return "Insights"
        }
    }

    var icon: String {
        switch self {
        case .summarize:     return "text.alignleft"
        case .generateTitle: return "pencil.and.sparkles"
        case .extractTasks:  return "checklist"
        case .generateTags:  return "tag"
        case .search:        return "magnifyingglass"
        case .askAbout:      return "bubble.left.and.bubble.right"
        case .insights:      return "chart.bar.xaxis"
        }
    }

    var processingLabel: String {
        switch self {
        case .summarize:     return "Generating Summary..."
        case .generateTitle: return "Crafting Title..."
        case .extractTasks:  return "Extracting Tasks..."
        case .generateTags:  return "Creating Tags..."
        case .search:        return "Searching Recordings..."
        case .askAbout:      return "Analyzing Recordings..."
        case .insights:      return "Generating Insights..."
        }
    }
}

// MARK: - AI Response Types

enum AIResponse {
    case summary(text: String, recording: Recording)
    case title(proposed: String, recording: Recording)
    case tasks(items: [String], recording: Recording)
    case tags(items: [String], recording: Recording)
    case searchResults(recordings: [SearchResult])
    case answer(text: String, sources: [Recording])
    case insights(text: String)
    case freeform(text: String)
    case error(String)

    struct SearchResult {
        let recording: Recording
        let matchReason: String
        let confidence: Double
    }
}

// Progress callbacks — always on MainActor
typealias ProgressCallback = @MainActor @Sendable (String) -> Void

// MARK: - AI Assistant Service (Gemini backend)

/// Orchestrates all AI operations.
///
/// TRANSCRIPT-FIRST PIPELINE:
/// Before ANY Gemini call, we ensure the recording has a transcript.
/// Gemini NEVER receives just a recording title — it always gets the full transcript.
///
/// Flow:
///   Transcript exists? -> use it
///   Transcript missing -> transcribe audio via Gemini multimodal -> save -> use it
@MainActor
final class AIAssistantService {

    static let shared = AIAssistantService()
    private init() {}

    private let gemini = GeminiService.shared

    // MARK: - Transcript Pipeline

    /// Returns existing transcript or generates one from audio via Gemini.
    /// The 'onProgress' label should already be on MainActor since ProgressCallback is @MainActor.
    func ensureTranscript(for recording: Recording, onProgress: ProgressCallback) async throws -> String {
        if let existing = recording.transcript, !existing.isEmpty {
            return existing
        }
        onProgress("Transcribing \"\(recording.title)\"...")
        let text = try await gemini.transcribe(audioURL: recording.fileURL)
        recording.transcript = text
        recording.updatedDate = Date()
        return text
    }

    /// Batch transcription — used for multi-recording tools.
    private func transcribeIfNeeded(_ recordings: [Recording], onProgress: ProgressCallback) async throws {
        for rec in recordings where (rec.transcript == nil || rec.transcript?.isEmpty == true) {
            onProgress("Transcribing \"\(rec.title)\"...")
            let text = try await gemini.transcribe(audioURL: rec.fileURL)
            rec.transcript = text
            rec.updatedDate = Date()
        }
    }

    // MARK: - Summarize
    //
    // Prompt from spec:
    //   Always send the transcript — never just the title.

    func summarize(recording: Recording, onProgress: ProgressCallback) async throws -> AIResponse {
        let transcript = try await ensureTranscript(for: recording, onProgress: onProgress)
        onProgress("Generating Summary...")

        let prompt =
            "You are an AI assistant inside a Voice Notes application.\n\n" +
            "Your task is to summarize the following recording transcript.\n\n" +
            "Rules:\n" +
            "- Generate a concise summary.\n" +
            "- Use bullet points.\n" +
            "- Focus on decisions, important discussions, action items, and outcomes.\n" +
            "- Do not invent information.\n" +
            "- If the transcript is unclear, mention that.\n" +
            "- Keep the summary professional and easy to read.\n\n" +
            "Recording Title:\n" +
            recording.title + "\n\n" +
            "Transcript:\n" +
            transcript + "\n\n" +
            "Response Format:\n\n" +
            "Summary\n\n" +
            "- Point 1\n" +
            "- Point 2\n" +
            "- Point 3\n\n" +
            "Key Topics\n\n" +
            "- Topic 1\n" +
            "- Topic 2\n" +
            "- Topic 3"

        let summary = try await gemini.generate(prompt: prompt)
        recording.summary = summary
        recording.updatedDate = Date()
        return .summary(text: summary, recording: recording)
    }

    // MARK: - Generate Title

    func generateTitle(recording: Recording, onProgress: ProgressCallback) async throws -> AIResponse {
        let transcript = try await ensureTranscript(for: recording, onProgress: onProgress)
        onProgress("Crafting Title...")

        let prompt =
            "You are an AI assistant inside a Voice Notes application.\n\n" +
            "Generate a short and professional title for this recording.\n\n" +
            "Rules:\n" +
            "- Maximum 8 words.\n" +
            "- Be specific.\n" +
            "- Use the actual discussion topic.\n" +
            "- Do not use generic names like 'Meeting Recording'.\n" +
            "- Return only the title, nothing else.\n\n" +
            "Transcript:\n\n" +
            transcript

        let title = try await gemini.generate(prompt: prompt)
        return .title(proposed: title.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), recording: recording)
    }

    // MARK: - Extract Tasks

    func extractTasks(recording: Recording, onProgress: ProgressCallback) async throws -> AIResponse {
        let transcript = try await ensureTranscript(for: recording, onProgress: onProgress)
        onProgress("Extracting Tasks...")

        let prompt =
            "You are an AI assistant inside a Voice Notes application.\n\n" +
            "Extract all actionable tasks from this transcript.\n\n" +
            "Rules:\n" +
            "- Return only tasks.\n" +
            "- Ignore discussions that are not action items.\n" +
            "- Convert tasks into short checkbox-style items.\n" +
            "- If no tasks are found, return: No tasks found.\n\n" +
            "Transcript:\n\n" +
            transcript + "\n\n" +
            "Response Format:\n\n" +
            "Tasks\n\n" +
            "- Task 1\n" +
            "- Task 2\n" +
            "- Task 3"

        let response = try await gemini.generate(prompt: prompt)

        let items = response
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .compactMap { (line: String) -> String? in
                // Strip common list prefixes
                for pfx in ["- ", "* ", ". ", "• "] {
                    if line.hasPrefix(pfx) { return String(line.dropFirst(pfx.count)) }
                }
                let lower = line.lowercased()
                if lower == "tasks" || line.isEmpty || lower == "no tasks found." { return nil }
                // Skip lines that are just headers or numbers alone
                if line.count <= 2 { return nil }
                return line
            }

        recording.tasks = items
        recording.updatedDate = Date()
        return .tasks(items: items, recording: recording)
    }

    // MARK: - Generate Tags

    func generateTags(recording: Recording, onProgress: ProgressCallback) async throws -> AIResponse {
        let transcript = try await ensureTranscript(for: recording, onProgress: onProgress)
        onProgress("Creating Tags...")

        let transcriptExcerpt = String(transcript.prefix(3000))
        let prompt =
            "You are an AI assistant inside a Voice Notes application.\n\n" +
            "Generate useful tags for this transcript.\n\n" +
            "Rules:\n" +
            "- Generate 3 to 10 tags.\n" +
            "- Use lowercase.\n" +
            "- Tags should represent important topics.\n" +
            "- Return only tags, one per line, each starting with #.\n\n" +
            "Transcript:\n\n" +
            transcriptExcerpt + "\n\n" +
            "Response Format:\n\n" +
            "#firebase\n" +
            "#swiftui\n" +
            "#deployment\n" +
            "#testing"

        let response = try await gemini.generate(prompt: prompt)

        let items = response
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased() }
            .filter { $0.hasPrefix("#") && $0.count > 1 }

        recording.tags = items
        recording.updatedDate = Date()
        return .tags(items: items, recording: recording)
    }

    // MARK: - AI Search

    func search(query: String, in recordings: [Recording], onProgress: ProgressCallback) async throws -> AIResponse {
        onProgress("Searching Recordings...")
        guard !recordings.isEmpty else { return .searchResults(recordings: []) }

        let recordingList = recordings.map { (rec: Recording) -> String in
            let excerpt = String((rec.transcript ?? rec.summary ?? "").prefix(300))
            return "ID: \(rec.id.uuidString)\nTitle: \(rec.title)\nTags: \(rec.tags.joined(separator: ", "))\nExcerpt: \(excerpt)"
        }.joined(separator: "\n\n---\n\n")

        let prompt =
            "You are an AI search assistant for a Voice Notes application.\n\n" +
            "Find which recordings are most relevant to the user's query.\n\n" +
            "User Query:\n\n" +
            query + "\n\n" +
            "Recordings:\n\n" +
            recordingList + "\n\n" +
            "Return a JSON array of the best matches: [{\"id\": \"uuid\", \"score\": 85, \"reason\": \"brief reason\"}]\n" +
            "Return best matches first. Return [] if nothing matches. Return ONLY the JSON array."

        let response = try await gemini.generate(prompt: prompt)
        let cleaned = response.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            .components(separatedBy: "```").filter { !$0.isEmpty }.first ?? response

        struct Match: Decodable { let id: String; let score: Int; let reason: String }
        let matches: [Match]
        if let data = cleaned.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([Match].self, from: data) {
            matches = decoded
        } else {
            matches = []
        }

        let results = matches.compactMap { (m: Match) -> AIResponse.SearchResult? in
            guard let rec = recordings.first(where: { $0.id.uuidString == m.id }) else { return nil }
            return AIResponse.SearchResult(recording: rec, matchReason: m.reason, confidence: Double(m.score) / 100.0)
        }
        return .searchResults(recordings: results)
    }

    // MARK: - Ask About Recordings

    func askAbout(question: String, recordings: [Recording], onProgress: ProgressCallback) async throws -> AIResponse {
        // Transcribe all selected recordings first
        try await transcribeIfNeeded(recordings, onProgress: onProgress)
        onProgress("Analyzing...")

        guard !recordings.isEmpty else {
            return .freeform(text: "Please select one or more recordings first.")
        }

        let transcriptContext = recordings.map { (rec: Recording) -> String in
            let transcript = rec.transcript ?? rec.summary ?? "(no content available)"
            return "Recording: \"\(rec.title)\"\nTranscript:\n\(String(transcript.prefix(2000)))"
        }.joined(separator: "\n\n---\n\n")

        let prompt =
            "You are an AI assistant for a Voice Notes application.\n\n" +
            "Answer the user's question using ONLY the provided recording transcript.\n\n" +
            "Rules:\n" +
            "- Do not invent information.\n" +
            "- If the answer is not found in the transcript, say: " +
            "\"This information was not found in the selected recording.\"\n" +
            "- Keep answers concise.\n\n" +
            "User Question:\n\n" +
            question + "\n\n" +
            "Transcript:\n\n" +
            transcriptContext

        let answer = try await gemini.generate(prompt: prompt)
        return .answer(text: answer, sources: recordings)
    }

    // MARK: - Insights

    func insights(recordings: [Recording], onProgress: ProgressCallback) async throws -> AIResponse {
        onProgress("Generating Insights...")
        guard !recordings.isEmpty else { return .freeform(text: "No recordings to analyze.") }

        let overview = recordings.map { (rec: Recording) -> String in
            let content = rec.summary ?? String((rec.transcript ?? rec.title).prefix(400))
            return "- \(rec.title) (\(rec.formattedDuration)): \(content)"
        }.joined(separator: "\n")

        let prompt =
            "You are an AI analyst reviewing a collection of voice recordings.\n\n" +
            "Identify top topics, common themes, recurring tasks, and activity patterns.\n\n" +
            "Format your response with these exact section headers:\n" +
            "**Top Topics**\n**Common Tasks**\n**Key Themes**\n**Most Active Period**\n\n" +
            "Use bullet points under each section. Be specific and data-driven.\n\n" +
            "Recordings (\(recordings.count) total):\n\n" +
            overview

        let result = try await gemini.generate(prompt: prompt)
        return .insights(text: result)
    }

    // MARK: - Freeform Chat
    //
    // CRITICAL: Transcribes all selected recordings before sending to Gemini.
    // Gemini will NEVER see "(no content)" — only real transcript text.

    func chat(question: String, recordings: [Recording], onProgress: ProgressCallback) async throws -> AIResponse {
        if !recordings.isEmpty {
            try await transcribeIfNeeded(recordings, onProgress: onProgress)
        }
        onProgress("Thinking...")

        let context: String
        if recordings.isEmpty {
            context = "No recordings selected. Answer the question generally."
        } else {
            context = recordings.map { (rec: Recording) -> String in
                let transcript = rec.transcript ?? rec.summary ?? ""
                return "Recording: \"\(rec.title)\" (\(rec.formattedDuration))\nTranscript:\n\(String(transcript.prefix(2000)))"
            }.joined(separator: "\n\n---\n\n")
        }

        let recordingsSection = recordings.isEmpty ? "" : "\n\nRecording Transcripts:\n\(context)"

        let prompt =
            "You are an intelligent voice-notes assistant inside a Voice Notes application.\n\n" +
            "Help the user interact with their recordings, extract insights, find information, " +
            "and organize their voice notes. Be concise, helpful, and accurate.\n\n" +
            "If the user asks to summarize, analyze, or describe a recording — use the transcript below. " +
            "The transcript IS the content of the recording. Do NOT say you cannot access it.\n\n" +
            "User Question: \(question)" +
            recordingsSection

        let answer = try await gemini.generate(prompt: prompt)
        return .freeform(text: answer)
    }
}
