import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(viewModel: viewModel)
                .frame(width: 220)

            VStack(spacing: 0) {
                SkillMatrixView(viewModel: viewModel)

                InstallBarView(viewModel: viewModel)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            viewModel.refresh()
        }
        .sheet(isPresented: $viewModel.showPreview) {
            PreviewInstallView(viewModel: viewModel)
        }
    }
}
