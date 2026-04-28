import SwiftUI

@main
struct SkillHubApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            Text("SkillHub")
                .frame(minWidth: 800, minHeight: 600)
        }
    }
}
