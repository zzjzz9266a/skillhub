import AppKit

final class MenuBarView: NSObject {
    private var statusItem: NSStatusItem!
    private weak var viewModel: AppViewModel?
    private weak var appDelegate: AppDelegate?

    init(viewModel: AppViewModel, appDelegate: AppDelegate) {
        self.viewModel = viewModel
        self.appDelegate = appDelegate
        super.init()
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateButtonTitle()
        buildMenu()
    }

    func updateButtonTitle() {
        guard let button = statusItem.button else { return }
        let count = viewModel?.visibleAgents.count ?? 0
        button.image = NSImage(systemSymbolName: "hammer.fill", accessibilityDescription: "SkillHub")
        if count > 0 {
            button.title = " \(count)"
        } else {
            button.title = ""
        }
        button.toolTip = "SkillHub — \(count) agent\(count == 1 ? "" : "s") detected"
    }

    func buildMenu() {
        let menu = NSMenu()

        guard let vm = viewModel else {
            statusItem.menu = menu
            return
        }

        // Agent status section
        if !vm.visibleAgents.isEmpty {
            let agentHeader = NSMenuItem(title: "Agents", action: nil, keyEquivalent: "")
            agentHeader.isEnabled = false
            agentHeader.attributedTitle = makeHeader("Agents")
            menu.addItem(agentHeader)

            for agent in vm.visibleAgents {
                let indicator = agent.installed ? "●" : "○"
                let item = NSMenuItem(title: "  \(indicator) \(agent.name)", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }

            menu.addItem(.separator())
        }

        // Skills by source
        if !vm.sources.isEmpty {
            let primaryAgent = vm.visibleAgents.first

            for source in vm.sources {
                let sourceItem = NSMenuItem(title: source.label, action: nil, keyEquivalent: "")
                sourceItem.image = NSImage(systemSymbolName: "shippingbox", accessibilityDescription: nil)

                let groupSkills = Dictionary(grouping: vm.skillsForSource(source.id)) { skill in
                    skill.groups.first ?? "ungrouped"
                }

                let submenu = NSMenu()
                for (groupName, skills) in groupSkills.sorted(by: { a, b in a.key < b.key }) {
                    let groupItem = NSMenuItem(title: groupName, action: nil, keyEquivalent: "")
                    groupItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)

                    let skillMenu = NSMenu()
                    for skill in skills {
                        let enabled = primaryAgent.flatMap { vm.agentSkillStates[$0.id]?[skill.id] } ?? false
                        let skillItem = NSMenuItem(
                            title: skill.name,
                            action: #selector(toggleSkillFromMenu(_:)),
                            keyEquivalent: ""
                        )
                        skillItem.target = self
                        skillItem.state = enabled ? .on : .off
                        skillItem.representedObject = SkillToggleInfo(
                            skillId: skill.id,
                            agentId: primaryAgent?.id
                        )
                        skillMenu.addItem(skillItem)
                    }

                    // Group-level toggle
                    if let agent = primaryAgent {
                        skillMenu.insertItem(.separator(), at: 0)
                        let toggleAll = NSMenuItem(
                            title: skills.allSatisfy({ vm.agentSkillStates[agent.id]?[$0.id] ?? false })
                                ? "Turn All Off" : "Turn All On",
                            action: #selector(toggleGroupFromMenu(_:)),
                            keyEquivalent: ""
                        )
                        toggleAll.target = self
                        toggleAll.representedObject = GroupToggleInfo(
                            sourceId: source.id,
                            groupName: groupName,
                            agentId: agent.id
                        )
                        skillMenu.insertItem(toggleAll, at: 0)
                    }

                    groupItem.submenu = skillMenu
                    submenu.addItem(groupItem)
                }
                sourceItem.submenu = submenu
                menu.addItem(sourceItem)
            }

            menu.addItem(.separator())
        }

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

    // MARK: - Actions

    @objc private func openMainWindow() {
        appDelegate?.showMainWindow()
    }

    @objc private func refresh() {
        viewModel?.refresh()
        updateButtonTitle()
        buildMenu()
    }

    @objc private func toggleSkillFromMenu(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? SkillToggleInfo,
              let agentId = info.agentId,
              let vm = viewModel else { return }
        let newState = sender.state != .on
        vm.toggleSkill(skillId: info.skillId, agentId: agentId, enabled: newState)
        sender.state = newState ? .on : .off
    }

    @objc private func toggleGroupFromMenu(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? GroupToggleInfo,
              let vm = viewModel else { return }
        let groupSkills = vm.skills.filter { skill in
            skill.sourceId == info.sourceId
                && (skill.groups.isEmpty ? info.groupName == "ungrouped" : skill.groups.contains(info.groupName))
        }
        let allEnabled = groupSkills.allSatisfy { vm.agentSkillStates[info.agentId]?[$0.id] ?? false }
        vm.toggleGroup(sourceId: info.sourceId, groupName: info.groupName, agentId: info.agentId, enabled: !allEnabled)
        buildMenu()
    }

    // MARK: - Helpers

    private func makeHeader(_ text: String) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [.font: NSFont.systemFont(ofSize: 11, weight: .semibold)]
        )
    }
}

// MARK: - Represented objects for menu items

private class SkillToggleInfo: NSObject {
    let skillId: Int64
    let agentId: Int64?
    init(skillId: Int64, agentId: Int64?) {
        self.skillId = skillId
        self.agentId = agentId
    }
}

private class GroupToggleInfo: NSObject {
    let sourceId: Int64
    let groupName: String
    let agentId: Int64
    init(sourceId: Int64, groupName: String, agentId: Int64) {
        self.sourceId = sourceId
        self.groupName = groupName
        self.agentId = agentId
    }
}
