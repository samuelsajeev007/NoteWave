import AVFoundation
import Foundation

enum AudioConverter {

    /// Converts a local audio file (e.g., .caf recorded from mic) to an AAC .m4a.
    ///
    /// Uses `AVAssetExportSession` which automatically handles mono/stereo channel
    /// mapping — safe for iPhone microphone recordings (always mono).
    ///
    /// - Parameters:
    ///   - sourceURL: The source audio file (e.g., a `.caf` draft).
    ///   - destinationURL: Where to write the `.m4a` output.
    ///   - bitRate: Target AAC bit rate in **bits per second** (e.g., 128_000 for 128 kbps).
    /// - Returns: The destination URL on success.
    static func convertToAAC(
        sourceURL: URL,
        destinationURL: URL,
        bitRate: Int = 128_000
    ) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)

        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(
                domain: "AudioConverter",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not create export session for \(sourceURL.lastPathComponent)."]
            )
        }

        // Remove destination if it already exists (export session will not overwrite).
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        session.outputURL      = destinationURL
        session.outputFileType = .m4a
        session.shouldOptimizeForNetworkUse = false

        await session.export()

        switch session.status {
        case .completed:
            return destinationURL
        case .failed:
            throw session.error ?? NSError(
                domain: "AudioConverter",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Export failed with no error details."]
            )
        case .cancelled:
            throw NSError(domain: "AudioConverter", code: 3, userInfo: [NSLocalizedDescriptionKey: "Export was cancelled."])
        default:
            throw NSError(domain: "AudioConverter", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unexpected export status: \(session.status.rawValue)"])
        }
    }
}
