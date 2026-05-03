import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var menuBarView: MenuBarView?
    let viewModel: AppViewModel
    private var mainWindow: NSWindow?

    override init() {
        viewModel = AppViewModel()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        menuBarView = MenuBarView(viewModel: viewModel)
        viewModel.refresh()
        menuBarView?.updateButtonTitle()
        menuBarView?.buildMenu()

        showMainWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func showMainWindow() {
        if mainWindow == nil {
            createMainWindow()
        }
        guard let window = mainWindow else { return }

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async {
            window.makeFirstResponder(nil)
        }
    }

    private func createMainWindow() {
        let contentView = ContentView().environmentObject(viewModel)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "SkillHub"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.setContentSize(NSSize(width: 1040, height: 680))
        window.minSize = NSSize(width: 860, height: 520)
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.center()
        mainWindow = window
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === mainWindow {
            sender.orderOut(nil)
            return false
        }
        return true
    }
}
