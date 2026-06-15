import SwiftUI

// MARK: - Prompt Bar

struct AIPromptBar: View {
    @Bindable var vm: AIAssistantViewModel
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(alignment: .bottom, spacing: 8) {
                // Keyboard dismiss button — only visible when keyboard is open
                if isFocused {
                    Button {
                        isFocused = false
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }

                // Text editor with placeholder
                ZStack(alignment: .topLeading) {
                    if vm.inputText.isEmpty {
                        Text("Ask anything about your recordings…")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .padding(.top, 10)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $vm.inputText)
                        .font(.system(size: 15))
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                        .frame(minHeight: 36, maxHeight: 120)
                        .focused($isFocused)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                // Send button
                Button {
                    HapticManager.medium()
                    isFocused = false
                    vm.send()
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isProcessing
                                    ? Color(.systemGray4) : Color.accentColor
                            )
                            .frame(width: 36, height: 36)
                        if vm.isProcessing {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isProcessing)
                .animation(.easeInOut(duration: 0.2),
                           value: vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .animation(.spring(duration: 0.25), value: isFocused)
        }
    }
}
