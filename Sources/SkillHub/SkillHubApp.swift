import SwiftUI

@main
struct SkillHubApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("SkillHub", id: "main") {
            ContentView()
                .environmentObject(appDelegate.viewModel)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
