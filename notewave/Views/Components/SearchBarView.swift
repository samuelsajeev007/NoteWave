import SwiftUI

struct SearchBarView: View {
    @Binding var text: String
    var onAskAI: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            // Search field — takes all remaining space
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color(.systemGray2))
                    .font(.system(size: 15))
                TextField("Search", text: $text)
                    .font(.system(size: 15))
                    .submitLabel(.search)
                    .foregroundStyle(.primary)
                if !text.isEmpty {
                    Button { text = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color(.systemGray3))
                    }
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 8)

            // Ask AI — white pill, no divider, floats inside gray container
            Button(action: onAskAI) {
                HStack(spacing: 5) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 13, weight: .medium))
                    Text("Ask AI")
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.07), radius: 4, y: 1)
            }
            .foregroundStyle(.primary)
            .padding(.trailing, 6)
        }
        .frame(height: 46)
        .background(Color(.systemGray6))
        .clipShape(Capsule())          // full pill shape, matching design
    }
}
