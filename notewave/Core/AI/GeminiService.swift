import Foundation

// MARK: - Gemini AI Service
//
// ┌─────────────────────────────────────────────────────────────┐
// │  ADD YOUR GEMINI API KEY BELOW                              │
// │  Get a free key at: https://aistudio.google.com/apikey     │
// │  Keys look like:  AIzaSy...                                │
// └─────────────────────────────────────────────────────────────┘
private let geminiAPIKey = "use_gemeni_api"

// Free-tier models (pick one):
//   gemini-2.0-flash       — recommended, 15 req/min free
//   gemini-1.5-flash-8b   — lightest, fastest, also free
// private let geminiTextModel = "gemini-2.0-flash"
private let geminiTextModel = "gemini-2.5-flash"
private let geminiBaseURL   = "https://generativelanguage.googleapis.com/v1beta/models"

// MARK: - Service

final class GeminiService {

    static let shared = GeminiService()
    private init() {}

    // MARK: - Transcribe Audio (Gemini multimodal — base64 audio)
    //
    // Supports: m4a, mp3, wav, flac, ogg, aac, webm.
    // Gemini 2.0 Flash handles up to ~1 hour of audio inline.

    func transcribe(audioURL: URL) async throws -> String {
        let audioData = try Data(contentsOf: audioURL)
        let base64Audio = audioData.base64EncodedString()

        let mimeType: String
        switch audioURL.pathExtension.lowercased() {
        case "mp3":  mimeType = "audio/mp3"
        case "wav":  mimeType = "audio/wav"
        case "flac": mimeType = "audio/flac"
        case "ogg":  mimeType = "audio/ogg"
        case "webm": mimeType = "audio/webm"
        default:     mimeType = "audio/mp4"   // covers m4a and aac
        }

        // Combine instruction + audio in a single user turn (most compatible format)
        let body: [String: Any] = [
            "contents": [[
                "role": "user",
                "parts": [
                    ["text": "Please transcribe this audio recording accurately. Return ONLY the transcript, no labels or annotations."],
                    ["inline_data": ["mime_type": mimeType, "data": base64Audio]]
                ]
            ]],
            "generationConfig": ["temperature": 0.1, "maxOutputTokens": 8192]
        ]

        return try await call(body: body)
    }

    // MARK: - Chat / Text Generation (with system + user split)
    //
    // Merges systemPrompt + userMessage into a single user turn.
    // This avoids system_instruction compatibility issues across model versions.

    func chat(
        systemPrompt: String,
        userMessage: String,
        temperature: Double = 0.7
    ) async throws -> String {
        let combined = """
            [Instructions]
            \(systemPrompt)

            [Request]
            \(userMessage)
            """
        return try await generate(prompt: combined, temperature: temperature)
    }

    // MARK: - Generate (single fully-formed prompt)
    //
    // Used by AIAssistantService which builds complete prompts itself.
    // The full prompt already contains all instructions + transcript content.

    func generate(prompt: String, temperature: Double = 0.7) async throws -> String {
        let body: [String: Any] = [
            "contents": [[
                "role": "user",
                "parts": [["text": prompt]]
            ]],
            "generationConfig": [
                "temperature": temperature,
                "maxOutputTokens": 4096
            ] as [String: Any]
        ]
        return try await call(body: body)
    }

    // MARK: - Core HTTP Call with Automatic Retry
    //
    // Retries up to 3 times on 429 (rate limit) with exponential backoff:
    //   Attempt 1: immediate
    //   Attempt 2: wait 3 s
    //   Attempt 3: wait 6 s
    //   Attempt 4: wait 12 s → throw if still failing

    private func call(body: [String: Any], attempt: Int = 0) async throws -> String {
        let urlString = "\(geminiBaseURL)/\(geminiTextModel):generateContent?key=\(geminiAPIKey)"
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as? HTTPURLResponse

        // ── Rate limit — retry with backoff ──────────────────────────
        if http?.statusCode == 429 {
            if attempt < 3 {
                let delaySec = Double(3 * (attempt + 1))  // 3s, 6s, 12s
                try await Task.sleep(nanoseconds: UInt64(delaySec * 1_000_000_000))
                return try await call(body: body, attempt: attempt + 1)
            }
            throw GeminiError.rateLimited
        }

        // ── Other HTTP errors ─────────────────────────────────────────
        if let status = http?.statusCode, !(200..<300).contains(status) {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let msg = error["message"] as? String {
                if status == 403 {
                    throw GeminiError.authError
                }
                throw GeminiError.apiError(msg)
            }
            throw GeminiError.networkError("HTTP \(status)")
        }

        // ── Parse response ────────────────────────────────────────────
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let first = candidates.first,
            let content = first["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String
        else {
            throw GeminiError.malformedResponse
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Errors

enum GeminiError: LocalizedError {
    case invalidURL
    case malformedResponse
    case authError
    case apiError(String)
    case rateLimited
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Gemini API URL."
        case .malformedResponse:
            return "Unexpected response from Gemini. Please try again."
        case .authError:
            return "Gemini API key is invalid or unauthorised. Get a free key at aistudio.google.com/apikey — keys start with 'AIzaSy'."
        case .apiError(let m):
            return "Gemini: \(m)"
        case .rateLimited:
            return "Rate limit reached. Please wait a few seconds and try again."
        case .networkError(let m):
            return "Network error: \(m)"
        }
    }
}
