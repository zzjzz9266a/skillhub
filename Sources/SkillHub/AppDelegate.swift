import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarView: MenuBarView?
    var viewModel: AppViewModel!
    private var fileWatcherStream: FSEventStreamRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        viewModel = AppViewModel()
        menuBarView = MenuBarView(viewModel: viewModel)
        viewModel.refresh()
        menuBarView?.buildMenu()

        setupFileWatcher()
    }

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
