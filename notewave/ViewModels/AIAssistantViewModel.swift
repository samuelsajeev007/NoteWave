import Foundation
import Observation
import SwiftData

// MARK: - Message Model (in-memory only, not persisted)

struct AIMessage: Identifiable {
    let id = UUID()
    let role: Role
    let response: AIResponse
    let createdAt: Date = Date()

    enum Role { case user, assistant }

    static func user(_ text: String) -> AIMessage {
        AIMessage(role: .user, response: .freeform(text: text))
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class AIAssistantViewModel {

    // MARK: - State
    var messages: [AIMessage] = []
    var selectedRecordings: [Recording] = []
    var recentChats: [AIChat] = []
    var allRecordings: [Recording] = []

    var isProcessing = false
    var processingLabel = "Thinking…"
    var inputText = ""
    var showAudioPicker = false
    var showHistory = false

    // Track last request for retry
    private(set) var lastPrompt: String? = nil
    private(set) var lastTool: AITool? = nil

    // MARK: - Dependencies
    private let service = AIAssistantService.shared
    private let repository: RecordingRepository

    init(repository: RecordingRepository) {
        self.repository = repository
    }

    // MARK: - Load

    func loadData() {
        allRecordings = (try? repository.fetchAll()) ?? []
        allRecordings = allRecordings.filter { $0.draftSessionId == nil }
        loadRecentChats()
    }

    func loadRecentChats() {
        do {
            let descriptor = FetchDescriptor<AIChat>(
                sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
            )
            let all = try repository.context.fetch(descriptor)
            recentChats = Array(all.prefix(50))
            // Prune oldest beyond 50
            if all.count > 50 {
                all.suffix(from: 50).forEach { repository.context.delete($0) }
                try? repository.context.save()
            }
        } catch {
            recentChats = []
        }
    }

    // MARK: - Audio Selection

    func toggleSelect(recording: Recording) {
        HapticManager.selection()
        if let idx = selectedRecordings.firstIndex(where: { $0.id == recording.id }) {
            selectedRecordings.remove(at: idx)
        } else {
            selectedRecordings.append(recording)
        }
    }

    func clearSelection() { selectedRecordings = [] }

    // MARK: - Retry Last Request

    func retryLast() {
        guard let prompt = lastPrompt, !isProcessing else { return }
        // Remove last error message from chat
        if case .error = messages.last?.response {
            messages.removeLast()
            // Also remove the duplicate user message that was appended
            if messages.last?.role == .user {
                messages.removeLast()
            }
        }
        HapticManager.medium()
        execute(prompt: prompt, tool: lastTool)
    }

    // MARK: - New Chat

    func newChat() {
        HapticManager.medium()
        messages = []
        inputText = ""
        lastPrompt = nil
        lastTool = nil
    }

    // MARK: - Send / Tool Execution

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isProcessing else { return }
        inputText = ""
        execute(prompt: text, tool: nil)
    }

    func executeTool(_ tool: AITool) {
        guard !isProcessing else { return }
        HapticManager.medium()
        let prompt = toolPrompt(for: tool)
        execute(prompt: prompt, tool: tool)
    }

    func executeSuggestion(_ suggestion: String) {
        guard !isProcessing else { return }
        inputText = suggestion
        send()
    }

    // MARK: - Core Execution

    private func execute(prompt: String, tool: AITool?) {
        guard !isProcessing else { return }

        // Track for retry
        lastPrompt = prompt
        lastTool = tool

        messages.append(AIMessage.user(prompt))
        isProcessing = true
        processingLabel = tool?.processingLabel ?? "Thinking…"

        Task {
            do {
                let response = try await dispatch(prompt: prompt, tool: tool)
                messages.append(AIMessage(role: .assistant, response: response))
                persistChat(prompt: prompt, response: response, tool: tool)
                HapticManager.success()
            } catch {
                messages.append(AIMessage(role: .assistant, response: .error(error.localizedDescription)))
                HapticManager.error()
            }
            isProcessing = false
            processingLabel = "Thinking…"
        }
    }

    private func dispatch(prompt: String, tool: AITool?) async throws -> AIResponse {
        let recs = selectedRecordings

        if let tool = tool {
            switch tool {
            case .summarize:
                guard let rec = recs.first else { return .error("Please select a recording first.") }
                return try await service.summarize(recording: rec, onProgress: { [weak self] label in
                    self?.processingLabel = label
                })
            case .generateTitle:
                guard let rec = recs.first else { return .error("Please select a recording first.") }
                return try await service.generateTitle(recording: rec, onProgress: { [weak self] label in
                    self?.processingLabel = label
                })
            case .extractTasks:
                guard let rec = recs.first else { return .error("Please select a recording first.") }
                return try await service.extractTasks(recording: rec, onProgress: { [weak self] label in
                    self?.processingLabel = label
                })
            case .generateTags:
                guard let rec = recs.first else { return .error("Please select a recording first.") }
                return try await service.generateTags(recording: rec, onProgress: { [weak self] label in
                    self?.processingLabel = label
                })
            case .search:
                return try await service.search(query: prompt, in: allRecordings, onProgress: { [weak self] label in
                    self?.processingLabel = label
                })
            case .askAbout:
                return try await service.askAbout(
                    question: prompt,
                    recordings: recs.isEmpty ? allRecordings : recs,
                    onProgress: { [weak self] label in self?.processingLabel = label }
                )
            case .insights:
                return try await service.insights(
                    recordings: recs.isEmpty ? allRecordings : recs,
                    onProgress: { [weak self] label in self?.processingLabel = label }
                )
            }
        }

        return try await service.chat(question: prompt, recordings: recs, onProgress: { [weak self] label in
            self?.processingLabel = label
        })
    }

    // MARK: - Apply Title

    func applyTitle(_ title: String, to recording: Recording) {
        recording.title = title
        recording.aiTitle = title
        recording.updatedDate = Date()
        try? repository.context.save()
        HapticManager.success()
    }

    // MARK: - Persist Chat

    private func persistChat(prompt: String, response: AIResponse, tool: AITool?) {
        let responseText: String
        switch response {
        case .summary(let t, _):        responseText = t
        case .title(let t, _):          responseText = t
        case .tasks(let items, _):      responseText = items.joined(separator: "\n")
        case .tags(let items, _):       responseText = items.joined(separator: ", ")
        case .searchResults(let rs):    responseText = rs.map { $0.recording.title }.joined(separator: "\n")
        case .answer(let t, _):         responseText = t
        case .insights(let t):          responseText = t
        case .freeform(let t):          responseText = t
        case .error(_):                 return
        }

        let chat = AIChat(
            prompt: prompt,
            response: responseText,
            toolType: tool?.rawValue ?? "freeform",
            recordingIDs: selectedRecordings.map { $0.id.uuidString }
        )
        repository.context.insert(chat)
        try? repository.context.save()
        loadRecentChats()
    }

    // MARK: - Delete Chat

    func deleteChat(_ chat: AIChat) {
        repository.context.delete(chat)
        try? repository.context.save()
        loadRecentChats()
    }

    // MARK: - Suggestions

    var suggestions: [String] {
        [
            "Summarize my latest recording",
            "Extract action items from the selected recording",
            "Find recordings discussing Firebase",
            "Generate a better title for this recording",
            "What tasks were assigned this week?",
            "Which recordings mention deployment?",
            "Give me insights across all my recordings",
            "What did we decide about the release date?",
            "List all topics discussed",
            "Translate this recording to English"
        ]
    }

    // MARK: - Helpers

    private func toolPrompt(for tool: AITool) -> String {
        switch tool {
        case .summarize:     return "Summarize the selected recording"
        case .generateTitle: return "Generate a better title for the selected recording"
        case .extractTasks:  return "Extract actionable tasks from the selected recording"
        case .generateTags:  return "Generate relevant tags for the selected recording"
        case .search:        return inputText.isEmpty ? "Search my recordings" : inputText
        case .askAbout:      return inputText.isEmpty ? "What are the key points from the selected recordings?" : inputText
        case .insights:      return "Generate insights across my recordings"
        }
    }
}
