import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var menuBarView: MenuBarView?
    let viewModel: AppViewModel
    private weak var mainWindow: NSWindow?
    private var fileWatcherStream: FSEventStreamRef?

    override init() {
        viewModel = AppViewModel()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarView = MenuBarView(viewModel: viewModel)
        viewModel.refresh()
        menuBarView?.buildMenu()

        setupFileWatcher()

        createMainWindow()
    }

    func openMainWindow() {
        if let window = mainWindow {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        } else {
            // Window was destroyed — recreate it
            createMainWindow()
            openMainWindow()
        }
    }

    private func createMainWindow() {
        let contentView = ContentView().environmentObject(viewModel)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "SkillHub"
        window.setContentSize(NSSize(width: 800, height: 600))
        window.minSize = NSSize(width: 600, height: 400)
        window.delegate = self
        window.styleMask.insert(.resizable)
        window.styleMask.insert(.fullSizeContentView)
        window.isReleasedWhenClosed = false
        mainWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
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
                DispatchQueue.main.async {
                    delegate.viewModel.refresh()
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
