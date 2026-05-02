import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var menuBarView: MenuBarView?
    let viewModel: AppViewModel
    private var mainWindow: NSWindow?
    private var fileWatcherStream: FSEventStreamRef?

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

        setupFileWatcher()
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
    }

    private func createMainWindow() {
        let contentView = ContentView().environmentObject(viewModel)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "SkillHub"
        window.setContentSize(NSSize(width: 800, height: 600))
        window.minSize = NSSize(width: 600, height: 400)
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
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

    // MARK: - FSEvents

    private func setupFileWatcher() {
        let hubPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".skillhub").path

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { (_, info, _, _, _, _) in
                guard let info = info else { return }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(info).takeUnretainedValue()
                guard Date().timeIntervalSince(delegate.viewModel.lastLocalWrite) >= 2.0 else { return }
                DispatchQueue.main.async {
                    delegate.viewModel.refresh()
                    delegate.menuBarView?.updateButtonTitle()
                    delegate.menuBarView?.buildMenu()
                }
            },
            &context,
            [hubPath] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            2.0,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)
        ) else { return }

        fileWatcherStream = stream
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
    }
}
