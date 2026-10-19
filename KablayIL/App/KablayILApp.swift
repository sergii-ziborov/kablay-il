import SwiftUI

@main
struct KablayILApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var appState = AppState()

    init() {
        // Portfolio originals are full-size photos, and the default shared cache
        // is far too small to hold them, so every visit to the catalog fetched
        // the same pictures again over mobile data.
        URLCache.shared = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 512 * 1024 * 1024
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(\.locale, appState.locale.locale)
                .environment(\.layoutDirection, appState.locale.layoutDirection)
                .tint(Brand.red)
                .onReceive(NotificationCenter.default.publisher(for: .kablayRemoteDeviceToken)) { event in
                    guard let token = event.object as? String else { return }
                    Task { await appState.registerRemoteToken(token) }
                }
                .onReceive(NotificationCenter.default.publisher(for: .kablayNotificationTapped)) { event in
                    appState.handleNotificationPayload(event.userInfo ?? [:])
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background, appState.isAuthenticated {
                        appState.appLock.lock()
                    } else if phase == .active, appState.hasRestoredSavedSnapshots {
                        Task { await appState.refreshSavedContent() }
                    }
                }
        }
    }
}
