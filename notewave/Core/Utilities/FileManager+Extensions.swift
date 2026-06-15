import Foundation

enum FileManagerExtensions {

    static var recordingsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var tempDirectory: URL {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("NoteWaveDrafts", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return tmp
    }

    static func newRecordingURL(title: String? = nil) -> URL {
        let name = title ?? "Recording_\(Int(Date().timeIntervalSince1970))"
        return recordingsDirectory.appendingPathComponent("\(name).m4a")
    }

    static func tempRecordingURL(sessionId: String) -> URL {
        // .caf extension matches the CAF/LPCM recording format.
        // CAF files are crash-safe: a force-killed recording is still a valid .caf file.
        tempDirectory.appendingPathComponent("draft_\(sessionId).caf")
    }

    static func moveToRecordings(from tempURL: URL, title: String) throws -> URL {
        // Preserve the source file's extension (.caf for recorded drafts, .m4a for legacy).
        let ext = tempURL.pathExtension.isEmpty ? "m4a" : tempURL.pathExtension
        let dest = recordingsDirectory.appendingPathComponent("\(title).\(ext)")
        let finalURL: URL
        if FileManager.default.fileExists(atPath: dest.path) {
            let unique = recordingsDirectory.appendingPathComponent("\(title)_\(Int(Date().timeIntervalSince1970)).\(ext)")
            try FileManager.default.moveItem(at: tempURL, to: unique)
            finalURL = unique
        } else {
            try FileManager.default.moveItem(at: tempURL, to: dest)
            finalURL = dest
        }
        return finalURL
    }

    static func fileSize(at url: URL) -> Int64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs?[.size] as? Int64) ?? 0
    }

    static func copyToRecordings(from url: URL, title: String) throws -> URL {
        let dest = recordingsDirectory.appendingPathComponent("\(title).m4a")
        let finalURL: URL
        if FileManager.default.fileExists(atPath: dest.path) {
            let unique = recordingsDirectory.appendingPathComponent("\(title)_\(Int(Date().timeIntervalSince1970)).m4a")
            try FileManager.default.copyItem(at: url, to: unique)
            finalURL = unique
        } else {
            try FileManager.default.copyItem(at: url, to: dest)
            finalURL = dest
        }
        return finalURL
    }
}
