import SwiftUI

struct MergeAudioView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm: MergeAudioViewModel
    @State private var activeSlot: Int = 1  // 1 or 2 — which slot user is picking for
    @State private var showPicker = false
    @State private var playerVM = PlayerViewModel(player: AudioPlayerManager())
    @State private var selectedRecording: Recording?
    private let repository: RecordingRepository

    init(repository: RecordingRepository) {
        self.repository = repository
        _vm = State(initialValue: MergeAudioViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch vm.mergeState {
                case .idle:
                    idleView
                case .merging:
                    mergingView
                case .success(let rec):
                    successView(rec)
                case .failure(let err):
                    failureView(err)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Merge Audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear { vm.loadRecordings() }
        .sheet(isPresented: $showPicker) {
            MergePickerSheet(vm: vm, slot: activeSlot)
        }
        .sheet(item: $selectedRecording) { rec in
            PlayerSheetView(
                recording: rec,
                vm: playerVM,
                dashVM: DashboardViewModel(repository: repository)
            )
        }
    }

    // MARK: - Idle (selection) view

    private var idleView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Select two recordings to combine them into one.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                // Slot cards
                VStack(spacing: 12) {
                    AudioSlotCard(
                        slot: 1,
                        recording: vm.firstRecording,
                        onTap: { activeSlot = 1; showPicker = true }
                    )
                    // Merge icon between slots
                    HStack(spacing: 8) {
                        Color(.separator).frame(height: 1)
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.accentColor.opacity(0.7))
                        Color(.separator).frame(height: 1)
                    }
                    .padding(.horizontal, 40)
                    AudioSlotCard(
                        slot: 2,
                        recording: vm.secondRecording,
                        onTap: { activeSlot = 2; showPicker = true }
                    )
                }
                .padding(.horizontal, 16)

                // Merge button
                Button {
                    HapticManager.medium()
                    vm.performMerge()
                } label: {
                    Label("Merge Recordings", systemImage: "waveform.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(vm.canMerge ? Color.accentColor : Color(.systemGray4))
                        .foregroundStyle(vm.canMerge ? .white : Color(.systemGray))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 16)
                .disabled(!vm.canMerge)
                .animation(.easeInOut(duration: 0.2), value: vm.canMerge)
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Merging (progress) view

    private var mergingView: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Circle()
                    .stroke(Color.accentColor.opacity(0.15), lineWidth: 8)
                    .frame(width: 110, height: 110)
                Circle()
                    .trim(from: 0, to: vm.mergeProgress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 110, height: 110)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.15), value: vm.mergeProgress)
                VStack(spacing: 4) {
                    Image(systemName: "waveform.badge.plus")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.accentColor)
                    Text("\(Int(vm.mergeProgress * 100))%")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            VStack(spacing: 8) {
                Text("Merging Audio...")
                    .font(.system(size: 20, weight: .semibold))
                Text("Combining recordings")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Success view

    private func successView(_ rec: Recording) -> some View {
        VStack(spacing: 28) {
            Spacer()
            // Success icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 90, height: 90)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.green)
            }
            VStack(spacing: 6) {
                Text("Merged Recording Ready")
                    .font(.system(size: 22, weight: .bold))
                Text(rec.title)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                Text(rec.formattedDuration)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }

            // Action buttons
            VStack(spacing: 12) {
                Button {
                    selectedRecording = rec
                } label: {
                    Label("Play", systemImage: "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                HStack(spacing: 12) {
                    Button {
                        shareRecording(rec)
                    } label: {
                        Label("Share", systemImage: "paperplane")
                            .font(.system(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        vm.reset()
                        dismiss()
                    } label: {
                        Label("Save & Close", systemImage: "checkmark")
                            .font(.system(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    // MARK: - Failure view

    private func failureView(_ error: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.orange)
            VStack(spacing: 8) {
                Text("Merge Failed")
                    .font(.system(size: 22, weight: .bold))
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Button("Try Again") { vm.reset() }
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Spacer()
        }
    }

    private func shareRecording(_ rec: Recording) {
        let av = UIActivityViewController(activityItems: [rec.fileURL], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.rootViewController?
            .present(av, animated: true)
    }
}

// MARK: - AudioSlotCard

private struct AudioSlotCard: View {
    let slot: Int
    let recording: Recording?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(recording != nil ? Color.accentColor : Color(.systemGray5))
                        .frame(width: 40, height: 40)
                    Text("\(slot)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(recording != nil ? .white : Color(.systemGray2))
                }

                VStack(alignment: .leading, spacing: 3) {
                    if let rec = recording {
                        Text(rec.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Text(rec.formattedDuration)
                            Text("·")
                            Text(rec.formattedCreatedDate)
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    } else {
                        Text(slot == 1 ? "Select First Audio" : "Select Second Audio")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                        Text("Tap to choose")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MergePickerSheet

private struct MergePickerSheet: View {
    var vm: MergeAudioViewModel
    let slot: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(vm.allRecordings) { rec in
                let isOtherSlot = slot == 1 ? (vm.secondRecording?.id == rec.id) : (vm.firstRecording?.id == rec.id)
                Button {
                    if !isOtherSlot {
                        vm.select(rec, slot: slot)
                        dismiss()
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(rec.title)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(isOtherSlot ? .secondary : .primary)
                            HStack(spacing: 6) {
                                Text(rec.formattedDuration)
                                Text("·")
                                Text(rec.formattedCreatedDate)
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if isOtherSlot {
                            Text("Already selected")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        } else if vm.selectionLabel(for: rec) != nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .opacity(isOtherSlot ? 0.4 : 1)
                }
                .disabled(isOtherSlot)
                .buttonStyle(.plain)
            }
            .navigationTitle(slot == 1 ? "Select First Audio" : "Select Second Audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// End of MergeAudioView.swift
