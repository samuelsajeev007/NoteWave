import SwiftUI

// MARK: - Quality Picker Sheet

struct QualityPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var settings = AppSettings.shared

    private let options: [QualityOption] = [
        QualityOption(kbps: 64,  label: "64 kbps",  description: "Smaller file size",   isDefault: false),
        QualityOption(kbps: 128, label: "128 kbps", description: "Recommended",          isDefault: true),
        QualityOption(kbps: 256, label: "256 kbps", description: "Highest quality",      isDefault: false),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header description
                VStack(spacing: 4) {
                    Text("Applies to new recordings only.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)

                // Options card
                VStack(spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        QualityOptionRow(
                            option: option,
                            isSelected: settings.recordingQualityKbps == option.kbps
                        ) {
                            HapticManager.light()
                            settings.recordingQualityKbps = option.kbps
                        }
                        if index < options.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)

                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Recording Quality")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Shared model

fileprivate struct QualityOption {
    let kbps: Int
    let label: String
    let description: String
    let isDefault: Bool
}

// MARK: - Row

private struct QualityOptionRow: View {
    let option: QualityOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Selection indicator circle
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.accentColor : Color(.systemGray3), lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 12, height: 12)
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: isSelected)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(option.label)
                            .font(.system(size: 16))
                            .foregroundStyle(.primary)
                        if option.isDefault {
                            Text("Default")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor)
                                .clipShape(Capsule())
                        }
                    }
                    Text(option.description)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? Color.accentColor.opacity(0.06) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
