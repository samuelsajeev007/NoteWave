import SwiftUI

struct SplashView: View {
    @State private var opacity: Double = 0
    @State private var scale: Double = 0.85
    var onFinish: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(.white)
                }
                .shadow(color: Color.accentColor.opacity(0.35), radius: 20, y: 8)

                Text("NoteWave")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("Voice Notes")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7)) {
                opacity = 1
                scale = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.4)) { opacity = 0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onFinish() }
            }
        }
    }
}
