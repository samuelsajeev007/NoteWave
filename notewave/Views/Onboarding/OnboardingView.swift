import SwiftUI

private struct OnboardingPage {
    let title: String
    let description: String
    let icon: String
    let gradient: [Color]
}

struct OnboardingView: View {
    @State private var currentPage = 0
    var onFinish: () -> Void

    private let pages: [OnboardingPage] = [
        .init(title: "Welcome to NoteWave",
              description: "Record, organize and manage voice recordings easily.",
              icon: "mic.fill",
              gradient: [Color(hue: 0.62, saturation: 0.7, brightness: 0.9),
                         Color(hue: 0.62, saturation: 0.5, brightness: 0.7)]),
        .init(title: "Playback and Share",
              description: "Play, share and manage recordings anytime.",
              icon: "play.circle.fill",
              gradient: [Color(hue: 0.55, saturation: 0.7, brightness: 0.9),
                         Color(hue: 0.55, saturation: 0.5, brightness: 0.7)]),
        .init(title: "Ready to Start",
              description: "Start recording and manage your audio library.",
              icon: "waveform",
              gradient: [Color(hue: 0.38, saturation: 0.65, brightness: 0.85),
                         Color(hue: 0.38, saturation: 0.5, brightness: 0.65)])
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { i in
                    pageView(pages[i]).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            // Dots
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { i in
                    Circle()
                        .fill(i == currentPage ? Color.accentColor : Color(.systemGray4))
                        .frame(width: i == currentPage ? 10 : 7, height: i == currentPage ? 10 : 7)
                        .animation(.spring(), value: currentPage)
                }
            }
            .padding(.vertical, 16)

            // Buttons
            HStack(spacing: 12) {
                if currentPage > 0 {
                    Button("Back") { withAnimation { currentPage -= 1 } }
                        .buttonStyle(.bordered)
                        .tint(.secondary)
                }
                Spacer()
                if currentPage == 0 {
                    Button("Skip") { onFinish() }
                        .foregroundStyle(.secondary)
                }
                if currentPage < pages.count - 1 {
                    Button("Next") { withAnimation { currentPage += 1 } }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Start") { onFinish() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: page.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 160, height: 160)
                    .shadow(color: page.gradient[0].opacity(0.4), radius: 24, y: 10)
                Image(systemName: page.icon)
                    .font(.system(size: 72))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
            }
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(page.description)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
    }
}
