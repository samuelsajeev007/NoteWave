import SwiftUI

struct MergedAudioLibraryView: View {
    let repository: RecordingRepository

    @State private var recordings: [Recording] = []
    @State private var playerVM = PlayerViewModel(player: AudioPlayerManager())
    @State private var selectedRecording: Recording?
    @State private var dashVM: DashboardViewModel

    init(repository: RecordingRepository) {
        self.repository = repository
        _dashVM = State(initialValue: DashboardViewModel(repository: repository))
    }

    var body: some View {
        Group {
            if recordings.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "waveform.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No Merged Recordings")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Merge audio files from the Audio Tools section.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(recordings) { rec in
                            RecordingCardView(recording: rec, vm: dashVM) {
                                selectedRecording = rec
                            }
                        }
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("Merged Library")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadRecordings() }
        .sheet(item: $selectedRecording) { rec in
            PlayerSheetView(recording: rec, vm: playerVM, dashVM: dashVM)
                .onDisappear { loadRecordings() }
        }
    }

    private func loadRecordings() {
        recordings = (try? repository.fetchMerged()) ?? []
    }
}
