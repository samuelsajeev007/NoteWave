import SwiftUI

// MARK: - AI Response Cards

/// Renders the appropriate card based on response type.
struct AIResponseCard: View {
    let response: AIResponse
    let vm: AIAssistantViewModel

    @State private var showShareSheet = false
    @State private var shareText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardContent
            actionBar
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(text: shareText)
        }
    }

    // MARK: - Card Content

    @ViewBuilder
    private var cardContent: some View {
        switch response {
        case .summary(let text, let rec):
            SummaryCard(text: text, recording: rec)

        case .title(let proposed, let rec):
            TitleCard(proposed: proposed, recording: rec, vm: vm)

        case .tasks(let items, let rec):
            TasksCard(items: items, recording: rec)

        case .tags(let items, let rec):
            TagsCard(items: items, recording: rec)

        case .searchResults(let results):
            SearchResultsCard(results: results)

        case .answer(let text, let sources):
            AnswerCard(text: text, sources: sources)

        case .insights(let text):
            InsightsCard(text: text)

        case .freeform(let text):
            FreeformCard(text: text)

        case .error(let msg):
            ErrorCard(message: msg, vm: vm)
        }
    }

    // MARK: - Action Bar (not shown for errors)

    @ViewBuilder
    private var actionBar: some View {
        if case .error = response {
            EmptyView()
        } else {
            HStack(spacing: 16) {
                actionButton("doc.on.doc", label: "Copy") {
                    UIPasteboard.general.string = plainText
                    HapticManager.light()
                }
                actionButton("square.and.arrow.up", label: "Share") {
                    shareText = plainText
                    showShareSheet = true
                    HapticManager.light()
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .overlay(alignment: .top) { Divider() }
        }
    }

    private func actionButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private var plainText: String {
        switch response {
        case .summary(let t, _):        return t
        case .title(let t, _):          return t
        case .tasks(let items, _):      return items.map { "• \($0)" }.joined(separator: "\n")
        case .tags(let items, _):       return items.joined(separator: ", ")
        case .searchResults(let rs):    return rs.map { $0.recording.title }.joined(separator: "\n")
        case .answer(let t, _):         return t
        case .insights(let t):          return t
        case .freeform(let t):          return t
        case .error(let t):             return t
        }
    }
}

// MARK: - Summary Card

private struct SummaryCard: View {
    let text: String
    let recording: Recording

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(.blue)
                Text("Summary")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.blue)
                Spacer()
                Text(recording.title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            ForEach(parseBullets(text), id: \.self) { bullet in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundStyle(.blue)
                        .font(.system(size: 14, weight: .bold))
                    Text(bullet)
                        .font(.system(size: 14))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
    }
}

// MARK: - Title Card

private struct TitleCard: View {
    let proposed: String
    let recording: Recording
    let vm: AIAssistantViewModel

    @State private var applied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "pencil.and.sparkles")
                    .foregroundStyle(.purple)
                Text("Suggested Title")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.purple)
            }

            Text("\"" + proposed + "\"")
                .font(.system(size: 17, weight: .semibold))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            if !applied {
                HStack(spacing: 10) {
                    Button {
                        vm.applyTitle(proposed, to: recording)
                        applied = true
                    } label: {
                        Text("Apply Title")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.purple)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Text("for \"\(recording.title)\"")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Label("Title applied!", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.green)
            }
        }
        .padding(14)
    }
}

// MARK: - Tasks Card

private struct TasksCard: View {
    let items: [String]
    let recording: Recording
    @State private var checked: Set<Int> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checklist")
                    .foregroundStyle(.green)
                Text("Tasks (\(items.count))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.green)
                Spacer()
                Text(recording.title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            ForEach(Array(items.enumerated()), id: \.offset) { idx, task in
                Button {
                    HapticManager.light()
                    if checked.contains(idx) { checked.remove(idx) } else { checked.insert(idx) }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: checked.contains(idx) ? "checkmark.square.fill" : "square")
                            .foregroundStyle(checked.contains(idx) ? .green : .secondary)
                            .font(.system(size: 17))
                        Text(task)
                            .font(.system(size: 14))
                            .strikethrough(checked.contains(idx))
                            .foregroundStyle(checked.contains(idx) ? .secondary : .primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
    }
}

// MARK: - Tags Card

private struct TagsCard: View {
    let items: [String]
    let recording: Recording

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .foregroundStyle(.orange)
                Text("Tags")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.orange)
                Spacer()
                Text(recording.title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            AITagFlowLayout(spacing: 8) {
                ForEach(items, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.12))
                        .foregroundStyle(Color.orange)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(14)
    }
}

// MARK: - Search Results Card

private struct SearchResultsCard: View {
    let results: [AIResponse.SearchResult]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.cyan)
                Text("\(results.count) Recording\(results.count == 1 ? "" : "s") Found")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.cyan)
            }

            if results.isEmpty {
                Text("No recordings matched your search.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(results, id: \.recording.id) { result in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(result.recording.title)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                            Text(result.recording.formattedCreatedDate + " · " + result.recording.formattedDuration)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        // Confidence dot
                        Circle()
                            .fill(Color.cyan)
                            .frame(width: 8, height: 8)
                    }
                    .padding(10)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(14)
    }
}

// MARK: - Answer Card

private struct AnswerCard: View {
    let text: String
    let sources: [Recording]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .foregroundStyle(.indigo)
                Text("Answer")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.indigo)
            }

            Text(text)
                .font(.system(size: 14))
                .fixedSize(horizontal: false, vertical: true)

            if !sources.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sources")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(sources) { rec in
                        Label(rec.title, systemImage: "waveform")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(10)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14)
    }
}

// MARK: - Insights Card

private struct InsightsCard: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundStyle(.red)
                Text("Recording Insights")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.red)
            }

            AttributedMarkdownText(text: text)
        }
        .padding(14)
    }
}

// MARK: - Freeform Card

private struct FreeformCard: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(text)
                .font(.system(size: 14))
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
        }
    }
}

// MARK: - Error Card

private struct ErrorCard: View {
    let message: String
    let vm: AIAssistantViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 16))
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Retry button
            Button {
                HapticManager.medium()
                vm.retryLast()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Retry")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
    }
}

// MARK: - Helpers

private func parseBullets(_ text: String) -> [String] {
    text.components(separatedBy: "\n")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
        .map { line in
            // Strip leading bullet characters
            var s = line
            for prefix in ["• ", "- ", "* ", "· "] {
                if s.hasPrefix(prefix) { s = String(s.dropFirst(prefix.count)) }
            }
            return s
        }
        .filter { !$0.isEmpty }
}

// MARK: - AttributedMarkdownText (bold headers)

private struct AttributedMarkdownText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(parsedLines, id: \.id) { line in
                if line.isBold {
                    Text(line.text)
                        .font(.system(size: 14, weight: .semibold))
                } else {
                    Text(line.text)
                        .font(.system(size: 14))
                        .foregroundStyle(line.text.hasPrefix("•") ? .primary : .secondary)
                }
            }
        }
    }

    private var parsedLines: [ParsedLine] {
        text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { line in
                let isBold = line.hasPrefix("**") && line.hasSuffix("**")
                let cleaned = isBold ? String(line.dropFirst(2).dropLast(2)) : line
                return ParsedLine(text: cleaned, isBold: isBold)
            }
    }

    private struct ParsedLine: Identifiable {
        let id = UUID()
        let text: String
        let isBold: Bool
    }
}

// MARK: - Flow Layout (for tags)

private struct AITagFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 300
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let text: String
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
