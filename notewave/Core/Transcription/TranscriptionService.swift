import Speech
import Foundation

/// Wraps SFSpeechRecognizer for async file transcription (English).
final class TranscriptionService {

    static let shared = TranscriptionService()
    private init() {}

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    // MARK: - Permission

    func requestPermission() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    var isAvailable: Bool { recognizer?.isAvailable == true }

    // MARK: - Transcribe

    /// Returns the full transcript string and time-stamped segments.
    func transcribe(url: URL) async throws -> TranscriptResult {
        guard let rec = recognizer else {
            throw TranscriptionError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.taskHint = .unspecified

        return try await withCheckedThrowingContinuation { cont in
            rec.recognitionTask(with: request) { result, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                guard let result = result, result.isFinal else { return }
                let segments = result.bestTranscription.segments.map {
                    TranscriptSegment(text: $0.substring,
                                     timestamp: $0.timestamp,
                                     duration: $0.duration)
                }
                cont.resume(returning: TranscriptResult(
                    fullText: result.bestTranscription.formattedString,
                    segments: segments
                ))
            }
        }
    }
}

// MARK: - Models

struct TranscriptResult: Sendable {
    let fullText: String
    let segments: [TranscriptSegment]
}

struct TranscriptSegment: Sendable, Identifiable {
    let id = UUID()
    let text: String
    let timestamp: TimeInterval
    let duration: TimeInterval
}

enum TranscriptionError: Error, LocalizedError {
    case recognizerUnavailable
    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable: return "Speech recognizer is not available."
        }
    }
}
