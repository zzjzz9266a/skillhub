import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(viewModel: viewModel)
                .frame(width: 260)

            VStack(spacing: 0) {
                SkillMatrixView(viewModel: viewModel)

                InstallBarView(viewModel: viewModel)
            }
            .background(Color(nsColor: .windowBackgroundColor))
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
    }
}
