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

        if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            let outSize = NSSize(width: 256, height: 256)
            let clipped = NSImage(size: outSize, flipped: false) { rect in
                let inset = rect.insetBy(dx: 14, dy: 14)
                let path = NSBezierPath(roundedRect: inset, xRadius: 52, yRadius: 52)
                path.addClip()
                icon.draw(in: inset, from: .zero, operation: .sourceOver, fraction: 1.0)
                return true
            }
            NSApp.applicationIconImage = clipped
        }

        menuBarView = MenuBarView(viewModel: viewModel, appDelegate: self)
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
        guard let window = mainWindow else {
            print("[SkillHub] showMainWindow — window is nil after createMainWindow")
            return
        }

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
