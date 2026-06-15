import SwiftUI

// MARK: - Suggestions Section

struct AISuggestionsSection: View {
    @Bindable var vm: AIAssistantViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Suggestions")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.suggestions, id: \.self) { suggestion in
                        SuggestionChip(text: suggestion) {
                            vm.executeSuggestion(suggestion)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Chip

private struct SuggestionChip: View {
    let text: String
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text(text)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color(.secondarySystemBackground))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = true } }
                .onEnded   { _ in withAnimation(.spring(duration: 0.3)) { isPressed = false } }
        )
    }
}
