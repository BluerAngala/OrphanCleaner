import SwiftUI

@main
struct OrphanCleanerApp: App {
    @StateObject private var viewModel = CleanerViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowResizability(.contentMinSize)
        .windowStyle(.titleBar)
    }
}
