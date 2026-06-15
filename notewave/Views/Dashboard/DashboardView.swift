import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AVFoundation

struct DashboardView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.scenePhase)   private var scenePhase
    @State private var dashVM: DashboardViewModel
    @State private var recorderManager = AudioRecorderManager()
    @State private var playerManager = AudioPlayerManager()
    @State private var recordingVM: RecordingViewModel
    @State private var playerVM: PlayerViewModel
    @State private var aiVM: AIAssistantViewModel
    @State private var navPath = NavigationPath()
    @State private var selectedRecording: Recording? = nil
    @State private var dateStart = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    @State private var dateEnd = Date()
    @State private var showMicDenied = false

    init(modelContext: ModelContext) {
        let repo = RecordingRepository(context: modelContext)
        let dvm = DashboardViewModel(repository: repo)
        let recMan = AudioRecorderManager()
        let rvm = RecordingViewModel(recorder: recMan)
        let pvm = PlayerViewModel(player: AudioPlayerManager())
        let avm = AIAssistantViewModel(repository: repo)
        _dashVM = State(initialValue: dvm)
        _recorderManager = State(initialValue: recMan)
        _recordingVM = State(initialValue: rvm)
        _playerVM = State(initialValue: pvm)
        _aiVM = State(initialValue: avm)
    }

    var body: some View {
        NavigationStack(path: $navPath) {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Top bar
                topBar
                // Title
                HStack {
                    Text("NoteWave")
                        .font(.system(size: 34, weight: .bold))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 8)

                // Search
                SearchBarView(text: $dashVM.searchQuery) {
                    HapticManager.light()
                    navPath.append("ai")
                }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                // Filter tabs
                FilterTabsView(selected: $dashVM.activeFilter)
                    .padding(.bottom, 4)

                Divider()

                // List
                if dashVM.filteredRecordings.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(dashVM.filteredRecordings) { rec in
                                RecordingCardView(recording: rec, vm: dashVM) {
                                    selectedRecording = rec
                                }
                            }
                        }
                    }
                }
            }

            // Recording Panel overlay
            if recordingVM.isShowingPanel {
                Color.black.opacity(0.001) // absorb taps
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VStack {
                    Spacer()
                    RecordingBottomPanelView(vm: recordingVM)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
            }
        } // ZStack
        .navigationDestination(for: String.self) { dest in
            if dest == "ai" {
                AIAssistantView(vm: aiVM)
            }
        }
        .animation(.spring(duration: 0.4), value: recordingVM.isShowingPanel)
        .sheet(item: $selectedRecording) { rec in
            PlayerSheetView(recording: rec, vm: playerVM, dashVM: dashVM)
        }
        .sheet(isPresented: $dashVM.showDateFilter) {
            DateFilterSheetView(
                startDate: $dateStart,
                endDate: $dateEnd,
                onApply: { dashVM.applyDateFilter(start: dateStart, end: dateEnd) },
                onReset: { dashVM.clearDateFilter() }
            )
        }
        .sheet(isPresented: $dashVM.showSettings) { SettingsView() }
        .fileImporter(
            isPresented: $dashVM.showImportPicker,
            allowedContentTypes: [.audio, UTType(filenameExtension: "m4a")!, .mp3, UTType(filenameExtension: "wav")!],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                dashVM.importRecording(from: url)
            }
        }
        .alert("Microphone Access Denied", isPresented: $showMicDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable microphone access in Settings to record voice notes.")
        }
        .alert("Recover Recording?", isPresented: $recordingVM.showRecoveryPrompt) {
            Button("Recover") { recordingVM.recoverDraft() }
            Button("Delete", role: .destructive) { recordingVM.discardDraft() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A previous recording was interrupted. Would you like to recover it?")
        }
        .alert("Error", isPresented: Binding(
            get: { recordingVM.errorMessage != nil },
            set: { if !$0 { recordingVM.errorMessage = nil } }
        )) {
            Button("OK") { recordingVM.errorMessage = nil }
        } message: {
            Text(recordingVM.errorMessage ?? "")
        }
        .onAppear {
            setupRecordingVM()
            dashVM.loadRecordings()
            recordingVM.checkForDraftRecording()
        }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhaseChange(phase)
        }
        .onChange(of: recordingVM.isRecording) { _, isRecording in
            // Screen-awake: only prevent sleep while a recording is actually active.
            if AppSettings.shared.keepScreenAwake {
                UIApplication.shared.isIdleTimerDisabled = isRecording
            }
        }
        } // NavigationStack
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                HapticManager.medium()
                Task { await recordingVM.requestPermissionAndStart() }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 36, height: 36)
            }
            .foregroundStyle(.primary)

            Button {
                HapticManager.light()
                dashVM.showDateFilter = true
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 18))
                    .frame(width: 36, height: 36)
            }
            .foregroundStyle(.primary)

            Button {
                HapticManager.light()
                dashVM.showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18))
                    .frame(width: 36, height: 36)
            }
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "waveform.slash")
                .font(.system(size: 52))
                .foregroundStyle(.quaternary)
            Text(emptyStateText)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            if dashVM.activeFilter == .device {
                Button("Import Recording") { dashVM.showImportPicker = true }
                    .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
    }

    private var emptyStateText: String {
        switch dashVM.activeFilter {
        case .all:     return dashVM.searchQuery.isEmpty ? "No recordings yet.\nTap + to start recording." : "No results for \"\(dashVM.searchQuery)\""
        case .shared:  return "No shared recordings yet."
        case .starred: return "No starred recordings yet."
        case .device:  return "No imported recordings yet."
        }
    }

    // MARK: - Setup

    private func setupRecordingVM() {
        recordingVM.configure(
            onDraftStarted: { sid, tempURL, title in
                dashVM.handleDraftStarted(sessionId: sid, tempURL: tempURL, title: title)
            },
            onFinished: { url, duration, title, draftSid in
                dashVM.addRecording(title: title, url: url, duration: duration, draftSid: draftSid)
            },
            onDraftDiscarded: { sid in
                dashVM.deleteDraftEntry(sessionId: sid)
            }
        )
    }

    // MARK: - Scene Phase (Background / Foreground)

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background:
            if !AppSettings.shared.backgroundRecording {
                // ── Background recording OFF ─────────────────────────────────
                // 1. Auto-pause an active recording.
                if recordingVM.isRecording && !recordingVM.isPaused {
                    recordingVM.pause()
                    HapticManager.warning()
                }
                // 2. Stop any active audio playback — deactivate the audio session
                //    so the app doesn't consume audio resources in the background.
                if playerVM.isPlaying {
                    playerVM.player.pause()
                }
                Task.detached(priority: .background) {
                    // Deactivate audio session so the system can route audio normally.
                    AudioSessionManager.shared.deactivate()
                }
            }
            // Always reset screen-awake when backgrounded.
            UIApplication.shared.isIdleTimerDisabled = false

        case .active:
            // ── Returning to foreground ──────────────────────────────────────
            // Re-apply screen-awake only if actively recording.
            if AppSettings.shared.keepScreenAwake && recordingVM.isRecording {
                UIApplication.shared.isIdleTimerDisabled = true
            }
            // NOTE: If recording was auto-paused, we intentionally do NOT auto-resume.
            // The user must manually tap Play to resume — prevents accidental re-recording.

        case .inactive:
            break

        @unknown default:
            break
        }
    }
}

