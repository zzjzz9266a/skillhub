import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // ── Toolbar ──────────────────────────────────────────
            HStack(spacing: 0) {
                Spacer().frame(width: 80)

                Spacer()

                HStack(spacing: 10) {
                    Text("SkillHub")
                        .font(.system(size: 13, weight: .semibold))

                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        TextField("Search skills…", text: $viewModel.searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .frame(width: viewModel.searchText.isEmpty ? 160 : 240)
                            .animation(.easeInOut(duration: 0.15), value: viewModel.searchText.isEmpty)
                            .focused($searchFocused)
                        if !viewModel.searchText.isEmpty {
                            Button {
                                viewModel.searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("⌘F")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.quaternary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }

                Spacer()

                HStack(spacing: 4) {
                    Button {
                        viewModel.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                    .help("Refresh")

                    Button {
                        viewModel.showAddSourcePopover.toggle()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .help("Add source")
                    .popover(isPresented: $viewModel.showAddSourcePopover, arrowEdge: .top) {
                        AddSourcePopoverView(viewModel: viewModel)
                    }
                }
                .padding(.trailing, 14)
            }
            .frame(height: 56)
            .background {
                VisualEffectView(material: .menu, blendingMode: .withinWindow)
                    .ignoresSafeArea()
            }
            .overlay(alignment: .bottom) { Divider() }

            // ── Body ─────────────────────────────────────────────
            HStack(spacing: 0) {
                SidebarView(viewModel: viewModel)
                    .frame(width: 260)

                VStack(spacing: 0) {
                    SkillMatrixView(viewModel: viewModel)
                    FooterStatusBar(viewModel: viewModel)
                }
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
        .frame(minWidth: 860, minHeight: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            viewModel.refresh()
        }
        .onTapGesture {
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
        .sheet(isPresented: $viewModel.showPreview) {
            PreviewInstallView(viewModel: viewModel)
        }
        .onKeyPress(.init("f"), phases: .down) { press in
            if press.modifiers.contains(.command) {
                searchFocused = true
                return .handled
            }
            return .ignored
        }
    }
}
