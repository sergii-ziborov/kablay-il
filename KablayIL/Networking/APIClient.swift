import Foundation

enum APIError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case server(status: Int, message: String, code: String?)
    case decoding

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid service URL"
        case .invalidResponse: "The service returned an invalid response"
        case let .server(_, message, _): message
        case .decoding: "The service response could not be read"
        }
    }
}

actor APIClient {
    private let apiBaseURL: URL
    private let triageBaseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        apiBaseURL: URL = AppConfiguration.apiBaseURL,
        triageBaseURL: URL = AppConfiguration.triageBaseURL,
        session: URLSession = .shared
    ) {
        self.apiBaseURL = apiBaseURL
        self.triageBaseURL = triageBaseURL
        self.session = session
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    func sendOTP(phone: String) async throws {
        struct Body: Encodable { let phone: String }
        struct Response: Decodable { let ok: Bool }
        let response: Response = try await request(path: "auth/send-otp", method: "POST", body: Body(phone: phone))
        guard response.ok else { throw APIError.invalidResponse }
    }

    func verifyOTP(phone: String, code: String, name: String?) async throws -> AuthSession {
        struct Body: Encodable {
            let phone: String
            let code: String
            let name: String?
        }
        struct Response: Decodable {
            let token: String
            let user: SessionUser
        }
        let response: Response = try await request(
            path: "auth/verify-otp",
            method: "POST",
            body: Body(phone: phone, code: code, name: name?.nilIfBlank)
        )
        return AuthSession(token: response.token, user: response.user)
    }

    func updateAccount(name: String, preferredCity: String?, token: String) async throws -> SessionUser {
        struct Body: Encodable {
            let name: String
            let preferredCity: String?
        }
        struct Response: Decodable { let user: SessionUser }
        let response: Response = try await request(
            path: "auth/me",
            method: "PATCH",
            token: token,
            body: Body(name: name, preferredCity: preferredCity?.nilIfBlank)
        )
        return response.user
    }

    func fetchCurrentUser(token: String) async throws -> SessionUser {
        struct Response: Decodable { let user: SessionUser }
        let response: Response = try await request(path: "auth/me", method: "GET", token: token)
        return response.user
    }

    func logout(token: String) async throws {
        struct Response: Decodable { let ok: Bool }
        let response: Response = try await request(
            path: "auth/logout",
            method: "POST",
            token: token,
            body: EmptyBody()
        )
        guard response.ok else { throw APIError.invalidResponse }
    }

    /// Downloads everything the account holds as one JSON file. The response is
    /// written to a temporary file rather than decoded: this is the user's copy
    /// of their data, not something the app needs to read.
    func downloadAccountDataExport(token: String) async throws -> URL {
        guard let url = URL(string: "auth/me/data-export", relativeTo: apiBaseURL)?.absoluteURL else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("KABLAY-IL-iOS/1", forHTTPHeaderField: "X-Kablay-Client")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
            let message = envelope?.error ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw APIError.server(status: http.statusCode, message: message, code: envelope?.code)
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("kablay-my-data.json")
        try data.write(to: destination, options: .atomic)
        return destination
    }

    func sendAccountDeletionCode(token: String) async throws -> String {
        struct Response: Decodable {
            let ok: Bool
            let phoneHint: String
        }
        let response: Response = try await request(
            path: "auth/account/deletion-code",
            method: "POST",
            token: token,
            body: EmptyBody()
        )
        guard response.ok else { throw APIError.invalidResponse }
        return response.phoneHint
    }

    func requestAccountDeletion(code: String, token: String) async throws {
        struct Body: Encodable {
            let confirmation: String
            let code: String
        }
        struct Response: Decodable {
            let ok: Bool
            let scheduledFor: String
        }
        let response: Response = try await request(
            path: "auth/account",
            method: "DELETE",
            token: token,
            body: Body(confirmation: "DELETE", code: code)
        )
        guard response.ok else { throw APIError.invalidResponse }
    }

    func reportSpecialist(id: String, reason: String, details: String?, token: String) async throws {
        try await reportContent(targetType: "specialist", targetID: id, reason: reason, details: details, token: token)
    }

    func reportContent(
        targetType: String,
        targetID: String,
        reason: String,
        details: String?,
        token: String
    ) async throws {
        struct Report: Decodable { let id: String }
        struct Response: Decodable { let report: Report }
        var body = [
            "targetType": targetType,
            "targetId": targetID,
            "reason": reason,
        ]
        if let details = details?.nilIfBlank { body["details"] = details }
        let response: Response = try await request(
            path: "moderation/reports",
            method: "POST",
            token: token,
            body: body
        )
        guard !response.report.id.isEmpty else { throw APIError.invalidResponse }
    }

    func blockSpecialist(id: String, token: String) async throws {
        try await blockContent(targetType: "specialist", targetID: id, token: token)
    }

    func blockContent(targetType: String, targetID: String, token: String) async throws {
        struct Block: Decodable { let blockedUserID: String }
        struct Response: Decodable { let block: Block }
        let response: Response = try await request(
            path: "moderation/blocks",
            method: "POST",
            token: token,
            body: ["targetType": targetType, "targetId": targetID]
        )
        guard !response.block.blockedUserID.isEmpty else { throw APIError.invalidResponse }
    }

    func fetchAppSpecialists() async throws -> [Specialist] {
        var page = 1
        var pages = 1
        var result: [Specialist] = []

        repeat {
            let response: PublicSpecialistsResponse = try await request(
                path: "specialists?audience=ios&page=\(page)",
                method: "GET"
            )
            result.append(contentsOf: response.specialists.map(\.model))
            pages = min(max(response.pages, 1), 50)
            page += 1
        } while page <= pages

        return result.sorted {
            if $0.premium != $1.premium { return $0.premium && !$1.premium }
            if $0.hasProfileMedia != $1.hasProfileMedia { return $0.hasProfileMedia && !$1.hasProfileMedia }
            if $0.reviewCount != $1.reviewCount { return $0.reviewCount > $1.reviewCount }
            if $0.rating != $1.rating { return $0.rating > $1.rating }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func fetchServiceCatalog() async throws -> (version: String, categories: [ServiceCategory]) {
        let response: ServiceCatalogResponseDTO = try await request(
            path: "catalog/v1",
            method: "GET"
        )
        let categories = response.categories.map(\.model).filter { !$0.groups.isEmpty }
        guard !response.version.isEmpty, !categories.isEmpty else { throw APIError.invalidResponse }
        return (response.version, categories)
    }

    func downloadWorkReport(month: String, format: String, token: String) async throws -> URL {
        guard let reportURL = URL(string: "specialists/me/work-report", relativeTo: apiBaseURL)?.absoluteURL else {
            throw APIError.invalidURL
        }
        var components = URLComponents(url: reportURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "month", value: month),
            URLQueryItem(name: "format", value: format),
        ]
        guard let url = components?.url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 60
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("KABLAY-IL-iOS/1", forHTTPHeaderField: "X-Kablay-Client")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? decoder.decode(ErrorEnvelope.self, from: data)
            throw APIError.server(
                status: http.statusCode,
                message: envelope?.error ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode),
                code: envelope?.code
            )
        }
        let fileExtension = format == "receipts_zip" ? "zip" : format
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("kablay-work-report-\(month).\(fileExtension)")
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    func fetchSpecialistDetails(id: String) async throws -> SpecialistProfileDetails {
        let response: PublicSpecialistDetailsDTO = try await request(
            path: "specialists/\(id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id)",
            method: "GET"
        )
        return response.model
    }

    func revealSpecialistContact(
        id: String,
        eventType: String,
        visitorID: String,
        token: String? = nil
    ) async throws -> String {
        struct Response: Decodable { let phone: String }
        let response: Response = try await request(
            path: "analytics/specialist-profile-contact",
            method: "POST",
            token: token,
            // This endpoint intentionally uses camelCase. A dictionary keeps
            // JSONEncoder.convertToSnakeCase from rewriting its contract.
            body: [
                "specialistId": id,
                "eventType": eventType,
                "visitorId": visitorID,
                "path": "/ios/specialist/\(id)",
            ]
        )
        return response.phone
    }

    func fetchBlogArticles(page: Int = 1) async throws -> (items: [BlogArticle], pages: Int) {
        // Rotate the CDN URL at the same cadence as the local snapshot. A
        // hard-coded query version could keep serving yesterday's article set.
        let revision = Int(Date().timeIntervalSince1970 / OfflineFreshness.articles)
        guard let url = URL(string: "static-blog-catalog-pages/\(page).json?v=\(revision)", relativeTo: AppConfiguration.webBaseURL)?.absoluteURL else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.invalidResponse
        }
        do {
            let catalog = try decoder.decode(BlogCatalogDTO.self, from: data)
            return (catalog.items.map(\.model), catalog.pages ?? 1)
        } catch {
            throw APIError.decoding
        }
    }

    func fetchNotifications(token: String, role: UserRole? = nil) async throws -> [AppNotification] {
        let response: NotificationsResponseDTO = try await request(path: "notifications", method: "GET", token: token)
        return response.notifications.map { $0.model(for: role) }
    }

    func markNotificationRead(id: String, token: String) async throws {
        struct Response: Decodable { let ok: Bool }
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let response: Response = try await request(path: "notifications/\(encoded)/read", method: "POST", token: token, body: EmptyBody())
        guard response.ok else { throw APIError.invalidResponse }
    }

    func markAllNotificationsRead(token: String) async throws {
        struct Response: Decodable { let ok: Bool }
        let response: Response = try await request(path: "notifications/read", method: "POST", token: token, body: EmptyBody())
        guard response.ok else { throw APIError.invalidResponse }
    }

    func fetchNotificationPreferences(token: String) async throws -> NotificationPreferences {
        struct Response: Decodable { let preferences: NotificationPreferences }
        let response: Response = try await request(
            path: "notifications/preferences",
            method: "GET",
            token: token
        )
        return response.preferences
    }

    func updateNotificationPreferences(_ preferences: NotificationPreferences, token: String) async throws -> NotificationPreferences {
        struct Response: Decodable { let preferences: NotificationPreferences }
        let response: Response = try await request(
            path: "notifications/preferences",
            method: "PATCH",
            token: token,
            body: preferences
        )
        return response.preferences
    }

    func fetchTasks(token: String, page: Int = 1) async throws -> (items: [RepairTask], pages: Int) {
        let response: TasksResponseDTO = try await request(path: "tasks?page=\(page)&limit=25", method: "GET", token: token)
        return (response.tasks.map { $0.model(baseURL: apiBaseURL) }, response.pages ?? 1)
    }

    func fetchProfessionalProfile(token: String) async throws -> ProfessionalProfile {
        let response: ProfessionalProfileResponseDTO = try await request(
            path: "specialists/me",
            method: "GET",
            token: token
        )
        return response.model(baseURL: apiBaseURL)
    }

    /// Catalog visibility is a single switch for the specialist: an available
    /// profile stays public, a hidden one is put on break so search, new jobs,
    /// and contact requests stop reaching it.
    func updateProfileVisibility(
        visible: Bool,
        fallbackName: String,
        token: String
    ) async throws -> ProfessionalProfile {
        struct Body: Encodable {
            let availableNow: Bool
            let onBreak: Bool
        }
        let response: SpecialistVisibilityResponseDTO = try await request(
            path: "specialists/me",
            method: "PATCH",
            token: token,
            body: Body(availableNow: visible, onBreak: !visible)
        )
        return response.model(fallbackName: fallbackName, baseURL: apiBaseURL)
    }

    /// Saves the questionnaire of a profile that already exists. Onboarding
    /// creates a profile once; everything after that is an edit of the same
    /// record, so the questionnaire must not post a second creation.
    func updateProfessionalQuestionnaire(
        categories: [String],
        city: String,
        bio: String,
        fallbackName: String,
        token: String
    ) async throws -> ProfessionalProfile {
        struct Body: Encodable {
            let categories: [String]
            let city: String?
            let bio: String
        }
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let response: SpecialistVisibilityResponseDTO = try await request(
            path: "specialists/me",
            method: "PATCH",
            token: token,
            body: Body(
                categories: categories,
                city: trimmedCity.isEmpty ? nil : trimmedCity,
                bio: bio.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
        return response.model(fallbackName: fallbackName, baseURL: apiBaseURL)
    }

    func fetchProfessionalLeads(token: String, actingSpecialistID: String? = nil, page: Int = 1) async throws -> (items: [ProfessionalLead], pages: Int) {
        let actingQuery = actingSpecialistID.map {
            "&acting_specialist_id=\($0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0)"
        } ?? ""
        let response: ProfessionalLeadsResponseDTO = try await request(
            path: "specialists/me/available-tasks?page=\(page)\(actingQuery)",
            method: "GET",
            token: token
        )
        return (response.tasks.map { $0.model(baseURL: apiBaseURL) }, response.pages)
    }

    func fetchProfessionalProposals(token: String) async throws -> [ProfessionalProposal] {
        let response: ProfessionalProposalsResponseDTO = try await request(
            path: "specialists/me/proposals",
            method: "GET",
            token: token
        )
        return response.proposals.map(\.model)
    }

    func submitProposal(taskID: String, token: String) async throws -> TaskClientContact? {
        struct Body: Encodable {
            let taskID: String
        }
        struct Proposal: Decodable { let id: String }
        struct Contact: Decodable {
            let name: String?
            let phone: String?
            let email: String?
        }
        struct Response: Decodable {
            let proposal: Proposal
            let clientContact: Contact?
        }

        let response: Response = try await request(
            path: "proposals",
            method: "POST",
            token: token,
            body: Body(taskID: taskID)
        )
        return response.clientContact.map {
            TaskClientContact(
                id: taskID,
                name: $0.name?.nilIfBlank ?? "Client",
                phone: $0.phone?.nilIfBlank,
                email: $0.email?.nilIfBlank,
                rating: nil,
                reviewCount: nil
            )
        }
    }

    func updateProposal(id: String, status: String, token: String) async throws {
        struct Body: Encodable { let status: String }
        struct ProposalIdentity: Decodable { let id: String; let status: String }
        struct Response: Decodable { let proposal: ProposalIdentity }
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let response: Response = try await request(
            path: "proposals/\(encoded)",
            method: "PATCH",
            token: token,
            body: Body(status: status)
        )
        guard response.proposal.id == id, response.proposal.status == status else {
            throw APIError.invalidResponse
        }
    }

    func completeProfessionalTask(
        id: String,
        amount: Int,
        note: String? = nil,
        expenseAmount: Int? = nil,
        photoKeys: [String] = [],
        receiptKeys: [String] = [],
        receiptVisibility: String = "specialist_private",
        token: String
    ) async throws {
        struct Body: Encodable {
            let amount: Int
            let note: String?
            let expenseAmount: Int?
            let photoKeys: [String]
            let receiptKeys: [String]
            let receiptVisibility: String
        }
        struct TaskIdentity: Decodable { let id: String; let status: String }
        struct Response: Decodable { let task: TaskIdentity }
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let response: Response = try await request(
            path: "tasks/\(encoded)/complete",
            method: "PATCH",
            token: token,
            body: Body(
                amount: amount,
                note: note?.nilIfBlank,
                expenseAmount: expenseAmount,
                photoKeys: photoKeys,
                receiptKeys: receiptKeys,
                receiptVisibility: receiptVisibility
            )
        )
        guard response.task.id == id, ["done", "completed"].contains(response.task.status) else {
            throw APIError.invalidResponse
        }
    }

    func fetchProfessionalConversations(token: String) async throws -> [ProfessionalConversation] {
        let response: ProfessionalConversationsResponseDTO = try await request(
            path: "conversations",
            method: "GET",
            token: token
        )
        return response.conversations.map { $0.model(baseURL: apiBaseURL) }
    }

    func fetchProfessionalMessages(conversationID: String, token: String, before: String? = nil) async throws -> (items: [ProfessionalMessage], cursor: String?) {
        let encoded = conversationID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? conversationID
        let beforeQuery = before.map { "?before=\($0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0)" } ?? ""
        let response: ProfessionalMessagesResponseDTO = try await request(
            path: "conversations/\(encoded)/messages\(beforeQuery)",
            method: "GET",
            token: token
        )
        return (response.messages.map(\.model), response.cursor)
    }

    func sendMessage(conversationID: String, text: String, token: String) async throws -> ProfessionalMessage {
        struct Body: Encodable { let text: String }
        struct Response: Decodable { let message: ProfessionalMessageDTO }
        let encoded = conversationID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? conversationID
        let response: Response = try await request(
            path: "conversations/\(encoded)/messages",
            method: "POST",
            token: token,
            body: Body(text: String(text.prefix(2_000)))
        )
        return response.message.model
    }

    func markConversationRead(id: String, token: String) async throws {
        struct Response: Decodable { let ok: Bool }
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let response: Response = try await request(
            path: "conversations/\(encoded)/read",
            method: "POST",
            token: token,
            body: EmptyBody()
        )
        guard response.ok else { throw APIError.invalidResponse }
    }

    func fetchProfessionalStats(token: String) async throws -> ProfessionalStats {
        let response: ProfessionalStatsResponseDTO = try await request(
            path: "specialists/me/stats",
            method: "GET",
            token: token
        )
        return response.stats.model
    }

    func fetchCreditAccount(token: String) async throws -> CreditAccount {
        let response: CreditAccountDTO = try await request(
            path: "billing/balance",
            method: "GET",
            token: token
        )
        return response.model
    }

    /// Hands a StoreKit transaction to the server, which checks it with Apple
    /// and applies the entitlement. The response carries the account state the
    /// server ended up with, so the app never grants anything on its own.
    func redeemApplePurchase(transactionID: String, token: String) async throws -> CreditAccount {
        struct Body: Encodable { let transactionId: String }
        struct Response: Decodable {
            let balance: Int
            let premium: Bool?
            let premiumUntil: String?
        }
        let response: Response = try await request(
            path: "billing/apple/redeem",
            method: "POST",
            token: token,
            body: Body(transactionId: transactionID)
        )
        return CreditAccount(
            balance: response.balance,
            transactions: [],
            premium: response.premium ?? false,
            premiumUntil: response.premiumUntil.flatMap(parseAPIDate)
        )
    }

    func fetchTask(id: String, token: String, actingSpecialistID: String? = nil) async throws -> RepairTask {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let actingQuery = actingSpecialistID.map {
            "?acting_specialist_id=\($0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0)"
        } ?? ""
        let response: TaskDetailsResponseDTO = try await request(
            path: "tasks/\(encoded)\(actingQuery)",
            method: "GET",
            token: token
        )
        return response.task.model(
            proposals: response.proposals.map { $0.model(baseURL: apiBaseURL) },
            detail: response.detail,
            baseURL: apiBaseURL
        )
    }

    func cancelTask(id: String, token: String) async throws {
        struct TaskIdentity: Decodable { let id: String }
        struct Response: Decodable { let task: TaskIdentity }
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let response: Response = try await request(path: "tasks/\(encoded)/cancel", method: "PATCH", token: token)
        guard response.task.id == id else { throw APIError.invalidResponse }
    }

    func resolveTaskCompletion(
        id: String,
        requestedAt: Date,
        confirm: Bool,
        clientPaidAmount: Int? = nil,
        clientNote: String? = nil,
        photoKeys: [String] = [],
        token: String
    ) async throws -> RepairTask {
        struct Body: Encodable {
            let requestedAt: String
            let clientPaidAmount: Int?
            let clientNote: String?
            let photoKeys: [String]
        }
        struct Response: Decodable { let task: RepairTaskDTO }
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let action = confirm ? "confirm" : "reject"
        let response: Response = try await request(
            path: "tasks/\(encoded)/completion/\(action)",
            method: "PATCH",
            token: token,
            body: Body(
                requestedAt: ISO8601DateFormatter().string(from: requestedAt),
                clientPaidAmount: clientPaidAmount,
                clientNote: clientNote?.nilIfBlank,
                photoKeys: photoKeys
            )
        )
        return response.task.model(baseURL: apiBaseURL)
    }

    func submitClientReview(taskID: String, rating: Int, text: String?, token: String) async throws {
        struct Body: Encodable {
            let taskID: String
            let rating: Int
            let text: String?
            let authorRole: String
        }
        struct ReviewIdentity: Decodable { let id: String }
        struct Response: Decodable { let review: ReviewIdentity }
        let response: Response = try await request(
            path: "reviews",
            method: "POST",
            token: token,
            body: Body(
                taskID: taskID,
                rating: min(max(rating, 1), 5),
                text: text?.nilIfBlank.map { String($0.prefix(2_000)) },
                authorRole: "client"
            )
        )
        guard !response.review.id.isEmpty else { throw APIError.invalidResponse }
    }

    func triage(text: String, locale: AppLocale) async throws -> TriageResult {
        struct Body: Encodable { let text: String; let locale: String }
        let boundedText = String(text.prefix(600))
        return try await request(
            baseURL: triageBaseURL,
            path: "v1/triage",
            method: "POST",
            body: Body(text: boundedText, locale: locale.rawValue)
        )
    }

    func translate(texts: [String], targetLocale: AppLocale) async throws -> TranslationBatch {
        struct Body: Encodable {
            let texts: [String]
            let targetLocale: String
        }
        let bounded = Array(texts.prefix(12)).map { String($0.prefix(800)) }
        return try await request(
            baseURL: triageBaseURL,
            path: "v1/translate",
            method: "POST",
            body: Body(texts: bounded, targetLocale: targetLocale.rawValue)
        )
    }

    func createTask(draft: TaskDraft, token: String) async throws -> String {
        struct Body: Encodable {
            let categoryID: String
            let title: String
            let description: String
            let city: String
            let address: String?
            let when: String
            let budgetMin: Double?
            let budgetMax: Double?
            let proposalMode: String
            let answersJSON: [String: TaskAnswerValue]
        }
        struct Task: Decodable { let id: String }
        struct Response: Decodable { let task: Task }

        let budget = budgetBounds(draft.budget)
        var encodedAnswers = draft.answers.mapValues(TaskAnswerValue.string)
        if let latitude = draft.latitude {
            encodedAnswers["latitude"] = .number(latitude)
        }
        if let longitude = draft.longitude {
            encodedAnswers["longitude"] = .number(longitude)
        }
        if !draft.relatedServices.isEmpty {
            encodedAnswers["relatedServices"] = .strings(draft.relatedServices.map(\.en))
        }
        if !draft.attachmentURLs.isEmpty {
            encodedAnswers["attachments"] = .strings(draft.attachmentURLs)
        }

        let response: Response = try await request(
            path: "tasks",
            method: "POST",
            token: token,
            body: Body(
                categoryID: draft.categoryID,
                title: draft.title,
                description: draft.details,
                city: draft.city,
                address: draft.address.nilIfBlank,
                when: draft.timing,
                budgetMin: budget.minimum,
                budgetMax: budget.maximum,
                proposalMode: draft.answers["targetSpecialistId"] == nil ? "passive" : "choose",
                answersJSON: encodedAnswers
            )
        )
        return response.task.id
    }

    func uploadTaskPhoto(data: Data, filename: String, token: String) async throws -> String {
        struct Response: Decodable { let url: String }

        guard let url = URL(string: "media/upload", relativeTo: apiBaseURL)?.absoluteURL else {
            throw APIError.invalidURL
        }
        let boundary = "KablayBoundary-\(UUID().uuidString)"
        var body = Data()
        body.appendUTF8("--\(boundary)\r\n")
        body.appendUTF8("Content-Disposition: form-data; name=\"type\"\r\n\r\n")
        body.appendUTF8("task\r\n")
        body.appendUTF8("--\(boundary)\r\n")
        body.appendUTF8("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.appendUTF8("Content-Type: image/jpeg\r\n\r\n")
        body.append(data)
        body.appendUTF8("\r\n--\(boundary)--\r\n")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("KABLAY-IL-iOS/1", forHTTPHeaderField: "X-Kablay-Client")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        let (responseData, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: responseData)
            let message = envelope?.error ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw APIError.server(status: http.statusCode, message: envelope?.error ?? message, code: envelope?.code)
        }
        guard let uploaded = try? decoder.decode(Response.self, from: responseData) else {
            throw APIError.decoding
        }
        return uploaded.url
    }

    func uploadCompletionPhoto(data: Data, filename: String, token: String) async throws -> String {
        try await uploadCompletionFile(
            data: data,
            filename: filename,
            mimeType: "image/jpeg",
            token: token
        )
    }

    func uploadCompletionFile(
        data: Data,
        filename: String,
        mimeType: String,
        token: String
    ) async throws -> String {
        struct Response: Decodable { let key: String }

        guard let url = URL(string: "media/upload", relativeTo: apiBaseURL)?.absoluteURL else {
            throw APIError.invalidURL
        }
        let boundary = "KablayBoundary-\(UUID().uuidString)"
        var body = Data()
        body.appendUTF8("--\(boundary)\r\n")
        body.appendUTF8("Content-Disposition: form-data; name=\"type\"\r\n\r\n")
        body.appendUTF8("completion\r\n")
        body.appendUTF8("--\(boundary)\r\n")
        body.appendUTF8("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.appendUTF8("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.appendUTF8("\r\n--\(boundary)--\r\n")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("KABLAY-IL-iOS/1", forHTTPHeaderField: "X-Kablay-Client")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        let (responseData, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: responseData)
            throw APIError.server(
                status: http.statusCode,
                message: envelope?.error ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode),
                code: envelope?.code
            )
        }
        guard let uploaded = try? decoder.decode(Response.self, from: responseData) else { throw APIError.decoding }
        return uploaded.key
    }

    func registerAPNsToken(_ deviceToken: String, locale: AppLocale, authToken: String) async throws {
        struct Body: Encodable {
            let deviceToken: String
            let platform: String
            let locale: String
            let environment: String
        }
        struct Response: Decodable { let ok: Bool }
        let response: Response = try await request(
            path: "push/apns",
            method: "POST",
            token: authToken,
            body: Body(deviceToken: deviceToken, platform: "ios", locale: locale.rawValue, environment: AppConfiguration.pushEnvironment)
        )
        guard response.ok else { throw APIError.invalidResponse }
    }

    func onboardProfessional(categories: [String], city: String, bio: String, token: String) async throws -> SessionUser {
        struct Body: Encodable {
            let categories: [String]
            let city: String
            let radiusKM: Int
            let bio: String
            let languages: [String]
        }
        struct Response: Decodable { let specialist: SpecialistEnvelope; let user: SessionUser }
        struct SpecialistEnvelope: Decodable { let id: String }
        let response: Response = try await request(
            path: "specialists/me",
            method: "POST",
            token: token,
            body: Body(categories: categories, city: city, radiusKM: 25, bio: bio, languages: ["he", "ru", "en"])
        )
        return response.user
    }

    private func request<Response: Decodable, Body: Encodable>(
        baseURL: URL? = nil,
        path: String,
        method: String,
        token: String? = nil,
        body: Body
    ) async throws -> Response {
        let root = baseURL ?? apiBaseURL
        guard let url = URL(string: path, relativeTo: root)?.absoluteURL else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("KABLAY-IL-iOS/1", forHTTPHeaderField: "X-Kablay-Client")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
            let message = envelope?.error ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw APIError.server(status: http.statusCode, message: message, code: envelope?.code)
        }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    private func request<Response: Decodable>(
        path: String,
        method: String,
        token: String? = nil
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: apiBaseURL)?.absoluteURL else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if method == "GET" { request.cachePolicy = .reloadIgnoringLocalCacheData }
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("KABLAY-IL-iOS/1", forHTTPHeaderField: "X-Kablay-Client")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
            let message = envelope?.error ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw APIError.server(status: http.statusCode, message: message, code: envelope?.code)
        }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }
}

private struct EmptyBody: Encodable {}

private enum TaskAnswerValue: Encodable {
    case string(String)
    case strings([String])
    case number(Double)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value): try container.encode(value)
        case let .strings(values): try container.encode(values)
        case let .number(value): try container.encode(value)
        }
    }
}

private struct BudgetBounds {
    let minimum: Double?
    let maximum: Double?
}

private func budgetBounds(_ value: String) -> BudgetBounds {
    let normalized = value.lowercased()
    let numericSource = normalized
        .replacingOccurrences(of: ",", with: "")
        .replacingOccurrences(of: " ", with: "")
    let numbers = numericSource
        .components(separatedBy: CharacterSet.decimalDigits.inverted)
        .filter { !$0.isEmpty }
        .compactMap(Double.init)
    guard let first = numbers.first else { return BudgetBounds(minimum: nil, maximum: nil) }
    if normalized.contains("up to") || normalized.contains("до") || normalized.contains("עד") {
        return BudgetBounds(minimum: nil, maximum: first)
    }
    if normalized.contains("+") || normalized.contains("from") || normalized.contains("от ") || normalized.contains("מ-") {
        return BudgetBounds(minimum: first, maximum: nil)
    }
    if numbers.count > 1 {
        return BudgetBounds(minimum: first, maximum: numbers[1])
    }
    return BudgetBounds(minimum: nil, maximum: first)
}

private extension Data {
    mutating func appendUTF8(_ value: String) {
        append(value.data(using: .utf8) ?? Data())
    }
}

private struct PublicSpecialistsResponse: Decodable {
    let specialists: [PublicSpecialistDTO]
    let pages: Int
}

private struct ProfessionalProfileResponseDTO: Decodable {
    let specialist: OwnSpecialistDTO
    let user: OwnSpecialistUserDTO

    func model(baseURL: URL) -> ProfessionalProfile {
        ProfessionalProfile(
            specialist: specialist.model(name: user.name, baseURL: baseURL),
            creditsBalance: specialist.creditsBalance
        )
    }
}

private struct OwnSpecialistUserDTO: Decodable {
    let name: String
}

/// The profile PATCH answers with the stored row and may omit the user block,
/// so the caller keeps the already known display name.
private struct SpecialistVisibilityResponseDTO: Decodable {
    let specialist: OwnSpecialistDTO
    let user: OwnSpecialistUserDTO?

    func model(fallbackName: String, baseURL: URL) -> ProfessionalProfile {
        ProfessionalProfile(
            specialist: specialist.model(name: user?.name ?? fallbackName, baseURL: baseURL),
            creditsBalance: specialist.creditsBalance
        )
    }
}

private struct OwnSpecialistDTO: Decodable {
    let id: String
    let categories: [String]
    let bio: String?
    let rating: Double
    let reviewCount: Int
    let verified: Bool
    let phoneVerified: Bool
    let licenseVerified: Bool
    let insuranceVerified: Bool
    let portfolioVerified: Bool
    let reviewsVerified: Bool
    let city: String
    let availableNow: Bool
    let premium: Bool
    let avatarUrl: String?
    let portfolioPhotos: [String]
    let portfolioAlbums: [PortfolioAlbumDTO]
    let completedJobsCount: Int
    let creditsBalance: Int

    enum CodingKeys: String, CodingKey {
        case id, categories, bio, rating, city, verified, phoneVerified, licenseVerified, insuranceVerified, portfolioVerified, reviewsVerified, premium
        case reviewCount, availableNow, avatarUrl, portfolioPhotos, portfolioAlbums, completedJobsCount, creditsBalance
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        categories = values.decodeStringArray(forKey: .categories)
        bio = try values.decodeIfPresent(String.self, forKey: .bio)
        rating = try values.decodeIfPresent(Double.self, forKey: .rating) ?? 0
        reviewCount = try values.decodeIfPresent(Int.self, forKey: .reviewCount) ?? 0
        verified = try values.decodeFlexibleBool(forKey: .verified)
        phoneVerified = try values.decodeFlexibleBool(forKey: .phoneVerified)
        licenseVerified = try values.decodeFlexibleBool(forKey: .licenseVerified)
        insuranceVerified = try values.decodeFlexibleBool(forKey: .insuranceVerified)
        portfolioVerified = try values.decodeFlexibleBool(forKey: .portfolioVerified)
        reviewsVerified = try values.decodeFlexibleBool(forKey: .reviewsVerified)
        city = try values.decodeIfPresent(String.self, forKey: .city) ?? ""
        availableNow = try values.decodeFlexibleBool(forKey: .availableNow)
        premium = try values.decodeFlexibleBool(forKey: .premium)
        avatarUrl = try values.decodeIfPresent(String.self, forKey: .avatarUrl)
        portfolioPhotos = values.decodeStringArray(forKey: .portfolioPhotos)
        portfolioAlbums = values.decodeJSONArray(PortfolioAlbumDTO.self, forKey: .portfolioAlbums)
        completedJobsCount = try values.decodeIfPresent(Int.self, forKey: .completedJobsCount) ?? 0
        creditsBalance = try values.decodeIfPresent(Int.self, forKey: .creditsBalance) ?? 0
    }

    func model(name: String, baseURL: URL) -> Specialist {
        let categoryTitle = categories
            .compactMap { id in ServiceCategory.catalog.first(where: { $0.id == id })?.title }
            .first ?? .init(he: "בעל מקצוע לבית", ru: "Мастер по ремонту", en: "Home repair specialist")
        let profileBio = bio ?? ""
        let localizedCity = LocalizedValue(he: city, ru: city, en: city)
        let projects = portfolioAlbums.compactMap { $0.model(baseURL: baseURL) }
        let photos = uniqueURLs(
            portfolioPhotos.compactMap { resolveAPIURL($0, baseURL: baseURL) }
                + projects.flatMap(\.photoURLs)
        )
        return Specialist(
            id: id,
            name: name,
            avatarURL: resolveAPIURL(avatarUrl, baseURL: baseURL),
            profession: categoryTitle,
            city: localizedCity,
            rating: rating,
            reviewCount: reviewCount,
            completedJobs: completedJobsCount,
            premium: premium,
            verified: verified,
            trust: SpecialistTrust(
                verified: verified,
                phoneVerified: phoneVerified,
                licenseVerified: licenseVerified,
                insuranceVerified: insuranceVerified,
                portfolioVerified: portfolioVerified,
                reviewsVerified: reviewsVerified
            ),
            availableNow: availableNow,
            bio: .init(he: profileBio, ru: profileBio, en: profileBio),
            categories: categories,
            yearsExperience: 0,
            portfolioURLs: photos,
            portfolioProjects: projects
        )
    }
}

private struct ProfessionalLeadsResponseDTO: Decodable {
    let tasks: [ProfessionalLeadDTO]
    let pages: Int
}

private struct ProfessionalLeadDTO: Decodable {
    let id: String
    let title: String
    let categoryId: String?
    let categorySlug: String?
    let description: String?
    let city: String?
    let clientName: String?
    let createdAt: String
    let budgetMin: Double?
    let budgetMax: Double?
    let whenNeeded: String?
    let attachments: [String]?
    let answersJson: TaskAttachmentAnswers?
    let location: TaskLocationDTO?

    func model(baseURL: URL) -> ProfessionalLead {
        var seen = Set<String>()
        let media = ((attachments ?? []) + (answersJson?.urls ?? [])).filter {
            seen.insert($0).inserted
        }
        return ProfessionalLead(
            id: id,
            title: title,
            categoryID: categorySlug ?? categoryId ?? "handyman",
            city: city ?? "",
            clientName: clientName?.nilIfBlank,
            createdAt: parseAPIDate(createdAt) ?? .now,
            description: description?.nilIfBlank ?? "",
            budget: formattedBudget(minimum: budgetMin, maximum: budgetMax),
            urgent: whenNeeded == "urgent",
            attachmentURLs: media.compactMap { resolveAPIURL($0, baseURL: baseURL) },
            location: location?.model
        )
    }
}

private struct TaskAttachmentAnswers: Decodable {
    let urls: [String]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let encoded = try? container.decode(String.self) {
            let data = encoded.data(using: .utf8)
            urls = data.flatMap { try? JSONDecoder().decode(TaskAttachmentFields.self, from: $0) }?.urls ?? []
            return
        }
        urls = (try? container.decode(TaskAttachmentFields.self))?.urls ?? []
    }
}

private struct TaskAttachmentFields: Decodable {
    let attachments: [String]?
    let images: [String]?
    let photos: [String]?
    let files: [String]?
    let media: [String]?

    var urls: [String] {
        // Keep the wire-field order without a long overloaded + expression.
        var result: [String] = attachments ?? []
        result.append(contentsOf: images ?? [])
        result.append(contentsOf: photos ?? [])
        result.append(contentsOf: files ?? [])
        result.append(contentsOf: media ?? [])
        return result
    }
}

private struct ProfessionalProposalsResponseDTO: Decodable {
    let proposals: [ProfessionalProposalDTO]
}

private struct ProfessionalProposalDTO: Decodable {
    let id: String
    let taskId: String
    let taskTitle: String
    let taskStatus: String
    let status: String
    let message: String?
    let price: Int?
    let createdAt: String
    let conversationId: String?

    var model: ProfessionalProposal {
        ProfessionalProposal(
            id: id,
            taskID: taskId,
            taskTitle: taskTitle,
            taskStatus: taskStatus,
            status: status,
            message: message?.nilIfBlank,
            price: price,
            createdAt: parseAPIDate(createdAt) ?? .now,
            conversationID: conversationId
        )
    }
}

private struct ProfessionalConversationsResponseDTO: Decodable {
    let conversations: [ProfessionalConversationDTO]
}

private struct ProfessionalConversationDTO: Decodable {
    let id: String
    let taskId: String?
    let taskTitle: String?
    let partnerName: String?
    let partnerAvatarUrl: String?
    let lastMessageText: String?
    let lastMessageAt: String?
    let unreadCount: Int

    func model(baseURL: URL) -> ProfessionalConversation {
        ProfessionalConversation(
            id: id,
            taskID: taskId,
            taskTitle: taskTitle?.nilIfBlank,
            partnerName: partnerName?.nilIfBlank ?? "KABLAY",
            partnerAvatarURL: resolveAPIURL(partnerAvatarUrl, baseURL: baseURL),
            lastMessage: lastMessageText?.nilIfBlank,
            lastMessageAt: lastMessageAt.flatMap(parseAPIDate),
            unreadCount: unreadCount
        )
    }
}

private struct ProfessionalMessagesResponseDTO: Decodable {
    let messages: [ProfessionalMessageDTO]
    let cursor: String?
}

private struct ProfessionalMessageDTO: Decodable {
    let id: String
    let senderId: String
    let text: String
    let createdAt: String

    var model: ProfessionalMessage {
        ProfessionalMessage(
            id: id,
            senderID: senderId,
            text: text,
            createdAt: parseAPIDate(createdAt) ?? .now
        )
    }
}

private struct ProfessionalStatsResponseDTO: Decodable {
    let stats: ProfessionalStatsDTO
}

private struct ProfessionalStatsDTO: Decodable {
    let profileViews: ProfessionalMetricDTO
    let phoneReveals: ProfessionalMetricDTO
    let whatsappOpens: ProfessionalMetricDTO
    let contactOpens: ProfessionalMetricDTO
    let phoneRevealRateLast30: Int
    let contactConversionRateLast30: Int

    var model: ProfessionalStats {
        ProfessionalStats(
            profileViews: profileViews.model,
            phoneReveals: phoneReveals.model,
            whatsappOpens: whatsappOpens.model,
            contactOpens: contactOpens.model,
            phoneRevealRateLast30: phoneRevealRateLast30,
            contactConversionRateLast30: contactConversionRateLast30
        )
    }
}

private struct ProfessionalMetricDTO: Decodable {
    let total: Int
    let last30: Int
    let last7: Int
    let today: Int
    let uniqueLast30: Int

    var model: ProfessionalMetric {
        ProfessionalMetric(total: total, last30: last30, last7: last7, today: today, uniqueLast30: uniqueLast30)
    }
}

private struct CreditAccountDTO: Decodable {
    let balance: Int
    let transactions: [CreditTransactionDTO]
    let premium: Bool?
    let premiumUntil: String?

    var model: CreditAccount {
        CreditAccount(
            balance: balance,
            transactions: transactions.map(\.model),
            premium: premium ?? false,
            premiumUntil: premiumUntil.flatMap(parseAPIDate)
        )
    }
}

private struct CreditTransactionDTO: Decodable {
    let id: String
    let type: String
    let amount: Int
    let taskId: String?
    let createdAt: String

    var model: CreditTransaction {
        CreditTransaction(
            id: id,
            type: type,
            amount: amount,
            taskID: taskId,
            createdAt: parseAPIDate(createdAt) ?? .now
        )
    }
}

private struct PublicSpecialistDTO: Decodable {
    let id: String
    let name: String
    let avatarUrl: String?
    let categories: [String]
    let bio: String?
    let rating: Double
    let reviewCount: Int
    let completedJobsCount: Int
    let verified: Bool
    let phoneVerified: Bool
    let licenseVerified: Bool
    let insuranceVerified: Bool
    let portfolioVerified: Bool
    let reviewsVerified: Bool
    let availableNow: Bool
    let premium: Bool
    let city: String
    let portfolioPhotos: [String]
    let portfolioAlbums: [PortfolioAlbumDTO]

    enum CodingKeys: String, CodingKey {
        case id, name, avatarUrl, categories, bio, rating, city, premium, verified, phoneVerified, licenseVerified, insuranceVerified, portfolioVerified, reviewsVerified
        case reviewCount, completedJobsCount, availableNow, portfolioPhotos, portfolioAlbums
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        avatarUrl = try values.decodeIfPresent(String.self, forKey: .avatarUrl)
        bio = try values.decodeIfPresent(String.self, forKey: .bio)
        rating = try values.decodeIfPresent(Double.self, forKey: .rating) ?? 0
        reviewCount = try values.decodeIfPresent(Int.self, forKey: .reviewCount) ?? 0
        completedJobsCount = try values.decodeIfPresent(Int.self, forKey: .completedJobsCount) ?? 0
        city = try values.decodeIfPresent(String.self, forKey: .city) ?? ""
        premium = try values.decodeFlexibleBool(forKey: .premium)
        verified = try values.decodeFlexibleBool(forKey: .verified)
        phoneVerified = try values.decodeFlexibleBool(forKey: .phoneVerified)
        licenseVerified = try values.decodeFlexibleBool(forKey: .licenseVerified)
        insuranceVerified = try values.decodeFlexibleBool(forKey: .insuranceVerified)
        portfolioVerified = try values.decodeFlexibleBool(forKey: .portfolioVerified)
        reviewsVerified = try values.decodeFlexibleBool(forKey: .reviewsVerified)
        availableNow = try values.decodeFlexibleBool(forKey: .availableNow)
        if let photos = try? values.decode([String].self, forKey: .portfolioPhotos) {
            portfolioPhotos = photos
        } else if let json = try? values.decode(String.self, forKey: .portfolioPhotos),
                  let data = json.data(using: .utf8),
                  let photos = try? JSONDecoder().decode([String].self, from: data) {
            portfolioPhotos = photos
        } else {
            portfolioPhotos = []
        }
        portfolioAlbums = values.decodeJSONArray(PortfolioAlbumDTO.self, forKey: .portfolioAlbums)

        if let array = try? values.decode([String].self, forKey: .categories) {
            categories = array
        } else if let json = try? values.decode(String.self, forKey: .categories),
                  let data = json.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) {
            categories = decoded
        } else {
            categories = []
        }
    }

    var model: Specialist {
        let categoryTitle = categories
            .compactMap { id in ServiceCategory.catalog.first(where: { $0.id == id })?.title }
            .first ?? .init(he: "בעל מקצוע לבית", ru: "Мастер по ремонту", en: "Home repair specialist")
        let localizedCity = LocalizedValue(he: city, ru: city, en: city)
        let publicBio = bio ?? ""
        let projects = portfolioAlbums.compactMap { $0.model(baseURL: AppConfiguration.apiBaseURL) }
        let photos = uniqueURLs(
            portfolioPhotos.compactMap(resolvePublicURL)
                + projects.flatMap(\.photoURLs)
        )
        return Specialist(
            id: id,
            name: name,
            avatarURL: resolvedAvatarURL,
            profession: categoryTitle,
            city: localizedCity,
            rating: rating,
            reviewCount: reviewCount,
            completedJobs: completedJobsCount,
            premium: premium,
            verified: verified,
            trust: SpecialistTrust(
                verified: verified,
                phoneVerified: phoneVerified,
                licenseVerified: licenseVerified,
                insuranceVerified: insuranceVerified,
                portfolioVerified: portfolioVerified,
                reviewsVerified: reviewsVerified
            ),
            availableNow: availableNow,
            bio: .init(he: publicBio, ru: publicBio, en: publicBio),
            categories: categories,
            yearsExperience: 0,
            portfolioURLs: photos,
            portfolioProjects: projects
        )
    }

    private var resolvedAvatarURL: URL? {
        guard let avatarUrl, !avatarUrl.isEmpty else { return nil }
        if let absolute = URL(string: avatarUrl), absolute.scheme != nil {
            return absolute
        }
        return URL(string: avatarUrl, relativeTo: AppConfiguration.apiBaseURL)?.absoluteURL
    }

    private func resolvePublicURL(_ value: String) -> URL? {
        if let absolute = URL(string: value), absolute.scheme != nil { return absolute }
        return URL(string: value, relativeTo: AppConfiguration.apiBaseURL)?.absoluteURL
    }
}

private struct PublicSpecialistDetailsDTO: Decodable {
    let portfolioPhotos: [String]
    let portfolioAlbums: [PortfolioAlbumDTO]
    let contactAvailable: Bool
    let whatsappAvailable: Bool
    let reviews: [PublicSpecialistReviewDTO]

    enum CodingKeys: String, CodingKey {
        case portfolioPhotos, portfolioAlbums, contactAvailable, whatsappAvailable, reviews
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        if let photos = try? values.decode([String].self, forKey: .portfolioPhotos) {
            portfolioPhotos = photos
        } else if let json = try? values.decode(String.self, forKey: .portfolioPhotos),
                  let data = json.data(using: .utf8),
                  let photos = try? JSONDecoder().decode([String].self, from: data) {
            portfolioPhotos = photos
        } else {
            portfolioPhotos = []
        }
        portfolioAlbums = values.decodeJSONArray(PortfolioAlbumDTO.self, forKey: .portfolioAlbums)
        contactAvailable = (try? values.decode(Bool.self, forKey: .contactAvailable)) ?? false
        whatsappAvailable = (try? values.decode(Bool.self, forKey: .whatsappAvailable)) ?? false
        reviews = (try? values.decode([PublicSpecialistReviewDTO].self, forKey: .reviews)) ?? []
    }

    var model: SpecialistProfileDetails {
        let projects = portfolioAlbums.compactMap { $0.model(baseURL: AppConfiguration.apiBaseURL) }
        let photos = uniqueURLs(
            portfolioPhotos.compactMap { resolveAPIURL($0) }
                + projects.flatMap(\.photoURLs)
        )
        return SpecialistProfileDetails(
            portfolioURLs: photos,
            portfolioProjects: projects,
            contactAvailable: contactAvailable,
            whatsappAvailable: whatsappAvailable,
            reviews: reviews.map(\.model)
        )
    }
}

private struct PortfolioAlbumDTO: Decodable {
    let id: String
    let title: String
    let photos: [String]
    let cover: String?

    func model(baseURL: URL) -> SpecialistProject? {
        let photoURLs = uniqueURLs(photos.compactMap { resolveAPIURL($0, baseURL: baseURL) })
        guard !photoURLs.isEmpty else { return nil }
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return SpecialistProject(
            id: id,
            title: normalizedTitle.isEmpty ? "Project" : normalizedTitle,
            photoURLs: photoURLs,
            coverURL: resolveAPIURL(cover, baseURL: baseURL)
        )
    }
}

private struct PublicSpecialistReviewDTO: Decodable {
    let id: String
    let rating: Double
    let text: String?
    let clientName: String?
    let createdAt: String?

    var model: SpecialistReview {
        SpecialistReview(
            id: id,
            author: clientName?.isEmpty == false ? clientName! : "KABLAY",
            rating: rating,
            text: text ?? "",
            createdAt: createdAt.flatMap(parseAPIDate)
        )
    }
}

private struct BlogCatalogDTO: Decodable {
    let items: [BlogArticleDTO]
    let pages: Int?
}

private struct BlogArticleDTO: Decodable {
    let slug: String
    let category: String?
    let titleHe: String
    let titleEn: String
    let titleRu: String
    let excerptHe: String
    let excerptEn: String
    let excerptRu: String
    let contentHe: String?
    let contentEn: String?
    let contentRu: String?
    let coverUrl: String?
    let publishedAt: String?
    let readMinutes: Int?

    var model: BlogArticle {
        let content = LocalizedValue(he: contentHe ?? "", ru: contentRu ?? "", en: contentEn ?? "")
        return BlogArticle(
            id: slug,
            title: .init(he: titleHe, ru: titleRu, en: titleEn),
            summary: .init(he: excerptHe, ru: excerptRu, en: excerptEn),
            categoryID: normalizedCategory,
            readingMinutes: readMinutes ?? estimatedReadingMinutes(for: content),
            coverURL: coverUrl.flatMap { URL(string: $0, relativeTo: AppConfiguration.webBaseURL)?.absoluteURL },
            publishedAt: publishedAt.flatMap(parseAPIDate),
            content: content
        )
    }

    /// The published catalog carries no reading estimate, so it is derived from
    /// the longest available translation rather than shown as a fixed number.
    private func estimatedReadingMinutes(for content: LocalizedValue) -> Int {
        let longest = [content.he, content.ru, content.en].max(by: { $0.count < $1.count }) ?? ""
        guard !longest.isEmpty else { return 7 }
        return ArticleContent.readingMinutes(from: longest)
    }

    private var normalizedCategory: String {
        if let category, ServiceCategory.catalog.contains(where: { $0.id == category }) { return category }
        if slug.localizedCaseInsensitiveContains("elektr") { return "electrician" }
        if slug.localizedCaseInsensitiveContains("plit") { return "tiler" }
        if slug.localizedCaseInsensitiveContains("uborka") { return "cleaning" }
        if slug.localizedCaseInsensitiveContains("pokrask") || slug.localizedCaseInsensitiveContains("shtuk") { return "painter" }
        if slug.localizedCaseInsensitiveContains("muzhchina-na-chas") { return "handyman" }
        if slug.localizedCaseInsensitiveContains("potol") { return "stretch-ceilings" }
        if slug.localizedCaseInsensitiveContains("remont") { return "renovation" }
        if slug.localizedCaseInsensitiveContains("gips") { return "drywall" }
        return "plumbing"
    }
}

private struct NotificationsResponseDTO: Decodable {
    let notifications: [NotificationDTO]
}

private struct NotificationDTO: Decodable {
    let id: String
    let kind: String
    let taskId: String?
    let payload: NotificationPayloadDTO
    let createdAt: String
    let readAt: String?

    func model(for role: UserRole?) -> AppNotification {
        let specialist = payload.specialistName?.nilIfBlank ?? "KABLAY"
        let task = payload.taskTitle?.nilIfBlank ?? ""
        let content: (LocalizedValue, LocalizedValue, String)
        switch kind {
        case "admin_credit_gift":
            content = (
                payload.titleLocalized ?? payload.title?.localized ?? .init(he: "מתנה מ-KABLAY: ‏30 נקודות", ru: "Подарок от KABLAY: 30 баллов", en: "A gift from KABLAY: 30 credits"),
                payload.bodyLocalized ?? payload.body?.localized ?? .init(he: "הוספנו 30 נקודות לחשבון שלכם.", ru: "Мы начислили 30 баллов на ваш счёт.", en: "We added 30 credits to your balance."),
                "gift.fill"
            )
        case "admin_announcement":
            content = (
                payload.titleLocalized ?? payload.title?.localized ?? .init(he: "הודעה מ-KABLAY", ru: "Сообщение от KABLAY", en: "From KABLAY"),
                payload.bodyLocalized ?? payload.body?.localized ?? .init(he: "עדכון חדש מהצוות.", ru: "Новое сообщение от команды.", en: "A new update from the team."),
                "megaphone.fill"
            )
        case "task_assignment":
            content = (
                .init(he: "בעל מקצוע נבחר", ru: "Мастер выбран", en: "Specialist selected"),
                .init(
                    he: task.isEmpty ? "\(specialist) קיבל את הבקשה שלך." : "\(specialist) קיבל את הבקשה „\(task)”.",
                    ru: task.isEmpty ? "\(specialist) принял вашу заявку." : "\(specialist) принял заявку «\(task)».",
                    en: task.isEmpty ? "\(specialist) accepted your request." : "\(specialist) accepted “\(task)”."
                ),
                "person.crop.circle.badge.checkmark"
            )
        case "chat_message", "message_received", "messages":
            content = (
                .init(he: "הודעה חדשה", ru: "Новое сообщение", en: "New message"),
                .init(
                    he: payload.body?.localized.he.nilIfBlank ?? (task.isEmpty ? "פתחו את הצ׳אט כדי לקרוא את ההודעה." : "הודעה חדשה על הבקשה „\(task)”. פתחו את הצ׳אט."),
                    ru: payload.body?.localized.ru.nilIfBlank ?? (task.isEmpty ? "Откройте чат, чтобы прочитать сообщение." : "Новое сообщение по заявке «\(task)». Откройте чат."),
                    en: payload.body?.localized.en.nilIfBlank ?? (task.isEmpty ? "Open the chat to read the message." : "New message about “\(task)”. Open the chat.")
                ),
                "message.fill"
            )
        case "new_jobs":
            let admin = role == .admin
            content = (
                .init(
                    he: admin ? "נוצרה הזמנה חדשה" : "הזמנה חדשה מתאימה",
                    ru: admin ? "Создан новый заказ" : "Новый подходящий заказ",
                    en: admin ? "New request created" : "New matching job"
                ),
                .init(
                    he: task.isEmpty ? (admin ? "בדקו את ההזמנה בלוח הניהול." : "פתחו את ההזמנה כדי לראות את הפרטים.") : "הזמנה חדשה: „\(task)”. פתחו לפרטים.",
                    ru: task.isEmpty ? (admin ? "Проверьте заказ в панели администратора." : "Откройте заказ, чтобы посмотреть детали.") : "Новая заявка: «\(task)». Откройте детали.",
                    en: task.isEmpty ? (admin ? "Review the request in the admin dashboard." : "Open the job to see the details.") : "New request: “\(task)”. Open for details."
                ),
                "briefcase.fill"
            )
        case "task_updates":
            content = (
                .init(he: "ההצעה שלכם נבחרה", ru: "Ваш отклик выбран", en: "Your offer was selected"),
                .init(
                    he: task.isEmpty ? "הלקוח בחר בהצעה שלכם. פתחו את פרטי העבודה." : "הלקוח בחר בהצעה שלכם לבקשה „\(task)”.",
                    ru: task.isEmpty ? "Клиент выбрал ваш отклик. Откройте заказ." : "Клиент выбрал ваш отклик на заявку «\(task)».",
                    en: task.isEmpty ? "The client selected your offer. Open the job." : "The client selected your offer for “\(task)”."
                ),
                "checkmark.circle.fill"
            )
        case "registrations":
            let specialistRegistered = id.contains("specialist.registered")
            content = (
                .init(
                    he: specialistRegistered ? "בעל מקצוע חדש נרשם" : "משתמש חדש נרשם",
                    ru: specialistRegistered ? "Зарегистрирован новый мастер" : "Зарегистрирован новый пользователь",
                    en: specialistRegistered ? "New professional registered" : "New user registered"
                ),
                .init(
                    he: specialistRegistered ? "בדקו את הפרופיל החדש בלוח הניהול." : "בדקו את החשבון החדש בלוח הניהול.",
                    ru: specialistRegistered ? "Проверьте анкету мастера в панели администратора." : "Проверьте новый аккаунт в панели администратора.",
                    en: specialistRegistered ? "Review the professional profile in the admin dashboard." : "Review the new account in the admin dashboard."
                ),
                "person.crop.circle.badge.plus"
            )
        default:
            let serverTitle = payload.title?.localized
            let fallbackBody = payload.body?.localized
            content = (
                .init(he: serverTitle?.he.nilIfBlank ?? "עדכון חדש", ru: serverTitle?.ru.nilIfBlank ?? "Новое событие", en: serverTitle?.en.nilIfBlank ?? "New update"),
                .init(
                    he: fallbackBody?.he.nilIfBlank ?? (task.isEmpty ? "פתחו את הפרטים כדי לראות מה השתנה." : "עדכון בבקשה „\(task)”."),
                    ru: fallbackBody?.ru.nilIfBlank ?? (task.isEmpty ? "Откройте уведомление, чтобы узнать подробности." : "Изменение по заявке «\(task)»."),
                    en: fallbackBody?.en.nilIfBlank ?? (task.isEmpty ? "Open the notification for details." : "Update about “\(task)”.")
                ),
                "bell.badge.fill"
            )
        }
        let conversationID = payload.conversationId ?? URLComponents(string: payload.url ?? "")?
            .queryItems?.first(where: { $0.name == "conversation" })?.value
        return AppNotification(
            id: id,
            title: content.0,
            body: content.1,
            systemImage: content.2,
            createdAt: parseAPIDate(createdAt) ?? .now,
            isRead: readAt != nil,
            taskID: taskId ?? payload.taskId,
            conversationID: conversationID,
            kind: kind
        )
    }
}

private struct NotificationPayloadDTO: Decodable {
    let taskId: String?
    let taskTitle: String?
    let specialistName: String?
    let conversationId: String?
    let body: NotificationTextDTO?
    let title: NotificationTextDTO?
    let bodyLocalized: LocalizedValue?
    let titleLocalized: LocalizedValue?
    let url: String?
}

private struct NotificationTextDTO: Decodable {
    let localized: LocalizedValue

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if let text = try? value.decode(String.self) {
            localized = .init(he: text, ru: text, en: text)
        } else {
            localized = try value.decode(LocalizedValue.self)
        }
    }
}

private struct TasksResponseDTO: Decodable {
    let tasks: [RepairTaskDTO]
    let pages: Int?
}

private struct ServiceCatalogResponseDTO: Decodable {
    let version: String
    let categories: [ServiceCatalogCategoryDTO]
}

private struct ServiceCatalogCategoryDTO: Decodable {
    let id: String
    let title: LocalizedValue
    let systemImage: String
    let tintHex: String
    let groups: [ServiceCatalogGroupDTO]

    var model: ServiceCategory {
        ServiceCategory(
            id: id,
            title: title,
            systemImage: systemImage,
            tintHex: tintHex,
            groups: groups.map(\.model)
        )
    }
}

private struct ServiceCatalogGroupDTO: Decodable {
    let id: String
    let title: LocalizedValue
    let services: [ServiceCatalogServiceDTO]

    var model: ServiceGroup {
        ServiceGroup(id: id, title: title, services: services.map(\.title))
    }
}

private struct ServiceCatalogServiceDTO: Decodable {
    let id: String
    // JSONDecoder.convertFromSnakeCase maps task_type_id to taskTypeId.
    let taskTypeId: String
    let title: LocalizedValue
}

private struct TaskDetailsResponseDTO: Decodable {
    let task: RepairTaskDTO
    let proposals: [TaskProposalDTO]
    let detail: TaskDetailDTO?
}

private struct ProposalIdentityDTO: Decodable { let id: String }

private struct TaskProposalDTO: Decodable {
    let id: String
    let specialistId: String?
    let specialistName: String?
    let specialistAvatarUrl: String?
    let specialistRating: Double?
    let specialistReviewCount: Int?
    let specialistVerified: Bool?
    let specialistPhoneVerified: Bool?
    let specialistLicenseVerified: Bool?
    let specialistInsuranceVerified: Bool?
    let specialistPortfolioVerified: Bool?
    let specialistReviewsVerified: Bool?
    let price: Int?
    let message: String?
    let status: String?
    let createdAt: String?

    func model(baseURL: URL) -> TaskProposal {
        TaskProposal(
            id: id,
            specialistID: specialistId ?? "",
            specialistName: specialistName?.nilIfBlank ?? "Specialist",
            specialistAvatarURL: resolveAPIURL(specialistAvatarUrl, baseURL: baseURL),
            rating: specialistRating,
            reviewCount: specialistReviewCount,
            price: price,
            message: message?.nilIfBlank,
            status: status ?? "pending",
            createdAt: createdAt.flatMap(parseAPIDate),
            trust: SpecialistTrust(
                verified: specialistVerified ?? false,
                phoneVerified: specialistPhoneVerified ?? false,
                licenseVerified: specialistLicenseVerified ?? false,
                insuranceVerified: specialistInsuranceVerified ?? false,
                portfolioVerified: specialistPortfolioVerified ?? false,
                reviewsVerified: specialistReviewsVerified ?? false
            )
        )
    }
}

private struct TaskDetailDTO: Decodable {
    let orderNumber: Int?
    let attachments: [String]?
    let location: TaskLocationDTO?
    let client: TaskClientContactDTO?
    let viewerProposal: ProposalIdentityDTO?
    let viewerConversationId: String?
    let viewerPremium: Bool?
    let responseCostCredits: Int?
    let responseAvailable: Bool?
    let responseAvailableAt: String?
    let responseBlockedReason: String?
    let verificationContact: VerificationContactDTO?
    let acceptedSpecialistContact: AcceptedSpecialistContactDTO?
    let completionRecord: CompletionRecordDTO?

    var responseState: TaskResponseState? {
        guard responseAvailable != nil
            || responseBlockedReason != nil
            || responseCostCredits != nil
            || viewerProposal != nil else { return nil }
        return TaskResponseState(
            available: responseAvailable ?? false,
            blockedReason: responseBlockedReason,
            availableAt: responseAvailableAt.flatMap(parseAPIDate),
            costCredits: responseCostCredits,
            viewerProposalID: viewerProposal?.id,
            viewerPremium: viewerPremium,
            verificationContact: verificationContact?.model
        )
    }

    func acceptedSpecialist(baseURL: URL) -> AcceptedSpecialistContact? {
        acceptedSpecialistContact?.model(baseURL: baseURL)
    }
}

private struct VerificationContactDTO: Decodable {
    let phoneDisplay: String?
    let phoneE164: String?
    let whatsappUrl: String?

    var model: VerificationContact {
        VerificationContact(
            phoneDisplay: phoneDisplay?.nilIfBlank,
            phoneE164: phoneE164?.nilIfBlank,
            whatsappURL: whatsappUrl?.nilIfBlank.flatMap { URL(string: $0) }
        )
    }
}

private struct CompletionRecordDTO: Decodable {
    let specialistFinalAmount: Int
    let specialistNote: String?
    let specialistSubmittedAt: String
    let clientPaidAmount: Int?
    let clientNote: String?
    let clientConfirmedAt: String?
    let expenseAmount: Int?
    let media: [CompletionMediaDTO]
}

private struct CompletionMediaDTO: Decodable {
    let kind: String
    let url: String?
}

private struct AcceptedSpecialistContactDTO: Decodable {
    let specialistId: String
    let userId: String
    let name: String
    let phone: String?
    let whatsapp: String?
    let email: String?
    let avatarUrl: String?

    func model(baseURL: URL) -> AcceptedSpecialistContact {
        AcceptedSpecialistContact(
            specialistID: specialistId,
            userID: userId,
            name: name,
            avatarURL: resolveAPIURL(avatarUrl, baseURL: baseURL),
            phone: phone?.nilIfBlank,
            whatsapp: whatsapp?.nilIfBlank,
            email: email?.nilIfBlank
        )
    }
}

private struct TaskClientContactDTO: Decodable {
    let id: String
    let name: String?
    let phone: String?
    let email: String?
    let clientRating: Double?
    let clientReviewCount: Int?

    var model: TaskClientContact {
        TaskClientContact(
            id: id,
            name: name?.nilIfBlank ?? "Client",
            phone: phone?.nilIfBlank,
            email: email?.nilIfBlank,
            rating: clientRating,
            reviewCount: clientReviewCount
        )
    }
}

private struct TaskLocationDTO: Decodable {
    let latitude: Double
    let longitude: Double
    let approximate: Bool

    var model: TaskMapLocation {
        TaskMapLocation(latitude: latitude, longitude: longitude, approximate: approximate)
    }
}

private struct RepairTaskDTO: Decodable {
    let id: String
    let orderNumber: Int?
    let title: String
    let categoryId: String?
    let canonicalCategorySlug: String?
    let description: String?
    let city: String?
    let address: String?
    let whenNeeded: String?
    let scheduledFor: String?
    let status: String
    let createdAt: String
    let proposalCount: Int?
    let budgetMin: Double?
    let budgetMax: Double?
    let completionAmount: Int?
    let completionRequestedAt: String?
    let completionConfirmedAt: String?

    func model(baseURL: URL) -> RepairTask {
        model(proposals: [], detail: nil, baseURL: baseURL)
    }

    func model(proposals: [TaskProposal], detail: TaskDetailDTO?, baseURL: URL) -> RepairTask {
        let effectiveProposalCount = proposalCount ?? proposals.count
        let mappedStatus: TaskStatus
        switch status {
        case "open": mappedStatus = effectiveProposalCount > 0 ? .proposalReceived : .open
        case "in_progress": mappedStatus = .inProgress
        case "done", "completed": mappedStatus = .completed
        case "cancelled": mappedStatus = .cancelled
        default: mappedStatus = .archived
        }
        let budget = formattedBudget(minimum: budgetMin, maximum: budgetMax)
        return RepairTask(
            id: id,
            orderNumber: orderNumber ?? detail?.orderNumber,
            title: title,
            categoryID: canonicalCategorySlug ?? categoryId ?? "handyman",
            description: description?.nilIfBlank,
            city: city ?? "",
            address: address?.nilIfBlank,
            whenNeeded: whenNeeded?.nilIfBlank,
            scheduledFor: scheduledFor.flatMap(parseAPIDate),
            status: mappedStatus,
            createdAt: parseAPIDate(createdAt) ?? .now,
            proposalCount: effectiveProposalCount,
            budget: budget,
            attachmentURLs: detail?.attachments?.compactMap { resolveAPIURL($0, baseURL: baseURL) } ?? [],
            location: detail?.location?.model,
            responseState: detail?.responseState,
            client: detail?.client?.model,
            viewerConversationID: detail?.viewerConversationId,
            proposals: proposals,
            acceptedSpecialist: detail?.acceptedSpecialist(baseURL: baseURL),
            completion: completionAmount.flatMap { amount in
                completionRequestedAt.flatMap(parseAPIDate).map {
                    TaskCompletion(
                        specialistFinalAmount: amount,
                        requestedAt: $0,
                        confirmedAt: completionConfirmedAt.flatMap(parseAPIDate),
                        specialistNote: detail?.completionRecord?.specialistNote?.nilIfBlank,
                        clientPaidAmount: detail?.completionRecord?.clientPaidAmount,
                        clientNote: detail?.completionRecord?.clientNote?.nilIfBlank,
                        expenseAmount: detail?.completionRecord?.expenseAmount,
                        specialistPhotoURLs: detail?.completionRecord?.media
                            .filter { $0.kind == "specialist_after" }
                            .compactMap { resolveAPIURL($0.url, baseURL: baseURL) } ?? [],
                        clientPhotoURLs: detail?.completionRecord?.media
                            .filter { $0.kind == "client_after" }
                            .compactMap { resolveAPIURL($0.url, baseURL: baseURL) } ?? [],
                        expenseReceiptURLs: detail?.completionRecord?.media
                            .filter { $0.kind == "expense_receipt" }
                            .compactMap { resolveAPIURL($0.url, baseURL: baseURL) } ?? []
                    )
                }
            }
        )
    }
}

private func parseAPIDate(_ value: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
}

private func formattedBudget(minimum: Double?, maximum: Double?) -> String? {
    switch (minimum, maximum) {
    case let (minimum?, maximum?): "₪\(Int(minimum))–\(Int(maximum))"
    case let (minimum?, nil): "₪\(Int(minimum))+"
    case let (nil, maximum?): "≤ ₪\(Int(maximum))"
    default: nil
    }
}

private func resolveAPIURL(_ value: String?, baseURL: URL = AppConfiguration.apiBaseURL) -> URL? {
    guard let value = value?.nilIfBlank else { return nil }
    if let absolute = URL(string: value), absolute.scheme != nil { return absolute }
    return URL(string: value, relativeTo: baseURL)?.absoluteURL
}

private func uniqueURLs(_ values: [URL]) -> [URL] {
    var seen = Set<String>()
    return values.filter { seen.insert($0.absoluteString).inserted }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleBool(forKey key: Key) throws -> Bool {
        if let value = try? decode(Bool.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) { return value != 0 }
        return false
    }

    func decodeStringArray(forKey key: Key) -> [String] {
        if let values = try? decode([String].self, forKey: key) { return values }
        guard let json = try? decode(String.self, forKey: key),
              let data = json.data(using: .utf8),
              let values = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return values
    }

    func decodeJSONArray<Value: Decodable>(_ type: Value.Type, forKey key: Key) -> [Value] {
        if let values = try? decode([Value].self, forKey: key) { return values }
        guard let json = try? decode(String.self, forKey: key),
              let data = json.data(using: .utf8),
              let values = try? JSONDecoder().decode([Value].self, from: data) else {
            return []
        }
        return values
    }
}

private struct ErrorEnvelope: Decodable {
    let error: String
    let code: String?
}

enum AppConfiguration {
    static let apiBaseURL = configuredURL(key: "KABLAY_API_BASE_URL", fallback: "https://api.kablay.co.il/")
    static let triageBaseURL = configuredURL(key: "KABLAY_TRIAGE_BASE_URL", fallback: "https://kablay-triage.sergii-ziborov.workers.dev/")
    static let webBaseURL = URL(string: "https://kablay.co.il/")!

    #if DEBUG
    static let pushEnvironment = "sandbox"
    #else
    static let pushEnvironment = "production"
    #endif

    private static func configuredURL(key: String, fallback: String) -> URL {
        let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String ?? fallback
        let normalized = raw.hasSuffix("/") ? raw : "\(raw)/"
        return URL(string: normalized) ?? URL(string: fallback)!
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
