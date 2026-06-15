import SwiftUI

// MARK: - AI Tools Section
// Note: This section is no longer shown in the main UI.
// Kept for potential future use.

struct AIToolsSection: View {
    @Bindable var vm: AIAssistantViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "AI Tools")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AITool.allCases) { tool in
                        AIToolCard(tool: tool, isDisabled: vm.isProcessing) {
                            vm.executeTool(tool)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Tool Card

private struct AIToolCard: View {
    let tool: AITool
    let isDisabled: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(0.25))
                        .frame(width: 40, height: 40)
                    Image(systemName: tool.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Spacer()

                Text(tool.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(width: 110, height: 110)
            .background(
                LinearGradient(
                    colors: isDisabled
                        ? [Color(.systemGray3), Color(.systemGray4)]
                        : [Color.accentColor, Color.purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.accentColor.opacity(isDisabled ? 0 : 0.35), radius: 8, y: 4)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1.0)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = true } }
                .onEnded   { _ in withAnimation(.spring(duration: 0.3)) { isPressed = false } }
        )
    }
}
