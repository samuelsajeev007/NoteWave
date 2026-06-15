import SwiftUI

struct RecordingCardView: View {
    let recording: Recording
    let vm: DashboardViewModel
    var onPlay: () -> Void

    @State private var showMoreMenu = false
    @State private var showDeleteConfirm = false
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var showDetails = false
    @State private var showShareSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Date + time
            Text(recording.formattedCreatedDate)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            // Title
            Text(recording.title)
                .font(.system(size: 17, weight: .semibold))
                .lineLimit(2)

            // Action row
            HStack(spacing: 8) {
                // Play button
                Button {
                    HapticManager.light()
                    onPlay()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                        Text(recording.formattedDuration)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
                }
                .foregroundStyle(.primary)
                .buttonStyle(.plain)

                Spacer()

                // Star / Unstar
                iconButton(recording.isStarred ? "doc.plaintext.fill" : "doc.plaintext") { vm.toggleStar(recording) }
                    .foregroundStyle(recording.isStarred ? Color.orange : Color.primary)

                // Rename
                iconButton("pencil.and.outline") {
                    renameText = recording.title
                    showRenameAlert = true
                }

                // Share
                iconButton("paperplane") { showShareSheet = true }

                // More
                iconButton("ellipsis") { showMoreMenu = true }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .confirmationDialog("", isPresented: $showMoreMenu) {
            Button("View Details") { showDetails = true }
            Button("Export Audio") { exportAudio() }
            if recording.transcript != nil {
                Button("Export Transcript") { exportTranscript() }
            }
            Button("Delete", role: .destructive) { showDeleteConfirm = true }
        }
        // ── Delete confirmation ────────────────────────────────────
        .alert("Delete Recording?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { vm.deleteRecording(recording) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        // ── Rename alert ───────────────────────────────────────────
        .alert("Rename Recording", isPresented: $showRenameAlert) {
            TextField("Recording name", text: $renameText)
            Button("Save") {
                let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    vm.renameRecording(recording, to: trimmed)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showDetails) { DetailsView(recording: recording) }
        .sheet(isPresented: $showShareSheet) { ShareSheetView(recording: recording, vm: vm) }

        Divider().padding(.horizontal, 16)
    }

    @ViewBuilder
    private func iconButton(_ name: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.light()
            action()
        } label: {
            Image(systemName: name)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 32, height: 32)
                .background(Color(.systemGray6))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private func exportAudio() {
        let url = recording.fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.rootViewController?
            .present(picker, animated: true)
    }

    private func exportTranscript() {
        guard let text = recording.transcript else { return }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(recording.title).txt")
        try? text.write(to: tmp, atomically: true, encoding: .utf8)
        let picker = UIDocumentPickerViewController(forExporting: [tmp], asCopy: true)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.rootViewController?
            .present(picker, animated: true)
    }
}

// MARK: - Details

struct DetailsView: View {
    let recording: Recording
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                row("Title", recording.title)
                row("Duration", recording.formattedDuration)
                row("Created", DateFormatter.fullDateTime.string(from: recording.createdDate))
                row("File Size", recording.formattedFileSize)
                row("Format", recording.audioFormat)
                row("Bitrate", "\(recording.bitRate / 1000) kbps")
                row("Path", recording.filePath)
                row("Source", recording.isImported ? "Imported" : "Recorded")
                row("Shared", recording.isShared ? "Yes" : "No")
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing).font(.system(size: 14))
        }
    }
}

// MARK: - Share Sheet

struct ShareSheetView: View {
    let recording: Recording
    let vm: DashboardViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showSystemShare = false

    var body: some View {
        NavigationStack {
            List {
                Button { share(medium: "General") } label: {
                    Label("Share via…", systemImage: "square.and.arrow.up")
                }
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .sheet(isPresented: $showSystemShare) {
            SystemShareSheet(url: recording.fileURL)
        }
    }

    private func share(medium: String) {
        vm.markShared(recording, medium: medium)
        showSystemShare = true
    }
}

struct SystemShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
