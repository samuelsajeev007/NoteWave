import AVFoundation
import Foundation

/// Manages AVAudioSession lifecycle and handles interruptions.
final class AudioSessionManager: NSObject {

    static let shared = AudioSessionManager()

    private override init() {
        super.init()
        observeNotifications()
    }

    // MARK: - Configuration

    func configureForRecording() async throws {
        try await Task.detached(priority: .userInitiated) {
            let s = AVAudioSession.sharedInstance()
            // When background recording is ON, add options that allow the audio
            // session to continue in the background.
            let options: AVAudioSession.CategoryOptions = AppSettings.shared.backgroundRecording
                ? [.defaultToSpeaker, .allowBluetoothHFP, .mixWithOthers]
                : [.defaultToSpeaker, .allowBluetoothHFP]
            try s.setCategory(.playAndRecord, mode: .default, options: options)
            try s.setActive(true)
        }.value
    }

    func configureForPlayback() throws {
        let s = AVAudioSession.sharedInstance()
        try s.setCategory(.playback, mode: .default)
        try s.setActive(true)
    }

    func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Notifications

    private func observeNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(_ n: Notification) {
        guard let raw = n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            NotificationCenter.default.post(name: .audioInterruptionBegan, object: nil)
        case .ended:
            NotificationCenter.default.post(name: .audioInterruptionEnded, object: nil)
        @unknown default: break
        }
    }

    @objc private func handleRouteChange(_ n: Notification) {
        guard let raw = n.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: raw),
              reason == .oldDeviceUnavailable else { return }
        NotificationCenter.default.post(name: .audioRouteChanged, object: nil)
    }
}

extension Notification.Name {
    static let audioInterruptionBegan = Notification.Name("NW.audioInterruptionBegan")
    static let audioInterruptionEnded = Notification.Name("NW.audioInterruptionEnded")
    static let audioRouteChanged     = Notification.Name("NW.audioRouteChanged")
}
