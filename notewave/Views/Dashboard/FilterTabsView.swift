import SwiftUI

struct FilterTabsView: View {
    @Binding var selected: RecordingFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RecordingFilter.allCases) { filter in
                    Button {
                        withAnimation(.spring(duration: 0.25)) { selected = filter }
                    } label: {
                        Text(filter.rawValue)
                            .font(.system(size: 14, weight: selected == filter ? .semibold : .regular))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                selected == filter
                                ? Color(.systemGray5)
                                : Color.clear
                            )
                            .clipShape(Capsule())
                    }
                    .foregroundStyle(selected == filter ? .primary : .secondary)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
