import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            if appState.requiresInitialAppLockSetup {
                AppLockSetupView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else if appState.isAuthenticated, appState.appLock.isLocked {
                AppUnlockView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            } else {
                Group {
                    if appState.isProfessional, appState.workspaceMode == .professional {
                        ProfessionalRootView()
                    } else {
                        ClientRootView()
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.snappy, value: appState.workspaceMode)
        .animation(.snappy, value: appState.appLock.isLocked)
        .animation(.snappy, value: appState.appLock.isConfigured)
        .alert(
            appState.locale.text(he: "לא ניתן להשלים", ru: "Не удалось выполнить", en: "Couldn’t complete"),
            isPresented: Binding(
                get: { appState.errorMessage != nil },
                set: { if !$0 { appState.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
        .sheet(
            item: Binding(
                get: { appState.pendingNotificationDestination },
                set: { appState.pendingNotificationDestination = $0 }
            )
        ) { destination in
            NavigationStack {
                NotificationDestinationView(destination: destination)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(appState.locale.text(he: "סגירה", ru: "Закрыть", en: "Close")) {
                                appState.pendingNotificationDestination = nil
                            }
                        }
                    }
            }
        }
        .sheet(
            item: Binding(
                get: { appState.pendingSpecialistDestination },
                set: { appState.pendingSpecialistDestination = $0 }
            )
        ) { destination in
            NavigationStack {
                DeepLinkedSpecialistView(specialistID: destination.id)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(appState.locale.text(he: "סגירה", ru: "Закрыть", en: "Close")) {
                                appState.pendingSpecialistDestination = nil
                            }
                        }
                    }
            }
        }
        .sheet(item: Binding(
            get: { appState.isProfessional ? appState.pendingBillingPage : nil },
            set: { appState.pendingBillingPage = $0 }
        )) { page in
            NavigationStack {
                Group {
                    if page == .premium { PremiumView() }
                    else { CreditsView() }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(appState.locale.text(he: "סגירה", ru: "Закрыть", en: "Close")) {
                            appState.pendingBillingPage = nil
                        }
                    }
                }
            }
        }
        .onOpenURL { appState.handleUniversalLink($0) }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL { appState.handleUniversalLink(url) }
        }
        .task(id: appState.session?.token) {
            await appState.restoreSavedSnapshots()
            async let role: Void = appState.refreshSessionRole()
            async let content: Void = appState.refreshSavedContent()
            async let alerts: Void = appState.loadNotifications()
            _ = await (role, content, alerts)
        }
    }
}

private struct DeepLinkedSpecialistView: View {
    @Environment(AppState.self) private var appState
    let specialistID: String
    @State private var specialist: Specialist?
    @State private var didLoad = false

    var body: some View {
        Group {
            if let specialist {
                SpecialistProfileView(specialist: specialist)
            } else if didLoad {
                ContentUnavailableView(
                    appState.locale.text(he: "בעל המקצוע אינו זמין", ru: "Мастер недоступен", en: "Specialist unavailable"),
                    systemImage: "person.crop.circle.badge.questionmark"
                )
            } else {
                ProgressView()
            }
        }
        .task(id: specialistID) {
            await appState.loadSpecialists(force: true)
            specialist = appState.specialists.first { candidate in
                candidate.id.caseInsensitiveCompare(specialistID) == .orderedSame
            }
            didLoad = true
        }
    }
}

private struct ClientRootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        TabView(selection: $state.clientTab) {
            Tab(appState.locale.text(he: "קטלוג", ru: "Каталог", en: "Catalog"), systemImage: "square.grid.2x2.fill", value: AppState.ClientTab.catalog) {
                NavigationStack { CatalogHomeView() }
            }
            Tab(appState.locale.text(he: "בקשה", ru: "Заявка", en: "Request"), systemImage: "plus.circle.fill", value: AppState.ClientTab.request) {
                NavigationStack { TaskWizardView() }
            }
            Tab(appState.locale.text(he: "הבקשות שלי", ru: "Мои заявки", en: "My requests"), systemImage: "doc.text.fill", value: AppState.ClientTab.tasks) {
                NavigationStack { ClientTasksView() }
            }
            Tab(appState.locale.text(he: "מדריכים", ru: "Гайды", en: "Guides"), systemImage: "book.pages.fill", value: AppState.ClientTab.content) {
                NavigationStack { ContentHubView() }
            }
            Tab(appState.locale.text(he: "חשבון", ru: "Кабинет", en: "Account"), systemImage: "person.crop.circle.fill", value: AppState.ClientTab.account) {
                NavigationStack { AccountView() }
            }
            .badge(appState.unreadCount)
        }
    }
}
