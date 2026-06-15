import UIKit

/// Centralised haptic feedback helper.
/// Respects the user's "Enable Haptics" setting from AppSettings.
enum HapticManager {

    // MARK: - Impact

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard AppSettings.shared.enableHaptics else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    // MARK: - Notification

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard AppSettings.shared.enableHaptics else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    // MARK: - Selection

    static func selection() {
        guard AppSettings.shared.enableHaptics else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // MARK: - Convenience

    /// Light tap — use for list item taps, icon toggles, minor interactions.
    static func light()  { impact(.light) }

    /// Medium tap — use for recording start, filter tab changes.
    static func medium() { impact(.medium) }

    /// Heavy tap — use for recording stop/done, destructive actions.
    static func heavy()  { impact(.heavy) }

    /// Success — use for successful operations (save, merge complete).
    static func success() { notification(.success) }

    /// Warning — use for cautionary prompts.
    static func warning() { notification(.warning) }

    /// Error — use for failed operations.
    static func error() { notification(.error) }
}
