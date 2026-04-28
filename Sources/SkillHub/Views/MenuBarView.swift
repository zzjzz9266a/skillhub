import AppKit

final class MenuBarView: NSObject {
    private var statusItem: NSStatusItem!
    private weak var viewModel: AppViewModel?

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        super.init()
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "SkillHub"
            button.image = NSImage(systemSymbolName: "hammer.fill", accessibilityDescription: "SkillHub")
            button.toolTip = "SkillHub - AI Agent Skill Manager"
        }

        buildMenu()
    }

    func buildMenu() {
        let menu = NSMenu()

        guard let vm = viewModel else {
            statusItem.menu = menu
            return
        }

        for source in vm.sources {
            let sourceItem = NSMenuItem(title: source.label, action: nil, keyEquivalent: "")
            sourceItem.image = NSImage(systemSymbolName: "shippingbox", accessibilityDescription: nil)
            sourceItem.isEnabled = true

            let groupSkills = Dictionary(grouping: vm.skillsForSource(source.id)) { skill in
                skill.groups.first ?? "ungrouped"
            }

            let submenu = NSMenu()
            for (groupName, skills) in groupSkills {
                let groupItem = NSMenuItem(title: groupName, action: nil, keyEquivalent: "")
                groupItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)

                let skillMenu = NSMenu()
                for skill in skills {
                    let skillItem = NSMenuItem(title: skill.name, action: nil, keyEquivalent: "")
                    skillItem.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
                    skillMenu.addItem(skillItem)
                }
                groupItem.submenu = skillMenu
                submenu.addItem(groupItem)
            }
            sourceItem.submenu = submenu
            menu.addItem(sourceItem)
        }

        menu.addItem(.separator())

        let openItem = NSMenuItem(title: "Open Main Window", action: #selector(openMainWindow), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit SkillHub", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func openMainWindow() {
        (NSApp.delegate as? AppDelegate)?.showMainWindow()
    }

    @objc private func refresh() {
        viewModel?.refresh()
        buildMenu()
    }
}
