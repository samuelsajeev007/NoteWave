import SwiftUI

// MARK: - Selected Audio Section

struct AISelectedAudioSection: View {
    @Bindable var vm: AIAssistantViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Selected Audio")

            selectedCard
        }
    }

    @ViewBuilder
    private var selectedCard: some View {
        if vm.selectedRecordings.isEmpty {
            emptyCard
        } else {
            filledCard
        }
    }

    private var emptyCard: some View {
        Button {
            HapticManager.light()
            vm.showAudioPicker = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "waveform.badge.plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("No Audio Selected")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("Tap to select recordings for AI analysis")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private var filledCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(vm.selectedRecordings.enumerated()), id: \.element.id) { idx, rec in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.system(size: 18))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(rec.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        Text(rec.formattedDuration + " · " + rec.formattedCreatedDate)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        HapticManager.light()
                        vm.toggleSelect(recording: rec)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                if idx < vm.selectedRecordings.count - 1 {
                    Divider().padding(.horizontal, 14)
                }
            }

            Divider()

            HStack {
                Button {
                    HapticManager.light()
                    vm.showAudioPicker = true
                } label: {
                    Label("Add More", systemImage: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    HapticManager.light()
                    vm.clearSelection()
                } label: {
                    Text("Clear All")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
    }
}
