import SwiftUI

@main
struct SibilAppMain: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 480, height: 560)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 480, height: 560)
    }
}
