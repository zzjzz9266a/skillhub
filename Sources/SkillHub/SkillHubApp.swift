import SwiftUI

@main
struct SkillHubApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {} // Required scene placeholder — actual window managed by AppDelegate
    }
}
