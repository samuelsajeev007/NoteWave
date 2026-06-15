import Foundation
import Observation
import AVFoundation

/// All user-configurable settings, persisted to UserDefaults.
/// Access via `AppSettings.shared`.
///
/// Uses stored properties (required by `@Observable`) that sync to UserDefaults
/// via `didSet`. Computed-property-only models are NOT tracked by the macro.
@Observable
final class AppSettings {

    static let shared = AppSettings()

    private init() {
        // Load initial values from UserDefaults on creation.
        _recordingQualityKbps = UserDefaults.standard.integer(forKey: Keys.recordingQuality).nonZero ?? 128
        _exportFormat         = ExportFormat(rawValue: UserDefaults.standard.string(forKey: Keys.exportFormat) ?? "") ?? .aac
        _enableHaptics        = UserDefaults.standard.object(forKey: Keys.enableHaptics) == nil
            ? true : UserDefaults.standard.bool(forKey: Keys.enableHaptics)
        _keepScreenAwake      = UserDefaults.standard.object(forKey: Keys.keepScreenAwake) == nil
            ? true : UserDefaults.standard.bool(forKey: Keys.keepScreenAwake)
        _backgroundRecording  = UserDefaults.standard.object(forKey: Keys.backgroundRecording) == nil
            ? true : UserDefaults.standard.bool(forKey: Keys.backgroundRecording)
    }

    // MARK: - Audio Quality (kbps)

    var recordingQualityKbps: Int {
        get { _recordingQualityKbps }
        set {
            _recordingQualityKbps = newValue
            UserDefaults.standard.set(newValue, forKey: Keys.recordingQuality)
        }
    }
    private var _recordingQualityKbps: Int = 128

    // MARK: - Export Format

    var exportFormat: ExportFormat {
        get { _exportFormat }
        set {
            _exportFormat = newValue
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.exportFormat)
        }
    }
    private var _exportFormat: ExportFormat = .aac

    // MARK: - Preferences

    var enableHaptics: Bool {
        get { _enableHaptics }
        set {
            _enableHaptics = newValue
            UserDefaults.standard.set(newValue, forKey: Keys.enableHaptics)
        }
    }
    private var _enableHaptics: Bool = true

    var keepScreenAwake: Bool {
        get { _keepScreenAwake }
        set {
            _keepScreenAwake = newValue
            UserDefaults.standard.set(newValue, forKey: Keys.keepScreenAwake)
        }
    }
    private var _keepScreenAwake: Bool = true

    var backgroundRecording: Bool {
        get { _backgroundRecording }
        set {
            _backgroundRecording = newValue
            UserDefaults.standard.set(newValue, forKey: Keys.backgroundRecording)
        }
    }
    private var _backgroundRecording: Bool = true

    // MARK: - Keys

    private enum Keys {
        static let recordingQuality    = "nw_recordingQuality"
        static let exportFormat        = "nw_exportFormat"
        static let enableHaptics       = "nw_enableHaptics"
        static let keepScreenAwake     = "nw_keepScreenAwake"
        static let backgroundRecording = "nw_backgroundRecording"
    }
}

// MARK: - Export Format

enum ExportFormat: String, CaseIterable, Identifiable {
    case aac = "AAC"
    case mp3 = "MP3"
    case wav = "WAV"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .aac: return "AAC (.m4a)"
        case .mp3: return "MP3 (.mp3)"
        case .wav: return "WAV (.wav)"
        }
    }

    var fileExtension: String {
        switch self {
        case .aac: return "m4a"
        case .mp3: return "mp3"
        case .wav: return "wav"
        }
    }

    var avFileType: AVFileType {
        switch self {
        case .aac: return .m4a
        case .mp3: return .mp3
        case .wav: return .wav
        }
    }

    var avExportPreset: String {
        switch self {
        case .aac: return AVAssetExportPresetAppleM4A
        case .mp3: return AVAssetExportPresetAppleM4A  // transcoded separately
        case .wav: return AVAssetExportPresetPassthrough
        }
    }
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
