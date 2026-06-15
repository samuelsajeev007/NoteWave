import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private let appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // App Icon + Name
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 88, height: 88)
                        Image(systemName: "waveform")
                            .font(.system(size: 38, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 12, y: 6)

                    Text("NoteWave")
                        .font(.system(size: 26, weight: .bold))
                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)

                // Info Card
                SettingsCard {
                    AboutRow(label: "Developer", value: "Samuel Sajeev")
                    Divider().padding(.leading, 16)
                    AboutRow(label: "Platform", value: "iOS 17+")
                    Divider().padding(.leading, 16)
                    AboutRow(label: "Framework", value: "SwiftUI + SwiftData")
                    Divider().padding(.leading, 16)
                    AboutRow(label: "Version", value: "\(appVersion) (\(buildNumber))")
                }

                // Links Card
                SettingsCard {
                    AboutLinkRow(label: "Privacy Policy", icon: "lock.shield") {
                        // Open privacy policy URL when available
                    }
                    Divider().padding(.leading, 16)
                    AboutLinkRow(label: "Terms of Service", icon: "doc.text") {
                        // Open terms URL
                    }
                    Divider().padding(.leading, 16)
                    AboutLinkRow(label: "Open Source Licenses", icon: "curlybraces") {
                        // Open licenses screen
                    }
                }

                // Roadmap Card
                VStack(alignment: .leading, spacing: 0) {
                    Text("FUTURE ROADMAP")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 16)
                        .padding(.bottom, 8)

                    SettingsCard {
                        RoadmapRow(icon: "icloud.and.arrow.up", label: "iCloud Sync", status: "Planned")
                        Divider().padding(.leading, 44)
                        RoadmapRow(icon: "person.2", label: "Collaboration & Sharing", status: "Planned")
                        Divider().padding(.leading, 44)
                        RoadmapRow(icon: "waveform.and.mic", label: "Speaker Identification", status: "Planned")
                        Divider().padding(.leading, 44)
                        RoadmapRow(icon: "doc.text.magnifyingglass", label: "Search Within Transcript", status: "In Progress")
                        Divider().padding(.leading, 44)
                        RoadmapRow(icon: "watchos.app", label: "Apple Watch App", status: "Planned")
                    }
                }

                Text("")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Helpers

private struct AboutRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct AboutLinkRow: View {
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)
                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct RoadmapRow: View {
    let icon: String
    let label: String
    let status: String

    var statusColor: Color {
        status == "In Progress" ? .orange : .secondary
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            Text(label)
                .font(.system(size: 15))
            Spacer()
            Text(status)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(statusColor.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
