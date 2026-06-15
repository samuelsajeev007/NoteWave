import Foundation
import Security

// MARK: - OpenAI Service

/// Thin HTTP client for OpenAI APIs: Whisper (audio transcription) and GPT-4o-mini (chat).
/// API key is stored securely in iOS Keychain.
final class OpenAIService {

    static let shared = OpenAIService()
    private init() {}

    // MARK: - Keychain

    private let keychainKey = "com.notewave.openai.apikey"

    var apiKey: String? {
        get { KeychainHelper.read(key: keychainKey) }
        set {
            if let value = newValue {
                KeychainHelper.save(key: keychainKey, value: value)
            } else {
                KeychainHelper.delete(key: keychainKey)
            }
        }
    }

    var hasAPIKey: Bool { !(apiKey ?? "").isEmpty }

    // MARK: - Network Availability

    var isOnline: Bool {
        // Lightweight connectivity check — try reaching openai.com DNS
        let hostname = "api.openai.com" as CFString
        guard let host = CFHostCreateWithName(nil, hostname).takeRetainedValue() as CFHost? else { return false }
        var resolved = DarwinBoolean(false)
        CFHostStartInfoResolution(host, .addresses, nil)
        CFHostGetAddressing(host, &resolved)
        return resolved.boolValue
    }

    // MARK: - Whisper: Audio Transcription

    /// Transcribes an audio file using OpenAI Whisper.
    /// Supports English, Hindi, Malayalam, Tamil, Telugu, Kannada, and mixed-language audio.
    func transcribe(audioURL: URL) async throws -> String {
        guard let key = apiKey, !key.isEmpty else {
            throw OpenAIError.missingAPIKey
        }

        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        // model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        // response_format
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("text\r\n".data(using: .utf8)!)
        // audio file
        let audioData = try Data(contentsOf: audioURL)
        let mimeType = audioURL.pathExtension.lowercased() == "mp3" ? "audio/mpeg" : "audio/m4a"
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)

        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    // MARK: - GPT-4o-mini: Chat

    /// Sends a prompt to GPT-4o-mini and returns the assistant's response string.
    func chat(
        systemPrompt: String,
        userMessage: String,
        temperature: Double = 0.4
    ) async throws -> String {
        guard let key = apiKey, !key.isEmpty else {
            throw OpenAIError.missingAPIKey
        }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "temperature": temperature,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.malformedResponse
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw OpenAIError.networkError("No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            if http.statusCode == 401 { throw OpenAIError.invalidAPIKey }
            if http.statusCode == 429 { throw OpenAIError.rateLimited }
            throw OpenAIError.networkError("HTTP \(http.statusCode): \(message)")
        }
    }
}

// MARK: - Errors

enum OpenAIError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case rateLimited
    case networkError(String)
    case malformedResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:    return "OpenAI API key not set. Please add your key in Settings > AI Assistant."
        case .invalidAPIKey:   return "Invalid API key. Please check your key in Settings > AI Assistant."
        case .rateLimited:     return "Too many requests. Please wait a moment and try again."
        case .networkError(let msg): return "Network error: \(msg)"
        case .malformedResponse: return "Unexpected response from OpenAI."
        }
    }
}

// MARK: - Keychain Helper

private enum KeychainHelper {
    static func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData:   data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
