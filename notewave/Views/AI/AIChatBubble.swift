import SwiftUI

// MARK: - Chat Bubble

struct AIChatBubble: View {
    let message: AIMessage
    let vm: AIAssistantViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .assistant {
                assistantAvatar
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if message.role == .user {
                    userBubble
                } else {
                    assistantBubble
                }

                Text(timeString(from: message.createdAt))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }

            if message.role == .user {
                Spacer(minLength: 60)
            }
        }
    }

    // MARK: - User Bubble

    private var userBubble: some View {
        Group {
            if case .freeform(let text) = message.response {
                Text(text)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 16, bottomLeadingRadius: 16,
                            bottomTrailingRadius: 4, topTrailingRadius: 16
                        )
                    )
            }
        }
    }

    // MARK: - Assistant Bubble

    private var assistantBubble: some View {
        AIResponseCard(response: message.response, vm: vm)
    }

    // MARK: - Avatar

    private var assistantAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(colors: [.purple, .blue],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
                .frame(width: 32, height: 32)
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private func timeString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}

// MARK: - Thinking Bubble

struct AIThinkingBubble: View {
    let label: String
    @State private var dots = 0

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.purple, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing))
                    .frame(width: 32, height: 32)
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                HStack(spacing: 3) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 5, height: 5)
                            .opacity(dots == i ? 1.0 : 0.3)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 4, bottomLeadingRadius: 16,
                    bottomTrailingRadius: 16, topTrailingRadius: 16
                )
            )

            Spacer(minLength: 60)
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    dots = (dots + 1) % 3
                }
            }
        }
    }
}
