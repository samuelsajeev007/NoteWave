import SwiftUI
import AVFoundation

// MARK: - Export Format Sheet

struct ExportFormatSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var settings = AppSettings.shared

    // Recordings to pick from — populated by caller
    var recordings: [Recording]

    @State private var selectedRecording: Recording?
    @State private var showRecordingPicker = false
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var showExportDone = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Description
                Text("Convert and export a recording to the selected format.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                // Format selection card
                VStack(spacing: 0) {
                    ForEach(Array(ExportFormat.allCases.enumerated()), id: \.element.id) { index, format in
                        FormatRow(format: format, isSelected: settings.exportFormat == format) {
                            HapticManager.light()
                            settings.exportFormat = format
                        }
                        if index < ExportFormat.allCases.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.bottom, 20)

                // Recording picker button
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Recording to Export")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 16)

                    Button {
                        showRecordingPicker = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                if let rec = selectedRecording {
                                    Text(rec.title)
                                        .font(.system(size: 16))
                                        .foregroundStyle(.primary)
                                    Text(rec.formattedDuration)
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Choose a recording…")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)
                }

                // Export button
                if selectedRecording != nil {
                    Button {
                        exportSelectedRecording()
                    } label: {
                        if isExporting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        } else {
                            Text("Export as \(settings.exportFormat.displayName)")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                    }
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .disabled(isExporting)
                }

                if let err = exportError {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }

                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Export Audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showRecordingPicker) {
                RecordingPickerSheet(recordings: recordings, selected: $selectedRecording)
            }
            .alert("Export Complete", isPresented: $showExportDone) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Recording exported successfully.")
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Export Logic

    private func exportSelectedRecording() {
        guard let recording = selectedRecording else { return }
        isExporting  = true
        exportError  = nil

        Task {
            do {
                let outputURL = try await convertAndExport(recording: recording, format: settings.exportFormat)
                await MainActor.run {
                    isExporting = false
                    presentShareSheet(for: outputURL)
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = error.localizedDescription
                }
            }
        }
    }

    private func convertAndExport(recording: Recording, format: ExportFormat) async throws -> URL {
        let sourceURL = recording.fileURL
        let asset = AVURLAsset(url: sourceURL)

        let outputName = "\(recording.title).\(format.fileExtension)"
        let outputURL  = FileManager.default.temporaryDirectory.appendingPathComponent(outputName)

        // Remove stale temp file if exists
        try? FileManager.default.removeItem(at: outputURL)

        switch format {
        case .aac:
            return try await exportWithSession(asset: asset, outputURL: outputURL, fileType: .m4a, preset: AVAssetExportPresetAppleM4A)
        case .mp3:
            return try await exportWithSession(asset: asset, outputURL: outputURL, fileType: .mp3, preset: AVAssetExportPresetAppleM4A)
        case .wav:
            return try await exportWithSession(asset: asset, outputURL: outputURL, fileType: .wav, preset: AVAssetExportPresetPassthrough)
        }
    }

    private func exportWithSession(asset: AVURLAsset, outputURL: URL, fileType: AVFileType, preset: String) async throws -> URL {
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw NSError(domain: "Export", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot create export session."])
        }
        session.outputURL      = outputURL
        session.outputFileType = fileType

        await session.export()

        if let error = session.error { throw error }
        guard session.status == .completed else {
            throw NSError(domain: "Export", code: -2, userInfo: [NSLocalizedDescriptionKey: "Export failed."])
        }
        return outputURL
    }

    private func presentShareSheet(for url: URL) {
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.rootViewController?
            .present(av, animated: true)
    }
}

// MARK: - FormatRow

private struct FormatRow: View {
    let format: ExportFormat
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Radio button indicator
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

                Text(format.displayName)
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)

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


// MARK: - Recording Picker Sheet

private struct RecordingPickerSheet: View {
    let recordings: [Recording]
    @Binding var selected: Recording?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(recordings) { rec in
                Button {
                    selected = rec
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(rec.title)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.primary)
                            HStack(spacing: 8) {
                                Text(rec.formattedDuration)
                                Text("·")
                                Text(rec.formattedCreatedDate)
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selected?.id == rec.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Select Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
