import SwiftUI
import SwiftData
import AVFoundation

// MARK: - Main Settings View

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Bindable private var settings = AppSettings.shared

    // Sheets
    @State private var showQualityPicker = false
    @State private var showExportFormat  = false
    @State private var showAbout         = false
    @State private var showMergeAudio    = false
    @State private var navigateToMergedLibrary = false

    // Storage stats
    @State private var totalCount    = 0
    @State private var totalSize: Int64 = 0
    @State private var importedCount = 0
    @State private var mergedCount   = 0
    @State private var sharedCount   = 0

    // All recordings (for export picker)
    @State private var allRecordings: [Recording] = []

    private var repository: RecordingRepository { RecordingRepository(context: ctx) }
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    audioSection
                    audioToolsSection
                    exportSection
                    preferencesSection
                    storageSection
                    aboutSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            // Sheets
            .sheet(isPresented: $showQualityPicker) { QualityPickerSheet() }
            .sheet(isPresented: $showExportFormat) {
                ExportFormatSheet(recordings: allRecordings)
            }
            .sheet(isPresented: $showMergeAudio) {
                MergeAudioView(repository: repository)
            }
            .navigationDestination(isPresented: $navigateToMergedLibrary) {
                MergedAudioLibraryView(repository: repository)
            }
            .sheet(isPresented: $showAbout) {
                NavigationStack { AboutView() }
            }
            .onAppear { loadStats() }
        }
    }

    // MARK: - Audio Section

    private var audioSection: some View {
        SettingsSection(title: "Audio") {
            SettingsInfoRow(
                icon: "waveform",
                iconColor: .blue,
                label: "Format",
                value: "AAC (.m4a)"
            )

            SettingsDivider()

            SettingsActionRow(
                icon: "dial.high",
                iconColor: .purple,
                label: "Quality",
                value: "\(settings.recordingQualityKbps) kbps"
            ) {
                haptic(.light)
                showQualityPicker = true
            }

            SettingsDivider()

            SettingsInfoRow(
                icon: "metronome",
                iconColor: .teal,
                label: "Sample Rate",
                value: "44.1 kHz"
            )
        }
    }

    // MARK: - Audio Tools Section

    private var audioToolsSection: some View {
        SettingsSection(title: "Audio Tools") {
            SettingsActionRow(
                icon: "waveform.badge.plus",
                iconColor: .orange,
                label: "Merge Audio",
                value: nil
            ) {
                haptic(.light)
                showMergeAudio = true
            }

            SettingsDivider()

            SettingsActionRow(
                icon: "rectangle.stack.badge.play",
                iconColor: .indigo,
                label: "Merged Audio Library",
                value: mergedCount > 0 ? "\(mergedCount)" : nil
            ) {
                haptic(.light)
                navigateToMergedLibrary = true
            }
        }
    }

    // MARK: - Export Section

    private var exportSection: some View {
        SettingsSection(title: "Export") {
            SettingsActionRow(
                icon: "square.and.arrow.up",
                iconColor: .green,
                label: "Export Audio Format",
                value: settings.exportFormat.displayName
            ) {
                haptic(.light)
                showExportFormat = true
            }
        }
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        SettingsSection(title: "Preferences") {
            SettingsToggleRow(
                icon: "hand.tap",
                iconColor: .pink,
                label: "Enable Haptics",
                isOn: $settings.enableHaptics
            )
            .onChange(of: settings.enableHaptics) { _, enabled in
                // Give a confirmation tap when haptics are turned ON.
                // Note: we bypass HapticManager here since the setting was just enabled.
                if enabled {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }

            SettingsDivider()

            SettingsToggleRow(
                icon: "sun.max",
                iconColor: .yellow,
                label: "Keep Screen Awake While Recording",
                isOn: $settings.keepScreenAwake
            )
            .onChange(of: settings.keepScreenAwake) { _, v in
                UIApplication.shared.isIdleTimerDisabled = v
            }

            SettingsDivider()

            SettingsToggleRow(
                icon: "mic.badge.plus",
                iconColor: .red,
                label: "Background Recording",
                isOn: $settings.backgroundRecording
            )
            .onChange(of: settings.backgroundRecording) { _, enabled in
                // Reconfigure the audio session so background recording takes effect
                // immediately without needing an app restart.
                Task.detached(priority: .userInitiated) {
                    let session = AVAudioSession.sharedInstance()
                    let options: AVAudioSession.CategoryOptions = enabled
                        ? [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
                        : [.defaultToSpeaker, .allowBluetooth]
                    try? session.setCategory(.playAndRecord, mode: .default, options: options)
                }
            }
        }
        .onAppear {
            // Re-apply screen-awake setting every time the Settings sheet opens
            // (e.g. after an app restart the UIApplication state may need refreshing).
            UIApplication.shared.isIdleTimerDisabled = settings.keepScreenAwake
        }
    }

    // MARK: - Storage Section

    private var storageSection: some View {
        SettingsSection(title: "Storage") {
            SettingsInfoRow(icon: "folder", iconColor: .brown, label: "Total Recordings", value: "\(totalCount)")
            SettingsDivider()
            SettingsInfoRow(icon: "internaldrive", iconColor: .gray, label: "Total Storage Used", value: formatSize(totalSize))
            SettingsDivider()
            SettingsInfoRow(icon: "square.and.arrow.down", iconColor: .cyan, label: "Imported Recordings", value: "\(importedCount)")
            SettingsDivider()
            SettingsInfoRow(icon: "waveform.badge.plus", iconColor: .orange, label: "Merged Recordings", value: "\(mergedCount)")
            SettingsDivider()
            SettingsInfoRow(icon: "paperplane", iconColor: .blue, label: "Shared Recordings", value: "\(sharedCount)")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        SettingsSection(title: "About") {
            SettingsInfoRow(icon: "waveform", iconColor: .accentColor, label: "NoteWave", value: "")
            SettingsDivider()
            SettingsInfoRow(icon: "info.circle", iconColor: .secondary, label: "Version", value: appVersion)
            SettingsDivider()
            SettingsActionRow(icon: "person.circle", iconColor: .indigo, label: "About", value: nil) {
                haptic(.light)
                showAbout = true
            }
        }
    }

    // MARK: - Helpers

    private func loadStats() {
        let recs = (try? repository.fetchAll()) ?? []
        allRecordings = recs.filter { $0.draftSessionId == nil }
        totalCount    = allRecordings.count
        totalSize     = allRecordings.reduce(0) { $0 + $1.fileSize }
        importedCount = allRecordings.filter { $0.isImported }.count
        mergedCount   = allRecordings.filter { $0.isMerged }.count
        sharedCount   = allRecordings.filter { $0.isShared }.count
    }

    private func formatSize(_ bytes: Int64) -> String {
        let fmt = ByteCountFormatter()
        fmt.allowedUnits = [.useGB, .useMB, .useKB]
        fmt.countStyle = .file
        return fmt.string(fromByteCount: bytes)
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        HapticManager.impact(style)
    }
}

// MARK: - Shared Card Components

/// Wraps a section with a title label and a card container.
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.leading, 16)
                .padding(.bottom, 8)

            SettingsCard { content }
        }
    }
}

/// The rounded card container shared by all sections.
struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// A thin divider inside a card.
struct SettingsDivider: View {
    var body: some View {
        Divider().padding(.leading, 52)
    }
}

/// Non-clickable info row.
struct SettingsInfoRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            iconView
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var iconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(iconColor.opacity(0.15))
                .frame(width: 30, height: 30)
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(iconColor)
        }
    }
}

/// Tappable row with chevron.
struct SettingsActionRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String?
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                iconView
                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                Spacer()
                if let val = value {
                    Text(val)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
            .background(isPressed ? Color(.systemGray5) : Color.clear)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed))
    }

    private var iconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(iconColor.opacity(0.15))
                .frame(width: 30, height: 30)
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(iconColor)
        }
    }
}

/// Toggle row.
struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Press Button Style

struct PressableButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in
                isPressed = pressed
            }
    }
}
