import SwiftUI

// MARK: - Audio Picker Sheet

struct AIAudioPickerSheet: View {
    @Bindable var vm: AIAssistantViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    private var filtered: [Recording] {
        if searchText.isEmpty { return vm.allRecordings }
        return vm.allRecordings.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.allRecordings.isEmpty {
                    emptyState
                } else {
                    recordingList
                }
            }
            .navigationTitle("Select Audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .searchable(text: $searchText, prompt: "Search recordings")
        }
    }

    // MARK: - List

    private var recordingList: some View {
        List {
            ForEach(filtered) { rec in
                PickerRow(
                    recording: rec,
                    isSelected: vm.selectedRecordings.contains(where: { $0.id == rec.id })
                ) {
                    vm.toggleSelect(recording: rec)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "waveform.slash")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("No recordings yet")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - Picker Row

private struct PickerRow: View {
    let recording: Recording
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Selection indicator
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color(.systemGray5))
                        .frame(width: 26, height: 26)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .animation(.spring(duration: 0.2), value: isSelected)

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(recording.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if recording.isStarred {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                        }
                    }
                    Text(recording.formattedDuration + " · " + recording.formattedCreatedDate)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Tags / summary indicator
                if recording.transcript != nil {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green.opacity(0.8))
                }
            }
        }
        .buttonStyle(.plain)
    }
}
