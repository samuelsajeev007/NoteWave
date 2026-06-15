import SwiftUI

// MARK: - AI Assistant Main View

struct AIAssistantView: View {
    @State var vm: AIAssistantViewModel
    @Namespace private var bottomID
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // ── Main Content ─────────────────────────────────────────────
            if vm.messages.isEmpty {
                discoveryView
            } else {
                // Compact context bar persists in chat mode
                chatContextBar
                chatView
            }

            // ── Prompt Bar ───────────────────────────────────────────────
            AIPromptBar(vm: vm, isFocused: $isInputFocused)
        }
        .navigationTitle("AI Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // History button — top left
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    HapticManager.light()
                    isInputFocused = false
                    vm.showHistory = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 14))
                        Text("History")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(Color.accentColor)
                }
            }

            // New Chat button — top right
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    HapticManager.medium()
                    isInputFocused = false
                    vm.newChat()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.bubble")
                            .font(.system(size: 14))
                        Text("New Chat")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                .disabled(vm.messages.isEmpty)
            }
        }
        // Tap anywhere on screen to dismiss keyboard
        .onTapGesture {
            isInputFocused = false
        }
        .sheet(isPresented: $vm.showAudioPicker) {
            AIAudioPickerSheet(vm: vm)
        }
        .sheet(isPresented: $vm.showHistory) {
            AIHistorySheet(vm: vm)
        }
        .onAppear {
            vm.loadData()
        }
    }

    // MARK: - Chat Context Bar (visible in chat mode)
    // Shows audio picker + suggestions so they remain accessible mid-chat

    private var chatContextBar: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Audio picker button
                    Button {
                        HapticManager.light()
                        isInputFocused = false
                        vm.showAudioPicker = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: vm.selectedRecordings.isEmpty ? "waveform" : "waveform.badge.plus")
                                .font(.system(size: 11, weight: .semibold))
                            Text(vm.selectedRecordings.isEmpty
                                 ? "Audio"
                                 : "\(vm.selectedRecordings.count) selected")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(vm.selectedRecordings.isEmpty ? Color.accentColor : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(vm.selectedRecordings.isEmpty
                                    ? Color.accentColor.opacity(0.12)
                                    : Color.accentColor)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    // Divider pip
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 1, height: 18)
                        .padding(.horizontal, 2)

                    // Suggestion chips
                    ForEach(vm.suggestions, id: \.self) { suggestion in
                        Button {
                            HapticManager.light()
                            isInputFocused = false
                            vm.executeSuggestion(suggestion)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "sparkle")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                                Text(suggestion)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.accentColor.opacity(0.2), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.isProcessing)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            Divider()
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Discovery View (no active chat)

    private var discoveryView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hero
                heroHeader
                    .padding(.horizontal, 16)

                // Selected Audio
                AISelectedAudioSection(vm: vm)

                // Suggestions — full wrap grid so all are visible
                suggestionGrid
                    .padding(.horizontal, 16)

                Spacer(minLength: 20)
            }
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        // Tap scroll area also dismisses keyboard
        .simultaneousGesture(
            TapGesture().onEnded { isInputFocused = false }
        )
    }

    // MARK: - Suggestions Grid (wrapping, all visible)

    private var suggestionGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Suggestions")
                .padding(.horizontal, 0)

            // Two-column grid of suggestion chips
            let cols = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(vm.suggestions, id: \.self) { suggestion in
                    Button {
                        HapticManager.light()
                        isInputFocused = false
                        vm.executeSuggestion(suggestion)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                            Text(suggestion)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Chat View

    private var chatView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(vm.messages) { msg in
                        AIChatBubble(message: msg, vm: vm)
                            .padding(.horizontal, 12)
                            .id(msg.id)
                    }

                    if vm.isProcessing {
                        AIThinkingBubble(label: vm.processingLabel)
                            .padding(.horizontal, 12)
                            .id("thinking")
                    }

                    Color.clear.frame(height: 1).id(bottomID)
                }
                .padding(.top, 16)
                .padding(.bottom, 8)
            }
            // Tap in chat area also dismisses keyboard
            .simultaneousGesture(
                TapGesture().onEnded { isInputFocused = false }
            )
            .onChange(of: vm.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
            .onChange(of: vm.isProcessing) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(colors: [.purple, .blue],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                    )
                    .frame(width: 52, height: 52)
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("AI Assistant")
                    .font(.system(size: 18, weight: .bold))
                Text("Analyze, summarize & explore your recordings")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - History Sheet

struct AIHistorySheet: View {
    @Bindable var vm: AIAssistantViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if vm.recentChats.isEmpty {
                    emptyHistory
                } else {
                    historyList
                }
            }
            .navigationTitle("Chat History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var historyList: some View {
        List {
            ForEach(vm.recentChats) { chat in
                HistoryRow(chat: chat)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            HapticManager.warning()
                            vm.deleteChat(chat)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyHistory: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("No chat history yet")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
            Text("Start a conversation to see it here")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }
}

// MARK: - History Row

private struct HistoryRow: View {
    let chat: AIChat

    private var toolColor: Color {
        switch chat.toolType {
        case "summarize":      return .blue
        case "generate_title": return .purple
        case "extract_tasks":  return .green
        case "generate_tags":  return .orange
        case "ai_search":      return .cyan
        case "ask_about":      return .indigo
        case "insights":       return .red
        default:               return Color.accentColor
        }
    }

    private var toolIcon: String {
        switch chat.toolType {
        case "summarize":      return "text.alignleft"
        case "generate_title": return "pencil.and.sparkles"
        case "extract_tasks":  return "checklist"
        case "generate_tags":  return "tag"
        case "ai_search":      return "magnifyingglass"
        case "ask_about":      return "bubble.left.and.bubble.right"
        case "insights":       return "chart.bar.xaxis"
        default:               return "sparkles"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(toolColor.opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: toolIcon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(toolColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(chat.displayTitle)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                Text(chat.relativeDate)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Shared Section Header

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}

// MARK: - Color from hex

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
