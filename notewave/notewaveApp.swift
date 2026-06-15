import SwiftUI
import SwiftData

@main
struct notewaveApp: App {

    @State private var showSplash = true
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "nw_onboardingDone")

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    SplashView {
                        showSplash = false
                    }
                } else if showOnboarding {
                    OnboardingView {
                        UserDefaults.standard.set(true, forKey: "nw_onboardingDone")
                        showOnboarding = false
                    }
                } else {
                    // Pass modelContext from the container to DashboardView
                    ModelContainerReader { container in
                        DashboardView(modelContext: container.mainContext)
                    }
                }
            }
        }
        .modelContainer(for: [Recording.self, AIChat.self])
    }
}

/// Helper to read the ModelContainer from environment inside WindowGroup.
private struct ModelContainerReader<Content: View>: View {
    @Environment(\.modelContext) private var ctx
    let content: (ModelContainer) -> Content

    init(@ViewBuilder content: @escaping (ModelContainer) -> Content) {
        self.content = content
    }

    var body: some View {
        content(ctx.container)
    }
}
