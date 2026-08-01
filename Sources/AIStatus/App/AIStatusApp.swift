import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // This is intentionally a menu-bar-first utility with no persistent Dock icon.
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
@MainActor
struct AIStatusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store: StatusStore

    init() {
        let initialStore = StatusStore()
        initialStore.start()
        _store = State(initialValue: initialStore)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarStatusView(store: store)
                .environment(\.locale, store.language.locale)
        } label: {
            HStack(spacing: 4) {
                Image(nsImage: MenuBarIconFactory.image(for: store.overallHealth))
                    .id(store.overallHealth)
                    .accessibilityLabel(store.overallHealth.title(in: store.language))
                if store.showsServiceCount {
                    Text("\(store.operationalCount)/\(store.services.count)")
                }
            }
        }
        .menuBarExtraStyle(.window)

        Window("AI Status", id: "dashboard") {
            DashboardView(store: store)
                .frame(minWidth: 760, minHeight: 570)
                .environment(\.locale, store.language.locale)
        }
        .defaultSize(width: 900, height: 680)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView(store: store)
                .environment(\.locale, store.language.locale)
        }
    }
}
