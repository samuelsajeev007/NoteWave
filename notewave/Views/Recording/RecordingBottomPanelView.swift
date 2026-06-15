import SwiftUI

/// Bottom recording panel.
/// Chevron toggle → collapses/expands wave+done.
/// Wave pill and Done button: same height, both Capsule shaped.
struct RecordingBottomPanelView: View {
    @Bindable var vm: RecordingViewModel

    @State private var wavePhase: Double = 0
    @State private var isExpanded: Bool = true  // toggles with chevron

    private static let pillHeight: CGFloat = 60

    private var currentAmplitude: Double {
        Double(vm.waveformSamples.last ?? 0.15)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // ── Main Panel Content ──────────────────────────────────
            VStack(spacing: 12) {
                if isExpanded {
                    waveformPill
                    doneButton
                } else {
                    // Placeholder space to maintain a minimal panel height when collapsed
                    Color.clear.frame(height: 12)
                }
            }
            .padding(.top, 28) // Padding to give space below the half-outside chevron
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 20, y: -4)

            // ── Floating Chevron toggle ───────────────────────────────
            Button {
                HapticManager.light()
                withAnimation(.spring(duration: 0.35)) { isExpanded.toggle() }
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.15), radius: 5, y: 2)
                    )
            }
            .buttonStyle(.plain)
            .offset(y: -18) // Position exactly half outside the top edge
        }
        .padding(.top, 18) // Prevent the floating button's shadow from being clipped by the parent layout
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 4
            }
        }
    }

    // MARK: - Wave Pill (Capsule)

    private var waveformPill: some View {
        ZStack {
            // Gray Capsule background
            Capsule()
                .fill(Color(.systemGray6))
                .frame(height: Self.pillHeight)

            // Liquid wave clipped to Capsule
            LiquidWaveView(phase: wavePhase, amplitude: currentAmplitude)
                .frame(height: Self.pillHeight)
                .clipShape(Capsule())

            // Pause icon + timer — centered on the wave
            HStack(spacing: 14) {
                Button {
                    HapticManager.light()
                    if vm.isPaused { vm.resume() } else { vm.pause() }
                } label: {
                    Image(systemName: vm.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                Text(vm.duration.formattedMMSS)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Done Button (Capsule, same height as pill)

    private var doneButton: some View {
        Button {
            HapticManager.heavy()
            vm.finish()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.pillHeight)     // same height as wave pill
            .background(
                Capsule()
                    .fill(Color.green.opacity(0.15))
            )
        }
        .foregroundStyle(Color.green)
    }
}
