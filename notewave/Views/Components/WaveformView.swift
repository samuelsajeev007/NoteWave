import SwiftUI

// MARK: - Bar Waveform (used in Player sheet)

/// Animated waveform bar chart. Pass `samples` (normalized 0…1 values).
struct WaveformView: View {
    var samples: [Float]
    var barColor: Color = .accentColor
    var backgroundColor: Color = Color(.systemGray6)
    var isRecording: Bool = false

    private let spacing: CGFloat = 2

    var body: some View {
        Canvas { ctx, size in
            let count = samples.count
            guard count > 0 else { return }
            let barWidth = (size.width - CGFloat(count - 1) * spacing) / CGFloat(count)
            let midY = size.height / 2

            for i in 0..<count {
                let amplitude = CGFloat(samples[i])
                let barHeight = max(3, amplitude * size.height * 0.9)
                let x = CGFloat(i) * (barWidth + spacing)
                let rect = CGRect(
                    x: x,
                    y: midY - barHeight / 2,
                    width: barWidth,
                    height: barHeight
                )
                let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)
                ctx.fill(path, with: .color(barColor.opacity(0.7 + 0.3 * Double(amplitude))))
            }
        }
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.1), value: samples.map { $0 })
    }
}

// MARK: - Playback Waveform (used in Player sheet progress)

/// Playback waveform – left side is "played" (accent), right is remaining (gray).
struct PlaybackWaveformView: View {
    var samples: [Float]
    var progress: Double  // 0…1

    var body: some View {
        Canvas { ctx, size in
            let count = samples.count
            guard count > 0 else { return }
            let spacing: CGFloat = 2
            let barWidth = (size.width - CGFloat(count - 1) * spacing) / CGFloat(count)
            let midY = size.height / 2
            let playedCount = Int(Double(count) * progress)

            for i in 0..<count {
                let amplitude = CGFloat(samples[i])
                let barHeight = max(3, amplitude * size.height * 0.9)
                let x = CGFloat(i) * (barWidth + spacing)
                let rect = CGRect(x: x, y: midY - barHeight / 2, width: barWidth, height: barHeight)
                let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)
                let color: Color = i < playedCount ? .accentColor : Color(.systemGray4)
                ctx.fill(path, with: .color(color))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Liquid Wave (used in Recording bottom panel)

/// Smooth animated sine-wave that fills from the curve down — matches the design's water-wave recording indicator.
struct LiquidWaveView: View {
    /// Drives horizontal movement — connect to a TimelineView Date or a @State phase.
    var phase: Double
    /// Loudness from mic, 0…1 — controls wave height
    var amplitude: Double

    /// Primary wave color (semi-transparent blue/lavender)
    var waveColor: Color = Color(hue: 0.62, saturation: 0.35, brightness: 0.80)
    /// Secondary wave (slightly offset for depth)
    var waveColor2: Color = Color(hue: 0.62, saturation: 0.25, brightness: 0.88)

    var body: some View {
        Canvas { ctx, size in
            // Draw two overlapping waves for a natural look
            ctx.fill(wavePath(size: size, phase: phase, amplitude: amplitude, verticalOffset: 0.52),
                     with: .color(waveColor2.opacity(0.55)))
            ctx.fill(wavePath(size: size, phase: phase + 1.2, amplitude: amplitude * 0.7, verticalOffset: 0.48),
                     with: .color(waveColor.opacity(0.75)))
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func wavePath(size: CGSize, phase: Double, amplitude: Double, verticalOffset: Double) -> Path {
        let clampedAmp = max(0.06, min(0.22, amplitude * 0.22))
        let baseY = size.height * verticalOffset
        var path = Path()
        path.move(to: CGPoint(x: 0, y: baseY))

        // Draw smooth sine curve across width
        let step: CGFloat = 2
        var x: CGFloat = 0
        while x <= size.width {
            let normalizedX = Double(x / size.width)
            let y = baseY + CGFloat(sin(normalizedX * .pi * 4 + phase) * clampedAmp * Double(size.height))
            if x == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
            x += step
        }

        // Close path to bottom corners to create filled shape
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }
}

#Preview {
    LiquidWaveView(phase: 0, amplitude: 0.5)
        .frame(height: 64)
        .padding()
}
