import SwiftUI

struct PlayerSheetView: View {
    let recording: Recording
    @Bindable var vm: PlayerViewModel
    var dashVM: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    // Pre-computed once so the view never crashes during body re-evaluation
    private let waveformSamples: [Float]

    init(recording: Recording, vm: PlayerViewModel, dashVM: DashboardViewModel) {
        self.recording = recording
        self.vm = vm
        self.dashVM = dashVM
        // Safe seed: use bitPattern to handle negative hashValue
        let rawHash = recording.id.hashValue
        let seed = UInt64(bitPattern: Int64(rawHash))
        var rng = SeededRNG(seed: seed == 0 ? 1 : seed)
        self.waveformSamples = (0..<80).map { _ in Float(rng.next()) * 0.85 + 0.15 }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Title
                Text(recording.title)
                    .font(.system(size: 18, weight: .semibold))
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .multilineTextAlignment(.center)

                Text(recording.formattedCreatedDate)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)

                // Time labels — use recording.duration as fallback while
                // the AVAudioPlayer hasn't finished loading yet (avoids 0:00 flash).
                let displayDuration = vm.duration > 0 ? vm.duration : recording.duration
                let progress = displayDuration > 0 ? vm.currentTime / displayDuration : 0
                PlaybackWaveformView(
                    samples: waveformSamples,
                    progress: progress
                )
                .frame(height: 60)
                .padding(.horizontal, 20)

                // Time labels
                HStack {
                    Text(vm.currentTime.formattedMMSS)
                    Spacer()
                    Text(displayDuration.formattedMMSS)
                }
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 6)

                // Seek slider
                Slider(value: Binding(
                    get: { displayDuration > 0 ? vm.currentTime / displayDuration : 0 },
                    set: { vm.seek(to: $0) }
                ))
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .tint(.accentColor)

                // Playback controls
                HStack(spacing: 32) {
                    Button { vm.toggleRepeat() } label: {
                        Image(systemName: "repeat")
                            .font(.system(size: 20))
                            .foregroundStyle(vm.isRepeatEnabled ? Color.accentColor : .secondary)
                    }

                    Button { vm.seekAbsolute(to: max(0, vm.currentTime - 15)) } label: {
                        Image(systemName: "gobackward.15")
                            .font(.system(size: 26))
                    }
                    .foregroundStyle(.primary)

                    Button { vm.togglePlay() } label: {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 64, height: 64)
                            Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(.white)
                        }
                    }
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 10, y: 4)

                    Button { vm.seekAbsolute(to: min(vm.duration, vm.currentTime + 15)) } label: {
                        Image(systemName: "goforward.15")
                            .font(.system(size: 26))
                    }
                    .foregroundStyle(.primary)

                    Menu {
                        ForEach(vm.availableSpeeds, id: \.self) { spd in
                            Button("\(spd == 1.0 ? "1" : String(format: "%g", spd))×") {
                                vm.setSpeed(spd)
                            }
                        }
                    } label: {
                        Text("\(vm.playbackSpeed == 1.0 ? "1" : String(format: "%g", vm.playbackSpeed))×")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 40)
                    }
                    .foregroundStyle(.primary)
                }
                .padding(.top, 24)

                // ── Playback error banner ──────────────────────────────────
                if let playErr = vm.player.lastError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                        Text(playErr)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }

                // ── Captions: always shown — tries to generate if not yet available ──
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            vm.toggleCaptions(for: recording)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: vm.isTranscribing ? "ellipsis" : "captions.bubble")
                                    .symbolEffect(.pulse, isActive: vm.isTranscribing)
                                Text(vm.showCaptions ? "Hide Captions" : "Captions")
                                    .font(.system(size: 14))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(vm.showCaptions ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
                            .clipShape(Capsule())
                        }
                        .foregroundStyle(vm.showCaptions ? Color.accentColor : .primary)
                        .disabled(vm.isTranscribing)

                        if vm.isTranscribing {
                            HStack(spacing: 6) {
                                ProgressView().scaleEffect(0.8)
                                Text("Transcribing…")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.leading, 8)
                        }
                    }
                    .padding(.top, 20)

                    // Error message when transcript fails
                    if let err = vm.transcriptError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 12))
                            Text(err)
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.top, 6)
                    }

                    // Caption text
                    if vm.showCaptions && !vm.segments.isEmpty {
                        captionsView
                    }
                }

                Spacer()
            }
            .padding(.top, 16)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        vm.stop()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            vm.load(url: recording.fileURL, title: recording.title, recordingID: recording.id)
        }
        .onDisappear {
            let joined = vm.segments.map { $0.text }.joined(separator: " ")
            if !joined.isEmpty, recording.transcript == nil {
                dashVM.saveTranscript(for: recording, text: joined)
            }
        }
    }

    private var captionsView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                FlowLayout(horizontalSpacing: 4, verticalSpacing: 6) {
                    ForEach(vm.segments) { seg in
                        let isCurrent = vm.segments.count > 1 && (vm.currentSegmentIndex.map { vm.segments[$0].id == seg.id } ?? false)
                        Text(seg.text)
                            .font(.system(size: 16, weight: isCurrent ? .semibold : .regular))
                            .foregroundStyle(isCurrent ? Color.accentColor : .primary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                isCurrent
                                    ? Color.accentColor.opacity(0.15)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .id(seg.id)
                            .onTapGesture { vm.seekAbsolute(to: seg.timestamp) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: 240)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .onChange(of: vm.currentSegmentIndex) { _, idx in
                guard let idx, idx < vm.segments.count else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(vm.segments[idx].id, anchor: .center)
                }
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

// Simple seeded LCG for deterministic waveform display
private struct SeededRNG {
    var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 33) / Double(UInt64(1) << 31)
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = 4
    var verticalSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, hSpacing: horizontalSpacing, vSpacing: verticalSpacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, hSpacing: horizontalSpacing, vSpacing: verticalSpacing)
        for (index, subview) in subviews.enumerated() {
            let point = result.frames[index].origin
            subview.place(at: CGPoint(x: point.x + bounds.minX, y: point.y + bounds.minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []

        init(in maxWidth: CGFloat, subviews: Subviews, hSpacing: CGFloat, vSpacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth, currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + vSpacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                
                currentX += size.width + hSpacing
                lineHeight = max(lineHeight, size.height)
            }
            
            size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}
