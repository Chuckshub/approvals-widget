import SwiftUI

@main
struct ApprovalsWidgetApp: App {
    @StateObject private var store = ApprovalsStore()

    var body: some Scene {
        MenuBarExtra(store.statusLabel) {
            ContentView(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}
