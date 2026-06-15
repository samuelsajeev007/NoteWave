import SwiftUI

struct DateFilterSheetView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    var onApply: () -> Void
    var onReset: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Start Date") {
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                }
                Section("End Date") {
                    DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                }
            }
            .navigationTitle("Filter by Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") { onReset(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { onApply(); dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
