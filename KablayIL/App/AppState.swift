import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class AppState {
    enum BillingPage: String, Identifiable {
        case credits
        case premium
        var id: String { rawValue }
    }
    enum ClientTab: Hashable {
        case catalog
        case request
        case tasks
        case content
        case account
    }

    enum RequestEntryMode: Hashable {
        case direct
        case routed
    }

    enum WorkspaceMode: String, Hashable {
        case client
        case professional
    }

    /// Consent to send Smart Search text to the third-party AI classifier, and
    /// the version of the disclosure that was agreed to. Nothing is sent before
    /// this is granted, and revoking it leaves the catalog fully usable.
    var smartSearchAIConsentVersion: Int {
        didSet {
            UserDefaults.standard.set(smartSearchAIConsentVersion, forKey: "smart-search-ai-consent-version")
        }
    }

    var hasSmartSearchAIConsent: Bool {
        smartSearchAIConsentVersion >= SmartSearchPrivacy.consentVersion
    }

    var languagePreference: AppLanguagePreference {
        didSet {
            UserDefaults.standard.set(languagePreference.rawValue, forKey: "app-language-preference")
            UserDefaults.standard.removeObject(forKey: "app-locale")
        }
    }
    var locale: AppLocale {
        languagePreference.manualLocale ?? AppLocale.preferred(from: Locale.preferredLanguages)
    }
    var session: AuthSession?
    var taskDraft = TaskDraft()
    var clientTab: ClientTab = .catalog
    var requestEntryMode: RequestEntryMode = .direct
    var otpNameRequired = false
    var notifications: [AppNotification] = []
    var notificationPreferences: NotificationPreferences = .enabled
    var blogArticles: [BlogArticle] = []
    var blogLoadedPage = 0
    var blogPages = 1
    private var blogFreshIDs: Set<String> = []
    var clientTasks: [RepairTask] = []
    var clientTasksLoadedPage = 0
    var clientTasksPages = 1
    private var clientTaskFreshIDs: Set<String> = []
    var professionalProfile: ProfessionalProfile?
    var professionalProfileUpdatedAt: Date?
    var professionalProfileShowingSavedCopy = false
    var professionalLeads: [ProfessionalLead] = []
    var professionalLeadsLoadedPage = 0
    var professionalLeadsPages = 1
    private var professionalLeadFreshIDs: Set<String> = []
    var professionalProposals: [ProfessionalProposal] = []
    var professionalProposalsUpdatedAt: Date?
    var professionalProposalsShowingSavedCopy = false
    var archivedProfessionalProposalIDs: Set<String> = []
    var professionalConversations: [ProfessionalConversation] = []
    var professionalConversationsUpdatedAt: Date?
    var professionalConversationsShowingSavedCopy = false
    var professionalStats: ProfessionalStats?
    var professionalStatsUpdatedAt: Date?
    var professionalStatsShowingSavedCopy = false
    var creditAccount: CreditAccount?
    var pendingNotificationDestination: NotificationDestination?
    var pendingSpecialistDestination: SpecialistDestination?
    var pendingBillingPage: BillingPage?
    var isWorking = false
    var errorMessage: String?
    var publishedTaskID: String?
    var lastTriage: TriageResult?
    var serviceCatalog: [ServiceCategory]
    var serviceCatalogVersion: String?
    var serviceCatalogUpdatedAt: Date?
    private var didAttemptServiceCatalogRefresh = false
    private var isLoadingServiceCatalog = false
    var specialists: [Specialist] = []
    var specialistsUpdatedAt: Date?
    var specialistsShowingSavedCopy = false
    var blogUpdatedAt: Date?
    var blogShowingSavedCopy = false
    var clientTasksUpdatedAt: Date?
    var clientTasksShowingSavedCopy = false
    var professionalLeadsUpdatedAt: Date?
    var professionalLeadsShowingSavedCopy = false
    var isLoadingSpecialists = false
    var specialistsLoadFailed = false
    var isLoadingNotifications = false
    var isLoadingBlog = false
    private var isPreloadingBlog = false
    var isLoadingTasks = false
    var clientTasksLoadFailed = false
    var isLoadingProfessionalProfile = false
    var isLoadingProfessionalLeads = false
    var isLoadingProfessionalProposals = false
    var isLoadingProfessionalConversations = false
    var isLoadingProfessionalStats = false
    var isLoadingCredits = false
    var professionalLoadFailed = false
    /// Why the professional workspace could not load. An empty feed and a
    /// failed request look identical without it.
    var professionalLoadErrorMessage: String?
    var workspaceMode: WorkspaceMode
    private var didRestoreSavedSnapshots = false
    private var isRefreshingSavedContent = false
    var hasRestoredSavedSnapshots: Bool { didRestoreSavedSnapshots }
    let notificationService = NotificationService()
    let appLock = AppLockService()
    let store = StoreService()

    private let api: APIClient
    private let sessionStore: any SessionStoring
    private let visitorID: String

    init(
        api: APIClient = APIClient(),
        sessionStore: any SessionStoring = KeychainSessionStore()
    ) {
        smartSearchAIConsentVersion = UserDefaults.standard.integer(forKey: "smart-search-ai-consent-version")
        let savedPreference = UserDefaults.standard.string(forKey: "app-language-preference")
            .flatMap(AppLanguagePreference.init(rawValue:))
        let legacyLocale = UserDefaults.standard.string(forKey: "app-locale")
            .flatMap(AppLocale.init(rawValue:))
        languagePreference = savedPreference
            ?? legacyLocale.flatMap { AppLanguagePreference(rawValue: $0.rawValue) }
            ?? .system
        let persistedSession = sessionStore.loadSession()
        let cachedCatalog = UserDefaults.standard.data(forKey: "kablay-service-catalog-v1")
            .flatMap { try? JSONDecoder().decode([ServiceCategory].self, from: $0) }
        serviceCatalog = cachedCatalog.flatMap { $0.isEmpty ? nil : $0 } ?? ServiceCategory.catalog
        serviceCatalogVersion = UserDefaults.standard.string(forKey: "kablay-service-catalog-version")
        serviceCatalogUpdatedAt = UserDefaults.standard.object(forKey: "kablay-service-catalog-updated-at") as? Date
        // Remove the legacy preview session once, so an old beta cannot reopen
        // a real device inside a fabricated specialist account.
        let storedSession = persistedSession?.token == "preview-token" ? nil : persistedSession
        if persistedSession?.token == "preview-token" { sessionStore.clearSession() }
        session = storedSession
        workspaceMode = storedSession?.user.role == .specialist ? .professional : .client
        self.api = api
        self.sessionStore = sessionStore
        if let storedVisitorID = UserDefaults.standard.string(forKey: "kablay-visitor-id") {
            visitorID = storedVisitorID
        } else {
            let generated = UUID().uuidString.lowercased()
            UserDefaults.standard.set(generated, forKey: "kablay-visitor-id")
            visitorID = generated
        }
        if storedSession != nil { appLock.onSessionRestored() }
        // Apple can hand the app a transaction at any time, so redeeming is
        // wired up for the whole session rather than only while a store screen
        // happens to be open.
        store.redeem = { [weak self] transactionID in
            await self?.redeemApplePurchase(transactionID: transactionID) ?? false
        }
        store.start()
    }

    /// Restore the last good copy after the first frame. The disk and JSON
    /// work runs on OfflineDataStore's queue, so a large cache cannot freeze
    /// the launch animation or the first Pro tab.
    func restoreSavedSnapshots() async {
        guard !didRestoreSavedSnapshots else { return }
        if let userID = session?.user.id { await restorePrivateSnapshots(for: userID) }
        if let saved = await OfflineDataStore.loadAsync([Specialist].self, key: "specialists"),
           specialistsUpdatedAt == nil {
            specialists = saved.value
            specialistsUpdatedAt = saved.savedAt
            specialistsShowingSavedCopy = true
        }
        if let saved = await OfflineDataStore.loadAsync([BlogArticle].self, key: "articles"),
           blogUpdatedAt == nil {
            blogArticles = saved.value
            blogUpdatedAt = saved.savedAt
            blogShowingSavedCopy = true
        }
        didRestoreSavedSnapshots = true
    }

    private func restorePrivateSnapshots(for userID: String) async {
        guard session?.user.id == userID else { return }
        if isProfessional {
            if let saved = await OfflineDataStore.loadAsync([ProfessionalLead].self, key: "professional-leads", accountID: userID),
               session?.user.id == userID, professionalLeadsUpdatedAt == nil {
                professionalLeads = saved.value
                professionalLeadsUpdatedAt = saved.savedAt
                professionalLeadsShowingSavedCopy = true
            }
            if let saved = await OfflineDataStore.loadAsync(ProfessionalProfile.self, key: "professional-profile", accountID: userID),
               session?.user.id == userID, professionalProfileUpdatedAt == nil {
                professionalProfile = saved.value
                professionalProfileUpdatedAt = saved.savedAt
                professionalProfileShowingSavedCopy = true
            }
            if let saved = await OfflineDataStore.loadAsync([ProfessionalProposal].self, key: "professional-proposals", accountID: userID),
               session?.user.id == userID, professionalProposalsUpdatedAt == nil {
                professionalProposals = saved.value
                professionalProposalsUpdatedAt = saved.savedAt
                professionalProposalsShowingSavedCopy = true
            }
            if let saved = await OfflineDataStore.loadAsync([ProfessionalConversation].self, key: "professional-conversations", accountID: userID),
               session?.user.id == userID, professionalConversationsUpdatedAt == nil {
                professionalConversations = saved.value
                professionalConversationsUpdatedAt = saved.savedAt
                professionalConversationsShowingSavedCopy = true
            }
            if let saved = await OfflineDataStore.loadAsync(ProfessionalStats.self, key: "professional-stats", accountID: userID),
               session?.user.id == userID, professionalStatsUpdatedAt == nil {
                professionalStats = saved.value
                professionalStatsUpdatedAt = saved.savedAt
                professionalStatsShowingSavedCopy = true
            }
        }
        if let saved = await OfflineDataStore.loadAsync([RepairTask].self, key: "client-tasks", accountID: userID),
           session?.user.id == userID, clientTasksUpdatedAt == nil {
            clientTasks = saved.value
            clientTasksUpdatedAt = saved.savedAt
            clientTasksShowingSavedCopy = true
        }
        if notifications.isEmpty,
           let saved = await OfflineDataStore.loadAsync([AppNotification].self, key: "notifications", accountID: userID),
           session?.user.id == userID {
            notifications = saved.value
        }
    }

    private func persistClientTasks(for userID: String) {
        clientTasksUpdatedAt = OfflineDataStore.saveDeferred(clientTasks, key: "client-tasks", accountID: userID)
        clientTasksShowingSavedCopy = false
        prefetchTaskImages()
    }

    private func persistProfessionalProfile(for userID: String) {
        guard let professionalProfile else { return }
        professionalProfileUpdatedAt = OfflineDataStore.saveDeferred(
            professionalProfile, key: "professional-profile", accountID: userID
        )
        professionalProfileShowingSavedCopy = false
    }

    private func prefetchPublicImages() {
        let directory = specialists
        let blog = blogArticles
        let leads = professionalLeads
        let tasks = clientTasks
        Task.detached(priority: .utility) {
            let specialists = OfflineImageTargets.specialists(directory)
            let articles = OfflineImageTargets.articles(blog)
            let keep = specialists + articles + OfflineImageTargets.tasks(leads, tasks)
            await OfflineImageStore.shared.prune(keeping: keep)
            await OfflineImageStore.shared.prefetch(specialists + articles)
        }
    }

    private func prefetchTaskImages() {
        let directory = specialists
        let blog = blogArticles
        let leads = professionalLeads
        let tasks = clientTasks
        Task.detached(priority: .utility) {
            let urls = OfflineImageTargets.tasks(leads, tasks)
            let keep = OfflineImageTargets.specialists(directory) + OfflineImageTargets.articles(blog) + urls
            await OfflineImageStore.shared.prune(keeping: keep)
            await OfflineImageStore.shared.prefetch(urls)
        }
    }

    private func prefetchArticlePageImages(_ page: [BlogArticle]) {
        Task.detached(priority: .utility) {
            await OfflineImageStore.shared.prefetch(OfflineImageTargets.articles(page))
        }
    }

    var isAuthenticated: Bool { session != nil }
    var isProfessional: Bool {
        session?.user.role == .specialist || session?.user.role == .admin
    }
    var requiresInitialAppLockSetup: Bool {
        Self.requiresInitialAppLockSetup(
            role: session?.user.role,
            isConfigured: appLock.isConfigured
        )
    }
    var unreadCount: Int { notifications.filter { !$0.isRead }.count }

    func refreshSavedContent() async {
        guard !isRefreshingSavedContent else { return }
        isRefreshingSavedContent = true
        defer { isRefreshingSavedContent = false }
        if isProfessional && workspaceMode == .professional {
            async let profile: Void = loadProfessionalProfile()
            async let leads: Void = loadProfessionalLeads()
            async let proposals: Void = loadProfessionalProposals()
            async let conversations: Void = loadProfessionalConversations()
            _ = await (profile, leads, proposals, conversations)
        }
        async let catalog: Void = loadServiceCatalog()
        async let directory: Void = loadSpecialists()
        async let articles: Void = loadBlogArticles()
        async let tasks: Void = loadClientTasks()
        _ = await (catalog, directory, articles, tasks)
    }

    @discardableResult
    func handleUniversalLink(_ url: URL) -> Bool {
        if url.scheme?.lowercased() == "kablay", url.host?.lowercased() == "billing" {
            guard isProfessional else { return false }
            workspaceMode = .professional
            pendingBillingPage = url.pathComponents.contains("premium") ? .premium : .credits
            return true
        }
        guard ["kablay.co.il", "www.kablay.co.il"].contains(url.host?.lowercased() ?? "") else {
            return false
        }
        let components = url.pathComponents.filter { $0 != "/" }
        let route = components.first.map { ["he", "en", "ru"].contains($0) } == true
            ? Array(components.dropFirst())
            : components
        if route.count >= 2, route[0] == "pro", route[1] == "billing" {
            guard isProfessional else { return false }
            workspaceMode = .professional
            pendingBillingPage = route.count >= 3 && route[2] == "premium" ? .premium : .credits
            return true
        }
        guard route.count >= 2 else { return false }
        let identifier = route[1].removingPercentEncoding ?? route[1]
        guard !identifier.isEmpty else { return false }
        switch route[0] {
        case "task", "tasks":
            pendingNotificationDestination = NotificationDestination(
                taskID: identifier,
                conversationID: nil,
                kind: "universal_link"
            )
            return true
        case "specialist", "specialists":
            workspaceMode = .client
            clientTab = .catalog
            pendingSpecialistDestination = SpecialistDestination(id: identifier)
            return true
        default:
            return false
        }
    }

    nonisolated static func requiresInitialAppLockSetup(
        role: UserRole?,
        isConfigured: Bool
    ) -> Bool {
        guard !isConfigured else { return false }
        return role == .specialist || role == .admin
    }

    func sendOTP(phone: String) async -> Bool {
        await perform {
            try await api.sendOTP(phone: phone)
        }
    }

    func verifyOTP(phone: String, code: String, name: String?) async -> Bool {
        isWorking = true
        errorMessage = nil
        otpNameRequired = false
        defer { isWorking = false }
        do {
            let authenticated = try await api.verifyOTP(phone: phone, code: code, name: name)
            if let previousID = session?.user.id, previousID != authenticated.user.id {
                clearLocalSession()
            }
            try sessionStore.saveSession(authenticated)
            session = authenticated
            Task(priority: .utility) { await restorePrivateSnapshots(for: authenticated.user.id) }
            workspaceMode = authenticated.user.role == .specialist ? .professional : .client
            if workspaceMode == .client { clientTab = .account }
            appLock.onAuthenticated()
            return true
        } catch let APIError.server(_, _, code) where code == "NAME_REQUIRED" {
            otpNameRequired = true
            return false
        } catch {
            report(error)
            return false
        }
    }

    func grantSmartSearchAIConsent() {
        smartSearchAIConsentVersion = SmartSearchPrivacy.consentVersion
    }

    func revokeSmartSearchAIConsent() {
        smartSearchAIConsentVersion = 0
    }

    func classifyTask(_ text: String) async -> TriageResult? {
        // Nothing reaches the classifier without consent, and what does reach it
        // is stripped of contact details and street numbers first.
        guard hasSmartSearchAIConsent else { return nil }
        let redacted = SmartSearchPrivacy.redact(text)
        guard SmartSearchPrivacy.isClassifiable(redacted) else { return nil }
        var result: TriageResult?
        let succeeded = await perform {
            result = try await api.triage(text: redacted, locale: locale)
            lastTriage = result
            if let result, serviceCatalog.contains(where: { $0.id == result.category }) {
                taskDraft.categoryID = result.category
                let originalTitle = taskDraft.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let routedTitle = result.serviceTitle ?? result.title
                if taskDraft.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let suggestedDetails = result.details?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    taskDraft.details = !suggestedDetails.isEmpty
                        ? suggestedDetails
                        : (originalTitle.caseInsensitiveCompare(routedTitle) == .orderedSame ? "" : originalTitle)
                }
                if taskDraft.answers["selectedService"]?.caseInsensitiveCompare(routedTitle) != .orderedSame {
                    taskDraft.relatedServices = []
                }
                taskDraft.title = routedTitle
                if let serviceID = result.serviceID { taskDraft.answers["selectedServiceId"] = serviceID }
                taskDraft.answers["selectedService"] = result.serviceTitle ?? result.title
            }
        }
        return succeeded ? result : nil
    }

    func loadSpecialists(force: Bool = false) async {
        guard !isLoadingSpecialists,
              force || OfflineFreshness.needsRefresh(specialistsUpdatedAt, after: OfflineFreshness.specialists) else { return }
        isLoadingSpecialists = true
        specialistsLoadFailed = false
        defer { isLoadingSpecialists = false }
        do {
            specialists = try await api.fetchAppSpecialists()
            specialistsUpdatedAt = OfflineDataStore.saveDeferred(specialists, key: "specialists")
            specialistsShowingSavedCopy = false
            prefetchPublicImages()
        } catch {
            guard !Self.isExpectedCancellation(error) else { return }
            specialistsLoadFailed = true
            specialistsShowingSavedCopy = !specialists.isEmpty
        }
    }

    func loadServiceCatalog(force: Bool = false) async {
        guard !isLoadingServiceCatalog,
              force || !didAttemptServiceCatalogRefresh
                || OfflineFreshness.needsRefresh(serviceCatalogUpdatedAt, after: OfflineFreshness.serviceCatalog) else { return }
        isLoadingServiceCatalog = true
        didAttemptServiceCatalogRefresh = true
        defer { isLoadingServiceCatalog = false }
        do {
            let remote = try await api.fetchServiceCatalog()
            serviceCatalog = remote.categories
            serviceCatalogVersion = remote.version
            serviceCatalogUpdatedAt = .now
            if let data = try? JSONEncoder().encode(remote.categories) {
                UserDefaults.standard.set(data, forKey: "kablay-service-catalog-v1")
                UserDefaults.standard.set(remote.version, forKey: "kablay-service-catalog-version")
                UserDefaults.standard.set(serviceCatalogUpdatedAt, forKey: "kablay-service-catalog-updated-at")
            }
        } catch {
            // Keep the bundled or last-known-good catalogue for offline use.
        }
    }

    func downloadWorkReport(month: String, format: String) async -> URL? {
        guard let session, isProfessional else { return nil }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            return try await api.downloadWorkReport(month: month, format: format, token: session.token)
        } catch {
            report(error)
            return nil
        }
    }

    func loadSpecialistDetails(
        id: String,
        reportFailure: Bool = true
    ) async -> SpecialistProfileDetails? {
        do {
            let details = try await api.fetchSpecialistDetails(id: id)
            OfflineDataStore.saveDeferred(details, key: "specialist-details-\(id)")
            return details
        } catch {
            if let saved = await OfflineDataStore.loadAsync(SpecialistProfileDetails.self, key: "specialist-details-\(id)") {
                return saved.value
            }
            if reportFailure { report(error) }
            return nil
        }
    }

    func revealSpecialistContact(id: String, forWhatsApp: Bool) async -> String? {
        do {
            return try await api.revealSpecialistContact(
                id: id,
                eventType: forWhatsApp ? "whatsapp_open" : "phone_reveal",
                visitorID: visitorID,
                token: session?.token
            )
        } catch {
            report(error)
            return nil
        }
    }

    func loadBlogArticles(force: Bool = false) async {
        guard !isLoadingBlog,
              force || blogLoadedPage == 0 || OfflineFreshness.needsRefresh(blogUpdatedAt, after: OfflineFreshness.articles) else { return }
        isLoadingBlog = true
        defer { isLoadingBlog = false }
        do {
            let result = try await api.fetchBlogArticles()
            let freshIDs = Set(result.items.map(\.id))
            blogFreshIDs = freshIDs
            blogArticles = result.items + blogArticles.filter { !freshIDs.contains($0.id) }
            blogLoadedPage = 1
            blogPages = result.pages
            let complete = blogLoadedPage >= blogPages
            if complete { blogArticles.removeAll { !blogFreshIDs.contains($0.id) } }
            let savedAt = complete ? Date.now : (blogUpdatedAt ?? .now)
            blogUpdatedAt = OfflineDataStore.saveDeferred(blogArticles, key: "articles", date: savedAt)
            blogShowingSavedCopy = !complete
            prefetchArticlePageImages(result.items)
            prefetchPublicImages()
            // Let the first screen render immediately, then warm the remaining
            // article pages and their images for offline reading.
            Task(priority: .utility) {
                await Task.yield()
                await preloadRemainingBlogArticles()
            }
        } catch {
            guard !Self.isExpectedCancellation(error) else { return }
            blogShowingSavedCopy = !blogArticles.isEmpty
        }
    }

    func loadMoreBlogArticles() async {
        guard !isLoadingBlog, blogLoadedPage < blogPages else { return }
        isLoadingBlog = true
        defer { isLoadingBlog = false }
        do {
            let result = try await api.fetchBlogArticles(page: blogLoadedPage + 1)
            let freshIDs = Set(result.items.map(\.id))
            let previousFreshIDs = blogFreshIDs
            blogFreshIDs.formUnion(freshIDs)
            blogArticles = blogArticles.filter { previousFreshIDs.contains($0.id) && !freshIDs.contains($0.id) }
                + result.items
                + blogArticles.filter { !previousFreshIDs.contains($0.id) && !freshIDs.contains($0.id) }
            blogLoadedPage += 1
            blogPages = result.pages
            let complete = blogLoadedPage >= blogPages
            if complete { blogArticles.removeAll { !blogFreshIDs.contains($0.id) } }
            let savedAt = complete ? Date.now : (blogUpdatedAt ?? .now)
            if complete || blogLoadedPage.isMultiple(of: 5) {
                blogUpdatedAt = OfflineDataStore.saveDeferred(blogArticles, key: "articles", date: savedAt)
            }
            blogShowingSavedCopy = !complete
            prefetchArticlePageImages(result.items)
            if complete { prefetchPublicImages() }
        } catch {
            blogShowingSavedCopy = !blogArticles.isEmpty
        }
    }

    private func preloadRemainingBlogArticles() async {
        guard !isPreloadingBlog else { return }
        isPreloadingBlog = true
        defer { isPreloadingBlog = false }
        while blogLoadedPage < blogPages, !Task.isCancelled {
            let previousPage = blogLoadedPage
            await loadMoreBlogArticles()
            guard blogLoadedPage > previousPage else { return }
        }
    }

    func loadNotifications() async {
        guard let session, !isLoadingNotifications else {
            if self.session == nil { notifications = [] }
            return
        }
        isLoadingNotifications = true
        defer { isLoadingNotifications = false }
        do {
            notifications = try await api.fetchNotifications(token: session.token, role: session.user.role)
            OfflineDataStore.saveDeferred(notifications, key: "notifications", accountID: session.user.id)
        } catch {
            guard !Self.isExpectedCancellation(error) else { return }
            if Self.isUnauthorized(error) { report(error) }
            // Keep the last known notifications when the connection drops.
        }
    }

    func markNotificationRead(_ notification: AppNotification) async {
        guard let session else { return }
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index].isRead = true
            OfflineDataStore.saveDeferred(notifications, key: "notifications", accountID: session.user.id)
        }
        do {
            try await api.markNotificationRead(id: notification.id, token: session.token)
        } catch {
            report(error)
        }
    }

    func markNotificationsRead() async {
        guard let session else { return }
        for index in notifications.indices { notifications[index].isRead = true }
        OfflineDataStore.saveDeferred(notifications, key: "notifications", accountID: session.user.id)
        do {
            try await api.markAllNotificationsRead(token: session.token)
        } catch {
            report(error)
        }
    }

    func loadNotificationPreferences() async {
        guard let session else { return }
        do {
            notificationPreferences = try await api.fetchNotificationPreferences(token: session.token)
        } catch {
            report(error)
        }
    }

    func saveNotificationPreferences(_ preferences: NotificationPreferences) async {
        guard let session else { return }
        notificationPreferences = preferences
        do {
            notificationPreferences = try await api.updateNotificationPreferences(preferences, token: session.token)
        } catch {
            report(error)
        }
    }

    func loadClientTasks(force: Bool = false) async {
        guard let session,
              !isLoadingTasks,
              force || clientTasksLoadedPage == 0 || OfflineFreshness.needsRefresh(clientTasksUpdatedAt, after: OfflineFreshness.personalTasks) else {
            if self.session == nil { clientTasks = [] }
            return
        }
        isLoadingTasks = true
        clientTasksLoadFailed = false
        defer { isLoadingTasks = false }
        do {
            let result = try await api.fetchTasks(token: session.token)
            let freshIDs = Set(result.items.map(\.id))
            clientTaskFreshIDs = freshIDs
            clientTasks = result.items + clientTasks.filter { !freshIDs.contains($0.id) }
            clientTasksLoadedPage = 1
            clientTasksPages = result.pages
            let complete = clientTasksLoadedPage >= clientTasksPages
            if complete { clientTasks.removeAll { !clientTaskFreshIDs.contains($0.id) } }
            let savedAt = complete ? Date.now : (clientTasksUpdatedAt ?? .now)
            clientTasksUpdatedAt = OfflineDataStore.saveDeferred(clientTasks, key: "client-tasks", accountID: session.user.id, date: savedAt)
            clientTasksShowingSavedCopy = !complete
            prefetchTaskImages()
        } catch {
            guard !Self.isExpectedCancellation(error) else { return }
            if Self.isUnauthorized(error) { report(error); return }
            clientTasksLoadFailed = true
            clientTasksShowingSavedCopy = !clientTasks.isEmpty
        }
    }

    func loadMoreClientTasks() async {
        guard let session, !isLoadingTasks, clientTasksLoadedPage < clientTasksPages else { return }
        isLoadingTasks = true
        defer { isLoadingTasks = false }
        do {
            let result = try await api.fetchTasks(token: session.token, page: clientTasksLoadedPage + 1)
            let freshIDs = Set(result.items.map(\.id))
            let previousFreshIDs = clientTaskFreshIDs
            clientTaskFreshIDs.formUnion(freshIDs)
            clientTasks = clientTasks.filter { previousFreshIDs.contains($0.id) && !freshIDs.contains($0.id) }
                + result.items
                + clientTasks.filter { !previousFreshIDs.contains($0.id) && !freshIDs.contains($0.id) }
            clientTasksLoadedPage += 1
            clientTasksPages = result.pages
            let complete = clientTasksLoadedPage >= clientTasksPages
            if complete { clientTasks.removeAll { !clientTaskFreshIDs.contains($0.id) } }
            let savedAt = complete ? Date.now : (clientTasksUpdatedAt ?? .now)
            clientTasksUpdatedAt = OfflineDataStore.saveDeferred(clientTasks, key: "client-tasks", accountID: session.user.id, date: savedAt)
            clientTasksShowingSavedCopy = !complete
            prefetchTaskImages()
        } catch {
            clientTasksShowingSavedCopy = !clientTasks.isEmpty
        }
    }

    func loadProfessionalProfile(force: Bool = false) async {
        guard let session, isProfessional, !isLoadingProfessionalProfile,
              force || OfflineFreshness.needsRefresh(professionalProfileUpdatedAt, after: OfflineFreshness.personalTasks) else {
            if self.session == nil { professionalProfile = nil }
            return
        }
        isLoadingProfessionalProfile = true
        defer { isLoadingProfessionalProfile = false }
        do {
            professionalProfile = try await api.fetchProfessionalProfile(token: session.token)
            if professionalProfile != nil {
                persistProfessionalProfile(for: session.user.id)
            }
            professionalLoadFailed = false
            professionalLoadErrorMessage = nil
        } catch {
            guard !Self.isExpectedCancellation(error) else { return }
            if Self.isUnauthorized(error) { report(error); return }
            professionalProfileShowingSavedCopy = professionalProfile != nil
            recordProfessionalLoadFailure(error)
        }
    }

    /// A specialist can pause their public presence without deleting anything:
    /// a hidden profile leaves the catalog and stops receiving new work.
    func setProfessionalVisibility(_ visible: Bool) async -> Bool {
        guard let session, isProfessional else { return false }
        let fallbackName = professionalProfile?.specialist.name ?? session.user.name
        return await perform {
            professionalProfile = try await api.updateProfileVisibility(
                visible: visible,
                fallbackName: fallbackName,
                token: session.token
            )
            persistProfessionalProfile(for: session.user.id)
        }
    }

    func loadProfessionalLeads(force: Bool = false) async {
        guard let session, isProfessional, !isLoadingProfessionalLeads,
              force || professionalLeadsLoadedPage == 0 || OfflineFreshness.needsRefresh(professionalLeadsUpdatedAt, after: OfflineFreshness.availableJobs) else { return }
        isLoadingProfessionalLeads = true
        defer { isLoadingProfessionalLeads = false }
        do {
            let actingSpecialistID = await actingSpecialistID(for: session)
            let result = try await api.fetchProfessionalLeads(
                token: session.token,
                actingSpecialistID: actingSpecialistID
            )
            let freshIDs = Set(result.items.map(\.id))
            professionalLeadFreshIDs = freshIDs
            professionalLeads = result.items + professionalLeads.filter { !freshIDs.contains($0.id) }
            professionalLeadsLoadedPage = 1
            professionalLeadsPages = result.pages
            let complete = professionalLeadsLoadedPage >= professionalLeadsPages
            if complete { professionalLeads.removeAll { !professionalLeadFreshIDs.contains($0.id) } }
            let savedAt = complete ? Date.now : (professionalLeadsUpdatedAt ?? .now)
            professionalLeadsUpdatedAt = OfflineDataStore.saveDeferred(
                professionalLeads, key: "professional-leads", accountID: session.user.id, date: savedAt
            )
            professionalLeadsShowingSavedCopy = !complete
            prefetchTaskImages()
            professionalLoadFailed = false
            professionalLoadErrorMessage = nil
        } catch {
            guard !Self.isExpectedCancellation(error) else { return }
            if Self.isUnauthorized(error) { report(error); return }
            professionalLeadsShowingSavedCopy = !professionalLeads.isEmpty
            recordProfessionalLoadFailure(error)
        }
    }

    func loadMoreProfessionalLeads() async {
        guard let session, isProfessional, !isLoadingProfessionalLeads,
              professionalLeadsLoadedPage < professionalLeadsPages else { return }
        isLoadingProfessionalLeads = true
        defer { isLoadingProfessionalLeads = false }
        do {
            let result = try await api.fetchProfessionalLeads(
                token: session.token,
                actingSpecialistID: await actingSpecialistID(for: session),
                page: professionalLeadsLoadedPage + 1
            )
            let freshIDs = Set(result.items.map(\.id))
            let previousFreshIDs = professionalLeadFreshIDs
            professionalLeadFreshIDs.formUnion(freshIDs)
            professionalLeads = professionalLeads.filter { previousFreshIDs.contains($0.id) && !freshIDs.contains($0.id) }
                + result.items
                + professionalLeads.filter { !previousFreshIDs.contains($0.id) && !freshIDs.contains($0.id) }
            professionalLeadsLoadedPage += 1
            professionalLeadsPages = result.pages
            let complete = professionalLeadsLoadedPage >= professionalLeadsPages
            if complete { professionalLeads.removeAll { !professionalLeadFreshIDs.contains($0.id) } }
            let savedAt = complete ? Date.now : (professionalLeadsUpdatedAt ?? .now)
            professionalLeadsUpdatedAt = OfflineDataStore.saveDeferred(
                professionalLeads, key: "professional-leads", accountID: session.user.id, date: savedAt
            )
            professionalLeadsShowingSavedCopy = !complete
            prefetchTaskImages()
        } catch {
            professionalLeadsShowingSavedCopy = !professionalLeads.isEmpty
        }
    }

    private func recordProfessionalLoadFailure(_ error: Error) {
        guard !Self.isExpectedCancellation(error) else { return }
        professionalLoadFailed = true
        professionalLoadErrorMessage = error.localizedDescription
    }

    func loadProfessionalProposals(force: Bool = false) async {
        guard let session, isProfessional, !isLoadingProfessionalProposals,
              force || OfflineFreshness.needsRefresh(professionalProposalsUpdatedAt, after: OfflineFreshness.personalTasks) else { return }
        archivedProfessionalProposalIDs = storedProfessionalProposalArchive(userID: session.user.id)
        isLoadingProfessionalProposals = true
        defer { isLoadingProfessionalProposals = false }
        do {
            professionalProposals = try await api.fetchProfessionalProposals(token: session.token)
            professionalProposalsUpdatedAt = OfflineDataStore.saveDeferred(professionalProposals, key: "professional-proposals", accountID: session.user.id)
            professionalProposalsShowingSavedCopy = false
            professionalLoadFailed = false
        } catch {
            guard !Self.isExpectedCancellation(error) else { return }
            if Self.isUnauthorized(error) { report(error); return }
            professionalProposalsShowingSavedCopy = !professionalProposals.isEmpty
            professionalLoadFailed = true
        }
    }

    func loadProfessionalConversations(force: Bool = false) async {
        guard let session, !isLoadingProfessionalConversations,
              force || OfflineFreshness.needsRefresh(professionalConversationsUpdatedAt, after: OfflineFreshness.personalTasks) else { return }
        isLoadingProfessionalConversations = true
        defer { isLoadingProfessionalConversations = false }
        do {
            let previousIDs = Set(professionalConversations.map(\.id))
            professionalConversations = try await api.fetchProfessionalConversations(token: session.token)
            let currentIDs = Set(professionalConversations.map(\.id))
            for removedID in previousIDs.subtracting(currentIDs) {
                OfflineDataStore.removeDeferred(key: "messages-\(removedID)", accountID: session.user.id)
            }
            professionalConversationsUpdatedAt = OfflineDataStore.saveDeferred(professionalConversations, key: "professional-conversations", accountID: session.user.id)
            professionalConversationsShowingSavedCopy = false
            professionalLoadFailed = false
        } catch {
            guard !Self.isExpectedCancellation(error) else { return }
            if Self.isUnauthorized(error) { report(error); return }
            professionalConversationsShowingSavedCopy = !professionalConversations.isEmpty
            professionalLoadFailed = true
        }
    }

    func loadProfessionalMessages(conversationID: String, before: String? = nil) async -> (items: [ProfessionalMessage], cursor: String?) {
        guard let session else { return ([], nil) }
        do {
            let page = try await api.fetchProfessionalMessages(conversationID: conversationID, token: session.token, before: before)
            let saved = await OfflineDataStore.loadAsync(
                [ProfessionalMessage].self, key: "messages-\(conversationID)", accountID: session.user.id
            )?.value ?? []
            let freshIDs = Set(page.items.map(\.id))
            let merged = (saved.filter { !freshIDs.contains($0.id) } + page.items)
                .sorted { $0.createdAt < $1.createdAt }
            OfflineDataStore.saveDeferred(merged, key: "messages-\(conversationID)", accountID: session.user.id)
            if before == nil { try? await api.markConversationRead(id: conversationID, token: session.token) }
            if let index = professionalConversations.firstIndex(where: { $0.id == conversationID }) {
                let value = professionalConversations[index]
                professionalConversations[index] = ProfessionalConversation(
                    id: value.id,
                    taskID: value.taskID,
                    taskTitle: value.taskTitle,
                    partnerName: value.partnerName,
                    partnerAvatarURL: value.partnerAvatarURL,
                    lastMessage: value.lastMessage,
                    lastMessageAt: value.lastMessageAt,
                    unreadCount: 0
                )
                OfflineDataStore.saveDeferred(professionalConversations, key: "professional-conversations", accountID: session.user.id)
            }
            return page
        } catch {
            if Self.isUnauthorized(error) { report(error); return ([], nil) }
            let cached = await OfflineDataStore.loadAsync([ProfessionalMessage].self, key: "messages-\(conversationID)", accountID: session.user.id)?.value ?? []
            return (Array(cached.suffix(50)), nil)
        }
    }

    func sendMessage(conversationID: String, text: String) async -> ProfessionalMessage? {
        guard let session else { return nil }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        do {
            let message = try await api.sendMessage(conversationID: conversationID, text: value, token: session.token)
            var savedMessages = await OfflineDataStore.loadAsync(
                [ProfessionalMessage].self, key: "messages-\(conversationID)", accountID: session.user.id
            )?.value ?? []
            if !savedMessages.contains(where: { $0.id == message.id }) {
                savedMessages.append(message)
                OfflineDataStore.saveDeferred(savedMessages, key: "messages-\(conversationID)", accountID: session.user.id)
            }
            if let index = professionalConversations.firstIndex(where: { $0.id == conversationID }) {
                let conversation = professionalConversations[index]
                professionalConversations[index] = ProfessionalConversation(
                    id: conversation.id,
                    taskID: conversation.taskID,
                    taskTitle: conversation.taskTitle,
                    partnerName: conversation.partnerName,
                    partnerAvatarURL: conversation.partnerAvatarURL,
                    lastMessage: message.text,
                    lastMessageAt: message.createdAt,
                    unreadCount: 0
                )
                OfflineDataStore.saveDeferred(professionalConversations, key: "professional-conversations", accountID: session.user.id)
            }
            return message
        } catch {
            report(error)
            return nil
        }
    }

    func translateTexts(_ texts: [String], reportError: Bool = true) async -> TranslationBatch? {
        guard !texts.isEmpty else { return nil }
        // Translation hands a job description or a chat message to the same
        // third-party model Smart Search uses. That is the thing the consent
        // screen is about, so a person who has not granted it — or who withdrew
        // it — must not have their text sent here either.
        guard hasSmartSearchAIConsent else { return nil }
        do {
            return try await api.translate(texts: texts, targetLocale: locale)
        } catch {
            if reportError { report(error) }
            return nil
        }
    }

    func loadProfessionalStats(force: Bool = false) async {
        guard let session, isProfessional, !isLoadingProfessionalStats,
              force || OfflineFreshness.needsRefresh(professionalStatsUpdatedAt, after: OfflineFreshness.personalTasks) else { return }
        isLoadingProfessionalStats = true
        defer { isLoadingProfessionalStats = false }
        do {
            professionalStats = try await api.fetchProfessionalStats(token: session.token)
            if let professionalStats {
                professionalStatsUpdatedAt = OfflineDataStore.saveDeferred(professionalStats, key: "professional-stats", accountID: session.user.id)
            }
            professionalStatsShowingSavedCopy = false
            professionalLoadFailed = false
        } catch {
            guard !Self.isExpectedCancellation(error) else { return }
            if Self.isUnauthorized(error) { report(error); return }
            professionalStatsShowingSavedCopy = professionalStats != nil
            professionalLoadFailed = true
        }
    }

    func loadCreditAccount(force: Bool = false) async {
        guard let session, isProfessional, force || (creditAccount == nil && !isLoadingCredits) else { return }
        isLoadingCredits = true
        defer { isLoadingCredits = false }
        do {
            creditAccount = try await api.fetchCreditAccount(token: session.token)
            professionalLoadFailed = false
        } catch {
            professionalLoadFailed = true
        }
    }

    /// Applies a StoreKit transaction through the server. The balance and the
    /// Premium window shown afterwards are the server's, never the app's guess.
    func redeemApplePurchase(transactionID: String) async -> Bool {
        guard let session else { return false }
        do {
            let account = try await api.redeemApplePurchase(transactionID: transactionID, token: session.token)
            creditAccount = CreditAccount(
                balance: account.balance,
                transactions: creditAccount?.transactions ?? [],
                premium: account.premium,
                premiumUntil: account.premiumUntil
            )
            if let refreshed = try? await api.fetchCreditAccount(token: session.token) {
                creditAccount = refreshed
            }
            // Refresh public profile contact visibility after a Premium purchase.
            if let profile = try? await api.fetchProfessionalProfile(token: session.token) {
                professionalProfile = profile
            }
            return true
        } catch {
            report(error)
            return false
        }
    }

    func purchaseStoreProduct(_ product: Product) async -> StoreService.PurchaseOutcome? {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            return try await store.purchase(product)
        } catch {
            report(error)
            return nil
        }
    }

    func restoreStorePurchases() async -> Int {
        errorMessage = nil
        return await store.restorePurchases()
    }

    func loadTask(id: String) async -> RepairTask? {
        guard let session else { return nil }
        do {
            let task = try await api.fetchTask(
                id: id,
                token: session.token,
                actingSpecialistID: await actingSpecialistID(for: session)
            )
            OfflineDataStore.saveDeferred(task, key: "task-detail-\(id)", accountID: session.user.id)
            return task
        } catch {
            if Self.isUnauthorized(error) { report(error); return nil }
            return await OfflineDataStore.loadAsync(RepairTask.self, key: "task-detail-\(id)", accountID: session.user.id)?.value
                ?? clientTasks.first { $0.id == id }
        }
    }

    func unlockClientContact(taskID: String) async -> (succeeded: Bool, contact: TaskClientContact?) {
        guard let session, isProfessional, workspaceMode == .professional else {
            errorMessage = locale.text(
                he: "יש לעבור לחשבון בעל מקצוע כדי לפתוח את מספר הלקוח",
                ru: "Переключитесь в кабинет специалиста, чтобы открыть номер клиента",
                en: "Switch to the professional workspace to unlock the client's number"
            )
            return (false, nil)
        }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let contact = try await api.submitProposal(taskID: taskID, token: session.token)
            professionalLeads.removeAll { $0.id == taskID }
            OfflineDataStore.saveDeferred(professionalLeads, key: "professional-leads", accountID: session.user.id)
            if let proposals = try? await api.fetchProfessionalProposals(token: session.token) {
                professionalProposals = proposals
                OfflineDataStore.saveDeferred(proposals, key: "professional-proposals", accountID: session.user.id)
            }
            if let credits = try? await api.fetchCreditAccount(token: session.token) {
                creditAccount = credits
            }
            if let conversations = try? await api.fetchProfessionalConversations(token: session.token) {
                professionalConversations = conversations
                OfflineDataStore.saveDeferred(conversations, key: "professional-conversations", accountID: session.user.id)
            }
            return (true, contact)
        } catch let APIError.server(_, message, code) {
            errorMessage = proposalErrorMessage(code: code, fallback: message)
            return (false, nil)
        } catch {
            report(error)
            return (false, nil)
        }
    }

    func updateProfessionalProposal(id: String, status: String) async -> Bool {
        guard let session, isProfessional else { return false }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await api.updateProposal(id: id, status: status, token: session.token)
            professionalProposals = try await api.fetchProfessionalProposals(token: session.token)
            OfflineDataStore.saveDeferred(professionalProposals, key: "professional-proposals", accountID: session.user.id)
            if status == "accepted" {
                professionalConversations = (try? await api.fetchProfessionalConversations(token: session.token)) ?? professionalConversations
                OfflineDataStore.saveDeferred(professionalConversations, key: "professional-conversations", accountID: session.user.id)
            }
            return true
        } catch let APIError.server(_, message, code) {
            errorMessage = professionalLifecycleErrorMessage(code: code, fallback: message)
            return false
        } catch {
            report(error)
            return false
        }
    }

    func completeProfessionalTask(
        id: String,
        amount: Int,
        note: String? = nil,
        expenseAmount: Int? = nil,
        photoData: [Data] = [],
        receiptUploads: [CompletionUpload] = [],
        shareReceiptsWithClient: Bool = false
    ) async -> Bool {
        guard let session, isProfessional else { return false }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let api = self.api
            let token = session.token
            let photoKeys = try await withThrowingTaskGroup(of: String.self) { group in
                for (index, data) in photoData.prefix(6).enumerated() {
                    group.addTask {
                        try await api.uploadCompletionPhoto(
                            data: data,
                            filename: "completion-\(id)-\(index + 1).jpg",
                            token: token
                        )
                    }
                }
                var keys: [String] = []
                for try await key in group { keys.append(key) }
                return keys
            }
            let receiptKeys = try await withThrowingTaskGroup(of: String.self) { group in
                for upload in receiptUploads.prefix(6) {
                    group.addTask {
                        try await api.uploadCompletionFile(
                            data: upload.data,
                            filename: upload.filename,
                            mimeType: upload.mimeType,
                            token: token
                        )
                    }
                }
                var keys: [String] = []
                for try await key in group { keys.append(key) }
                return keys
            }
            try await api.completeProfessionalTask(
                id: id,
                amount: amount,
                note: note,
                expenseAmount: expenseAmount,
                photoKeys: photoKeys,
                receiptKeys: receiptKeys,
                receiptVisibility: shareReceiptsWithClient ? "participants" : "specialist_private",
                token: token
            )
            professionalProposals = try await api.fetchProfessionalProposals(token: session.token)
            OfflineDataStore.saveDeferred(professionalProposals, key: "professional-proposals", accountID: session.user.id)
            return true
        } catch let APIError.server(_, message, code) {
            errorMessage = professionalLifecycleErrorMessage(code: code, fallback: message)
            return false
        } catch {
            report(error)
            return false
        }
    }

    func archiveProfessionalProposal(id: String) {
        guard let userID = session?.user.id else { return }
        archivedProfessionalProposalIDs.insert(id)
        saveProfessionalProposalArchive(userID: userID)
    }

    func restoreProfessionalProposal(id: String) {
        guard let userID = session?.user.id else { return }
        archivedProfessionalProposalIDs.remove(id)
        saveProfessionalProposalArchive(userID: userID)
    }

    func cancelTask(id: String) async -> RepairTask? {
        guard let session else { return nil }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await api.cancelTask(id: id, token: session.token)
            let updated = try await api.fetchTask(id: id, token: session.token)
            if let index = clientTasks.firstIndex(where: { $0.id == id }) {
                clientTasks[index] = updated
            }
            OfflineDataStore.saveDeferred(updated, key: "task-detail-\(id)", accountID: session.user.id)
            persistClientTasks(for: session.user.id)
            return updated
        } catch {
            report(error)
            return nil
        }
    }

    func resolveTaskCompletion(
        id: String,
        requestedAt: Date,
        confirm: Bool,
        clientPaidAmount: Int? = nil,
        clientNote: String? = nil,
        photoData: [Data] = []
    ) async -> RepairTask? {
        guard let session else { return nil }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let api = self.api
            let token = session.token
            let photoKeys = try await withThrowingTaskGroup(of: String.self) { group in
                for (index, data) in photoData.prefix(6).enumerated() {
                    group.addTask {
                        try await api.uploadCompletionPhoto(
                            data: data,
                            filename: "client-result-\(id)-\(index + 1).jpg",
                            token: token
                        )
                    }
                }
                var keys: [String] = []
                for try await key in group { keys.append(key) }
                return keys
            }
            let updated = try await api.resolveTaskCompletion(
                id: id,
                requestedAt: requestedAt,
                confirm: confirm,
                clientPaidAmount: clientPaidAmount,
                clientNote: clientNote,
                photoKeys: photoKeys,
                token: token
            )
            if let index = clientTasks.firstIndex(where: { $0.id == id }) {
                clientTasks[index] = updated
            }
            OfflineDataStore.saveDeferred(updated, key: "task-detail-\(id)", accountID: session.user.id)
            persistClientTasks(for: session.user.id)
            let refreshed = try await api.fetchTask(id: id, token: session.token)
            OfflineDataStore.saveDeferred(refreshed, key: "task-detail-\(id)", accountID: session.user.id)
            return refreshed
        } catch {
            report(error)
            return nil
        }
    }

    func submitClientReview(taskID: String, rating: Int, text: String?) async -> Bool {
        guard let session else { return false }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await api.submitClientReview(taskID: taskID, rating: rating, text: text, token: session.token)
            return true
        } catch {
            report(error)
            return false
        }
    }

    func reportSpecialist(id: String, reason: String, details: String?) async -> Bool {
        await reportContent(targetType: "specialist", targetID: id, reason: reason, details: details)
    }

    func reportContent(targetType: String, targetID: String, reason: String, details: String?) async -> Bool {
        guard let session else {
            errorMessage = locale.text(he: "יש להתחבר כדי לדווח", ru: "Войдите, чтобы отправить жалобу", en: "Sign in to submit a report")
            return false
        }
        do {
            try await api.reportContent(
                targetType: targetType,
                targetID: targetID,
                reason: reason,
                details: details,
                token: session.token
            )
            return true
        } catch {
            report(error)
            return false
        }
    }

    func blockSpecialist(id: String) async -> Bool {
        let blocked = await blockContent(targetType: "specialist", targetID: id)
        if blocked { specialists.removeAll { $0.id == id } }
        return blocked
    }

    func blockContent(targetType: String, targetID: String) async -> Bool {
        guard let session else {
            errorMessage = locale.text(he: "יש להתחבר כדי לחסום", ru: "Войдите, чтобы заблокировать", en: "Sign in to block")
            return false
        }
        do {
            try await api.blockContent(targetType: targetType, targetID: targetID, token: session.token)
            return true
        } catch {
            report(error)
            return false
        }
    }

    func reportConversation(id: String, reason: String, details: String?) async -> Bool {
        await reportContent(targetType: "conversation", targetID: id, reason: reason, details: details)
    }

    func blockConversation(id: String) async -> Bool {
        let blocked = await blockContent(targetType: "conversation", targetID: id)
        if blocked { professionalConversations.removeAll { $0.id == id } }
        return blocked
    }

    func prepareSimilarRequest(from task: RepairTask) {
        var draft = TaskDraft()
        draft.categoryID = task.categoryID
        draft.title = task.title
        draft.details = task.description ?? ""
        draft.city = task.city
        draft.address = task.address ?? ""
        draft.timing = task.whenNeeded ?? "flexible"
        draft.budget = task.budget ?? ""
        draft.answers["selectedService"] = task.title
        taskDraft = draft
        requestEntryMode = .routed
        clientTab = .request
    }

    func handleNotificationPayload(_ payload: [AnyHashable: Any]) {
        let taskID = (payload["taskId"] ?? payload["task_id"]) as? String
        guard let taskID, !taskID.isEmpty else { return }
        let conversationID = (payload["conversationId"] ?? payload["conversation_id"]) as? String
        let kind = payload["kind"] as? String ?? "task_update"
        pendingNotificationDestination = NotificationDestination(
            taskID: taskID,
            conversationID: conversationID,
            kind: kind
        )
    }

    func publishTask(photoData: [Data] = []) async -> Bool {
        guard taskDraft.canPublish else {
            errorMessage = locale.text(
                he: "יש למלא קטגוריה, תיאור, עיר וכתובת לפני הפרסום",
                ru: "Перед публикацией заполните категорию, описание, город и адрес",
                en: "Complete the category, description, city, and address before publishing"
            )
            return false
        }
        guard let session else {
            errorMessage = locale.text(he: "יש להתחבר כדי לפרסם בקשה", ru: "Войдите, чтобы опубликовать заявку", en: "Sign in to publish a request")
            return false
        }
        return await perform {
            var publishableDraft = taskDraft
            if !photoData.isEmpty {
                let api = self.api
                let token = session.token
                let uploadedURLs = try await withThrowingTaskGroup(of: String.self) { group in
                    for (index, data) in photoData.prefix(6).enumerated() {
                        group.addTask {
                            try await api.uploadTaskPhoto(
                                data: data,
                                filename: "kablay-task-\(index + 1).jpg",
                                token: token
                            )
                        }
                    }
                    var urls: [String] = []
                    for try await url in group { urls.append(url) }
                    return urls
                }
                publishableDraft.attachmentURLs = uploadedURLs
            }
            publishedTaskID = try await api.createTask(draft: publishableDraft, token: session.token)
            if let refreshedTasks = try? await api.fetchTasks(token: session.token) {
                let freshIDs = Set(refreshedTasks.items.map(\.id))
                clientTasks = refreshedTasks.items + clientTasks.filter { !freshIDs.contains($0.id) }
                clientTasksLoadedPage = 1
                clientTasksPages = refreshedTasks.pages
                persistClientTasks(for: session.user.id)
            }
            taskDraft = TaskDraft()
            requestEntryMode = .direct
            lastTriage = nil
            clientTab = .tasks
        }
    }

    func registerRemoteToken(_ token: String) async {
        guard let session else { return }
        do {
            try await api.registerAPNsToken(token, locale: locale, authToken: session.token)
        } catch {
            report(error)
        }
    }

    func signOut() {
        clearLocalSession()
    }

    func signOutAndRevoke() async {
        let token = session?.token
        clearLocalSession()
        guard let token else { return }
        try? await api.logout(token: token)
    }

    func updateAccount(name: String, preferredCity: String) async -> Bool {
        guard var session else { return false }
        return await perform {
            session.user = try await api.updateAccount(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                preferredCity: preferredCity,
                token: session.token
            )
            try sessionStore.saveSession(session)
            self.session = session
        }
    }

    /// Hands the user their own copy of everything the account holds.
    func exportAccountData() async -> URL? {
        guard let session else { return nil }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            return try await api.downloadAccountDataExport(token: session.token)
        } catch {
            report(error)
            return nil
        }
    }

    func sendAccountDeletionCode() async -> String? {
        guard let session else { return nil }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            return try await api.sendAccountDeletionCode(token: session.token)
        } catch {
            report(error)
            return nil
        }
    }

    func deleteAccount(code: String) async -> Bool {
        guard let session else { return false }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await api.requestAccountDeletion(code: code, token: session.token)
            clearLocalSession()
            return true
        } catch {
            report(error)
            return false
        }
    }

    private func clearLocalSession() {
        if let userID = session?.user.id {
            OfflineDataStore.removeAccountDeferred(userID)
            let leads = professionalLeads
            let tasks = clientTasks
            Task.detached(priority: .utility) {
                await OfflineImageStore.shared.remove(OfflineImageTargets.tasks(leads, tasks))
            }
        }
        session = nil
        workspaceMode = .client
        notifications = []
        notificationPreferences = .enabled
        clientTasks = []
        clientTasksLoadedPage = 0
        clientTasksPages = 1
        clientTaskFreshIDs = []
        clientTasksUpdatedAt = nil
        clientTasksShowingSavedCopy = false
        professionalProfile = nil
        professionalProfileUpdatedAt = nil
        professionalProfileShowingSavedCopy = false
        professionalLeads = []
        professionalLeadsLoadedPage = 0
        professionalLeadsPages = 1
        professionalLeadFreshIDs = []
        professionalLeadsUpdatedAt = nil
        professionalLeadsShowingSavedCopy = false
        professionalLoadFailed = false
        professionalLoadErrorMessage = nil
        professionalProposals = []
        professionalProposalsUpdatedAt = nil
        professionalProposalsShowingSavedCopy = false
        professionalConversations = []
        professionalConversationsUpdatedAt = nil
        professionalConversationsShowingSavedCopy = false
        professionalStats = nil
        professionalStatsUpdatedAt = nil
        professionalStatsShowingSavedCopy = false
        creditAccount = nil
        sessionStore.clearSession()
        appLock.removeProtection()
    }

    /// One entry point for the questionnaire. A client without a profile creates
    /// one; a specialist who already has a profile edits that same record.
    func saveProfessionalQuestionnaire(categories: [String], city: String, bio: String) async -> Bool {
        guard let session else { return false }
        guard isProfessional else {
            return await becomeProfessional(categories: categories, city: city, bio: bio)
        }
        let fallbackName = professionalProfile?.specialist.name ?? session.user.name
        return await perform {
            professionalProfile = try await api.updateProfessionalQuestionnaire(
                categories: categories,
                city: city,
                bio: bio,
                fallbackName: fallbackName,
                token: session.token
            )
            persistProfessionalProfile(for: session.user.id)
        }
    }

    func becomeProfessional(categories: [String], city: String, bio: String) async -> Bool {
        guard var session, session.user.role == .client else { return false }
        return await perform {
            let updatedUser = try await api.onboardProfessional(categories: categories, city: city, bio: bio, token: session.token)
            guard updatedUser.role == .specialist else { throw APIError.invalidResponse }
            session.user = updatedUser
            try sessionStore.saveSession(session)
            self.session = session
            workspaceMode = .professional
        }
    }

    func refreshSessionRole() async {
        guard var current = session else { return }
        do {
            let user = try await api.fetchCurrentUser(token: current.token)
            guard session?.token == current.token else { return }
            current.user = user
            try sessionStore.saveSession(current)
            session = current
            if user.role != .specialist && user.role != .admin {
                workspaceMode = .client
                pendingBillingPage = nil
            }
        } catch {
            if Self.isUnauthorized(error), session?.token == current.token {
                clearLocalSession()
            }
            // Saved access remains usable on connectivity failures. The
            // server checks the role on every protected endpoint.
        }
    }

    private func perform(_ operation: () async throws -> Void) async -> Bool {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await operation()
            return true
        } catch {
            report(error)
            return false
        }
    }

    /// The admin role switch acts through the admin's own specialist profile.
    /// It only refines the view: the server already grants an admin the full
    /// marketplace, so a profile lookup that fails must never take down the job
    /// feed or a task the admin is trying to open.
    private func actingSpecialistID(for session: AuthSession) async -> String? {
        guard session.user.role == .admin, workspaceMode == .professional else { return nil }
        if let specialistID = professionalProfile?.specialist.id { return specialistID }
        guard let profile = try? await api.fetchProfessionalProfile(token: session.token) else { return nil }
        professionalProfile = profile
        return profile.specialist.id
    }

    private func proposalErrorMessage(code: String?, fallback: String) -> String {
        switch code {
        case "INSUFFICIENT_CREDITS":
            locale.text(
                he: "אין מספיק נקודות לפתיחת מספר הלקוח",
                ru: "Недостаточно баллов для открытия номера клиента",
                en: "Not enough credits to unlock the client's number"
            )
        case "DUPLICATE_PROPOSAL":
            locale.text(he: "כבר פתחתם את מספר הלקוח למשימה הזו", ru: "Вы уже открыли номер клиента для этого заказа", en: "You already unlocked this client's number")
        case "PROFILE_NOT_VERIFIED":
            locale.text(
                he: "הפרופיל עדיין לא אומת. לקבלת עבודות פנו למנהל KABLAY לאימות.",
                ru: "Профиль ещё не подтверждён. Чтобы брать заказы, обратитесь к администратору KABLAY для подтверждения.",
                en: "The profile is not verified yet. Contact the KABLAY administrator to get verified before taking jobs."
            )
        case "DIRECT_CONTACT_NOT_ALLOWED":
            locale.text(
                he: "אין לציין טלפון, אימייל או WhatsApp לפני קבלת ההצעה",
                ru: "Нельзя указывать телефон, email или WhatsApp до принятия отклика",
                en: "Phone, email, and WhatsApp details are not allowed before acceptance"
            )
        case "TASK_CLOSED":
            locale.text(he: "הבקשה כבר נסגרה", ru: "Заявка уже закрыта", en: "This request is already closed")
        case "OWN_TASK":
            locale.text(he: "לא ניתן להגיב לבקשה שלכם", ru: "Нельзя откликнуться на собственную заявку", en: "You cannot respond to your own request")
        case "TARGET_SPECIALIST_ONLY":
            locale.text(he: "הבקשה מיועדת לבעל מקצוע אחר", ru: "Заявка адресована другому специалисту", en: "This request is addressed to another professional")
        default: fallback
        }
    }

    private func professionalLifecycleErrorMessage(code: String?, fallback: String) -> String {
        switch code {
        case "TASK_ALREADY_TAKEN":
            locale.text(he: "העבודה כבר נלקחה", ru: "Эту заявку уже взял другой специалист", en: "Another professional already took this job")
        case "ACTIVE_TASK_LIMIT":
            locale.text(he: "הגעתם למגבלת העבודות הפעילות", ru: "Достигнут лимит активных задач", en: "You reached the active job limit")
        case "TASK_NOT_IN_PROGRESS", "NO_ACTIVE_ASSIGNMENT":
            locale.text(he: "לא ניתן להשלים את העבודה במצבה הנוכחי", ru: "Эту задачу сейчас нельзя завершить", en: "This job cannot be completed in its current state")
        case "PROPOSAL_ALREADY_DECIDED":
            locale.text(he: "ההצעה כבר אינה פעילה", ru: "Статус отклика уже изменился", en: "This proposal is no longer active")
        default: fallback
        }
    }

    private func storedProfessionalProposalArchive(userID: String) -> Set<String> {
        let values = UserDefaults.standard.stringArray(forKey: professionalArchiveKey(userID: userID)) ?? []
        return Set(values)
    }

    private func saveProfessionalProposalArchive(userID: String) {
        UserDefaults.standard.set(
            archivedProfessionalProposalIDs.sorted(),
            forKey: professionalArchiveKey(userID: userID)
        )
    }

    private func professionalArchiveKey(userID: String) -> String {
        "professional-proposal-archive-\(userID)"
    }

    /// SwiftUI cancels in-flight view tasks during navigation, app locking, and
    /// biometric presentation. Those cancellations are expected control flow,
    /// not failures the user can act on.
    nonisolated static func isExpectedCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        let value = error as NSError
        return value.domain == NSURLErrorDomain && value.code == NSURLErrorCancelled
    }

    nonisolated static func isUnauthorized(_ error: Error) -> Bool {
        if case let APIError.server(status, _, _) = error { return status == 401 }
        return false
    }

    private func report(_ error: Error) {
        guard !Self.isExpectedCancellation(error) else { return }
        if case let APIError.server(status, _, _) = error, status == 401 {
            clearLocalSession()
            errorMessage = locale.text(
                he: "פג תוקף החיבור. יש להתחבר מחדש.",
                ru: "Сессия истекла. Войдите снова.",
                en: "Your session expired. Please sign in again."
            )
            return
        }
        // A server-side fault is not the reader's problem to decode. Raw
        // "Internal Server Error" text says nothing about what to do next.
        if case let APIError.server(status, _, _) = error, status >= 500 {
            errorMessage = locale.text(
                he: "השירות אינו זמין כרגע. נסו שוב בעוד רגע.",
                ru: "Сервис временно недоступен. Попробуйте ещё раз через минуту.",
                en: "The service is temporarily unavailable. Please try again in a moment."
            )
            return
        }
        errorMessage = error.localizedDescription
    }
}

/// URL extraction is deliberately outside AppState's main actor. A large
/// offline article library can contain thousands of inline image references.
private enum OfflineImageTargets {
    static func specialists(_ items: [Specialist]) -> [URL] {
        items.compactMap(\.displayAvatarURL) + items.flatMap { specialist in
            specialist.portfolioProjects.compactMap(\.displayCoverURL)
                + specialist.portfolioURLs
                + specialist.portfolioProjects.flatMap(\.photoURLs)
        }
    }

    static func articles(_ items: [BlogArticle]) -> [URL] {
        items.compactMap(\.coverURL) + items.flatMap { article in
            [article.content.he, article.content.ru, article.content.en]
                .flatMap { ArticleContent.blocks(from: $0, baseURL: AppConfiguration.webBaseURL) }
                .compactMap { block -> URL? in
                    if case let .image(url) = block { return url }
                    return nil
                }
        }
    }

    static func tasks(_ leads: [ProfessionalLead], _ tasks: [RepairTask]) -> [URL] {
        var urls = leads.flatMap(\.attachmentURLs)
        for task in tasks {
            urls.append(contentsOf: task.attachmentURLs)
            urls.append(contentsOf: task.proposals.compactMap(\.specialistAvatarURL))
            if let avatar = task.acceptedSpecialist?.avatarURL { urls.append(avatar) }
            if let completion = task.completion {
                urls.append(contentsOf: completion.specialistPhotoURLs)
                urls.append(contentsOf: completion.clientPhotoURLs)
                urls.append(contentsOf: completion.expenseReceiptURLs)
            }
        }
        return urls
    }
}
