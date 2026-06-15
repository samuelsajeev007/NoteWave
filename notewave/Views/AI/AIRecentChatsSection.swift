import SwiftUI

// MARK: - Recent Chats Section

struct AIRecentChatsSection: View {
    @Bindable var vm: AIAssistantViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent AI Chats")

            if vm.recentChats.isEmpty {
                emptyState
            } else {
                chatList
            }
        }
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 30))
                    .foregroundStyle(.quaternary)
                Text("No recent chats")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 24)
            Spacer()
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var chatList: some View {
        VStack(spacing: 0) {
            ForEach(Array(vm.recentChats.prefix(5).enumerated()), id: \.element.id) { idx, chat in
                RecentChatRow(chat: chat) {
                    vm.deleteChat(chat)
                }
                if idx < min(vm.recentChats.count, 5) - 1 {
                    Divider().padding(.horizontal, 14)
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
    }
}

// MARK: - Chat Row

private struct RecentChatRow: View {
    let chat: AIChat
    let onDelete: () -> Void

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

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                HapticManager.warning()
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
