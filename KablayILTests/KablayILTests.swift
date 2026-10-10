import XCTest
import UIKit
@testable import KablayIL

final class KablayILTests: XCTestCase {
    func testCategoryWebPCoversAreBundledAndDecodable() throws {
        for category in ServiceCategory.catalog {
            let url = try XCTUnwrap(
                Bundle.main.url(forResource: category.id, withExtension: "webp"),
                "Missing WebP cover for \(category.id)"
            )
            XCTAssertNotNil(UIImage(contentsOfFile: url.path), "Invalid WebP cover for \(category.id)")
        }
    }

    func testArticleHTMLBecomesNativeBlocks() {
        let html = #"""
        <div class="intro"><p>KABLAY <strong>соединяет</strong> клиентов и мастеров.</p></div>
        <h2>Откуда приходят клиенты</h2>
        <ul><li>Лента <strong>доступных задач</strong></li><li>Прямые обращения</li></ul>
        <ol><li>Первый шаг</li><li>Второй шаг</li></ol>
        <aside>Проверьте лицензию до начала работ.</aside>
        <blockquote>Цена без объёма — не цена.</blockquote>
        <table><thead><tr><th>План</th><th>Контакты</th></tr></thead>
        <tbody><tr><td>Базовый</td><td>За баллы</td></tr></tbody></table>
        <p>Подробнее в <a href="/ru/pro">кабинете</a> &mdash; без &laquo;сюрпризов&raquo;.</p>
        """#

        let blocks = ArticleContent.blocks(from: html, baseURL: AppConfiguration.webBaseURL)

        guard case let .paragraph(intro) = blocks.first else {
            return XCTFail("The first block should be the intro paragraph, got \(String(describing: blocks.first))")
        }
        XCTAssertEqual(String(intro.characters), "KABLAY соединяет клиентов и мастеров.")

        guard case let .heading(level, heading) = blocks[1] else { return XCTFail("Expected a heading") }
        XCTAssertEqual(level, 2)
        XCTAssertEqual(String(heading.characters), "Откуда приходят клиенты")

        guard case let .bullets(bullets) = blocks[2] else { return XCTFail("Expected a bullet list") }
        XCTAssertEqual(bullets.map { String($0.characters) }, ["Лента доступных задач", "Прямые обращения"])

        guard case let .numbered(numbered) = blocks[3] else { return XCTFail("Expected a numbered list") }
        XCTAssertEqual(numbered.map { String($0.characters) }, ["Первый шаг", "Второй шаг"])

        guard case let .callout(callout) = blocks[4] else { return XCTFail("Expected a callout") }
        XCTAssertEqual(String(callout.characters), "Проверьте лицензию до начала работ.")

        guard case let .quote(quote) = blocks[5] else { return XCTFail("Expected a quote") }
        XCTAssertEqual(String(quote.characters), "Цена без объёма — не цена.")

        guard case let .table(headers, rows) = blocks[6] else { return XCTFail("Expected a table") }
        XCTAssertEqual(headers.map { String($0.characters) }, ["План", "Контакты"])
        XCTAssertEqual(rows.map { $0.map { String($0.characters) } }, [["Базовый", "За баллы"]])

        guard case let .paragraph(outro) = blocks[7] else { return XCTFail("Expected the closing paragraph") }
        XCTAssertEqual(String(outro.characters), "Подробнее в кабинете — без «сюрпризов».")
    }

    func testArticleInlineRunsKeepEmphasisAndLinks() {
        let blocks = ArticleContent.blocks(
            from: "<p>Читайте <strong>условия</strong> и <a href=\"/ru/legal\">правила</a>.</p>",
            baseURL: AppConfiguration.webBaseURL
        )
        guard case let .paragraph(text) = blocks.first else { return XCTFail("Expected a paragraph") }

        var boldRuns = 0
        var linkTargets: [URL] = []
        for run in text.runs {
            if run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true { boldRuns += 1 }
            if let link = run.link { linkTargets.append(link) }
        }
        XCTAssertEqual(boldRuns, 1)
        XCTAssertEqual(linkTargets.map(\.path), ["/ru/legal"])
    }

    func testArticleReadingTimeGrowsWithLength() {
        let short = ArticleContent.readingMinutes(from: "<p>Короткая заметка</p>")
        let long = ArticleContent.readingMinutes(
            from: "<p>" + String(repeating: "слово ", count: 1_800) + "</p>"
        )
        XCTAssertEqual(short, 1)
        XCTAssertEqual(long, 10)
        XCTAssertLessThanOrEqual(long, 60)
    }

    func testHebrewUsesRightToLeftLayout() {
        XCTAssertEqual(AppLocale.he.layoutDirection, .rightToLeft)
        XCTAssertEqual(AppLocale.ru.layoutDirection, .leftToRight)
        XCTAssertEqual(AppLocale.en.layoutDirection, .leftToRight)
    }

    func testRequestLanguageDetectionDistinguishesSupportedScripts() {
        XCTAssertEqual(AppLocale.detected(in: "צריך להחליף ברז"), .he)
        XCTAssertEqual(AppLocale.detected(in: "Нужно заменить кран"), .ru)
        XCTAssertEqual(AppLocale.detected(in: "Replace the faucet"), .en)
        XCTAssertNil(AppLocale.detected(in: "123 ₪"))
    }

    func testAppLanguageFollowsSupportedIPhoneLanguageOrder() {
        XCTAssertEqual(AppLocale.preferred(from: ["ru-IL"]), .ru)
        XCTAssertEqual(AppLocale.preferred(from: ["en-US"]), .en)
        XCTAssertEqual(AppLocale.preferred(from: ["he-IL"]), .he)
        XCTAssertEqual(AppLocale.preferred(from: ["iw-IL"]), .he)
        XCTAssertEqual(AppLocale.preferred(from: ["fr-FR", "ru-RU", "en-US"]), .ru)
        // The app ships to App Store regions outside Israel, so a device in a
        // language KABLAY does not speak opens in English, not Hebrew.
        XCTAssertEqual(AppLocale.preferred(from: ["fr-FR"]), .en)
        XCTAssertEqual(AppLocale.preferred(from: ["de-DE"]), .en)
        XCTAssertEqual(AppLocale.preferred(from: ["es-AR", "pt-BR"]), .en)
        XCTAssertEqual(AppLocale.preferred(from: []), .en)
    }

    func testManualLanguagePreferenceOverridesSystemMode() {
        XCTAssertNil(AppLanguagePreference.system.manualLocale)
        XCTAssertEqual(AppLanguagePreference.he.manualLocale, .he)
        XCTAssertEqual(AppLanguagePreference.en.manualLocale, .en)
        XCTAssertEqual(AppLanguagePreference.ru.manualLocale, .ru)
    }

    func testTaskBudgetAlwaysShowsActionableFinancialState() {
        XCTAssertEqual(taskBudgetText("₪300–500", locale: .ru), "₪300–500")
        XCTAssertEqual(taskBudgetText("≤ ₪500", locale: .ru), "Лимит до ₪500")
        XCTAssertEqual(taskBudgetText("≤ ₪500", locale: .en), "Limit up to ₪500")
        XCTAssertEqual(taskBudgetText("≤ ₪500", locale: .he), "תקציב עד ₪500")
        XCTAssertEqual(taskBudgetText("₪1,000+", locale: .ru), "От ₪1,000")
        XCTAssertEqual(taskBudgetText("₪1,000+", locale: .en), "From ₪1,000")
        XCTAssertEqual(taskBudgetText("₪1,000+", locale: .he), "מ-₪1,000")
        XCTAssertEqual(taskBudgetText("  ", locale: .ru), "Предложите цену")
        XCTAssertEqual(taskBudgetText(nil, locale: .en), "Propose a price")
        XCTAssertEqual(taskBudgetText(nil, locale: .he), "הציעו מחיר")
    }

    func testStoredIsraelCitySlugIsLocalizedForEveryAppLanguage() {
        XCTAssertEqual(IsraelCityCatalog.localizedName(for: "kiryat-gat", locale: .he), "קריית גת")
        XCTAssertEqual(IsraelCityCatalog.localizedName(for: "kiryat-gat", locale: .ru), "Кирьят-Гат")
        XCTAssertEqual(IsraelCityCatalog.localizedName(for: "kiryat-gat", locale: .en), "Kiryat Gat")
        XCTAssertEqual(IsraelCityCatalog.localizedName(for: "Kiryat Gat", locale: .ru), "Кирьят-Гат")
    }

    func testCityPickerFindsCitiesAcrossTheThreeLanguages() {
        let englishMatches = Set(IsraelCityCatalog.matching("As", locale: .en).map(\.slug))
        XCTAssertTrue(englishMatches.isSuperset(of: ["ashdod", "ashkelon"]))
        XCTAssertEqual(IsraelCityCatalog.matching("Ашкел", locale: .ru).first?.slug, "ashkelon")
        XCTAssertEqual(IsraelCityCatalog.matching("אשקל", locale: .he).first?.slug, "ashkelon")
        XCTAssertEqual(IsraelCityCatalog.slug(for: "Ashkelon"), "ashkelon")
        XCTAssertEqual(IsraelCityCatalog.slug(for: "אשקלון"), "ashkelon")
        XCTAssertNil(IsraelCityCatalog.slug(for: ""))
    }

    func testStoredCitySlugIsLocalizedInsideTaskAddress() {
        XCTAssertEqual(
            IsraelCityCatalog.localizingCity(
                in: "Exodus 12, kiryat-gat",
                city: "kiryat-gat",
                locale: .ru
            ),
            "Exodus 12, Кирьят-Гат"
        )
    }

    func testCatalogSlugsAreUniqueAndCoverMarketplaceScope() {
        let ids = ServiceCategory.catalog.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertTrue(Set(["plumbing", "electrician", "drywall", "handyman", "stretch-ceilings", "painter", "tiler", "renovation"]).isSubset(of: Set(ids)))
        XCTAssertTrue(ServiceCategory.catalog.allSatisfy { !$0.groups.isEmpty })
        XCTAssertTrue(ServiceCategory.catalog.allSatisfy { $0.groups.allSatisfy { !$0.services.isEmpty } })
    }

    func testTaskDraftRequiresCategoryTitleCityAndAddress() {
        var draft = TaskDraft()
        XCTAssertFalse(draft.canPublish)
        draft.categoryID = "plumbing"
        draft.title = "Repair hidden leak"
        draft.answers["selectedService"] = "Hidden leak detection"
        draft.city = "Tel Aviv"
        XCTAssertFalse(draft.canPublish)
        draft.address = "10 Dizengoff Street"
        XCTAssertTrue(draft.canPublish)
    }

    func testInitialAppProtectionIsMandatoryOnlyForProfessionalAccounts() {
        XCTAssertFalse(AppState.requiresInitialAppLockSetup(role: .client, isConfigured: false))
        XCTAssertTrue(AppState.requiresInitialAppLockSetup(role: .specialist, isConfigured: false))
        XCTAssertTrue(AppState.requiresInitialAppLockSetup(role: .admin, isConfigured: false))
        XCTAssertFalse(AppState.requiresInitialAppLockSetup(role: .specialist, isConfigured: true))
    }

    func testExpectedViewTaskCancellationDoesNotBecomeAnAlert() {
        XCTAssertTrue(AppState.isExpectedCancellation(CancellationError()))
        XCTAssertTrue(AppState.isExpectedCancellation(URLError(.cancelled)))
        XCTAssertFalse(AppState.isExpectedCancellation(URLError(.notConnectedToInternet)))
    }

    func testOwnSpecialistProfilePreviewNeverLoadsClientOnlyDetailsOrAllowsSelfRequest() {
        XCTAssertFalse(SpecialistProfilePresentation.ownerPreview.loadsPublicDetails)
        XCTAssertFalse(SpecialistProfilePresentation.ownerPreview.allowsDirectRequest)
        XCTAssertTrue(SpecialistProfilePresentation.directory.loadsPublicDetails)
        XCTAssertTrue(SpecialistProfilePresentation.directory.allowsDirectRequest)
    }

    @MainActor
    func testStalePublicSpecialistDetailsDoNotCoverTheLoadedProfileWithAnAlert() async {
        let session = makeMockSession(statusCode: 404) { request in
            XCTAssertEqual(request.url?.path, "/specialists/paused-specialist")
            return #"{"error":"Specialist not found","code":"NOT_FOUND"}"#
        }
        let state = AppState(api: APIClient(
            apiBaseURL: URL(string: "https://example.test/")!,
            triageBaseURL: URL(string: "https://triage.example.test/")!,
            session: session
        ), sessionStore: TestSessionStore())

        let details = await state.loadSpecialistDetails(
            id: "paused-specialist",
            reportFailure: false
        )

        XCTAssertNil(details)
        XCTAssertNil(state.errorMessage)
    }

    @MainActor
    func testRealClientSignInSelectsClientWorkspace() async {
        let session = makeMockSession { request in
            XCTAssertEqual(request.url?.path, "/auth/verify-otp")
            return """
            {"token":"real-client-token","user":{"id":"client-1","name":"Dana","phone":"+972501234567","role":"client"}}
            """
        }
        let state = AppState(api: APIClient(
            apiBaseURL: URL(string: "https://example.test/")!,
            triageBaseURL: URL(string: "https://triage.example.test/")!,
            session: session
        ), sessionStore: TestSessionStore())

        let authenticated = await state.verifyOTP(phone: "+972501234567", code: "123456", name: nil)
        XCTAssertTrue(authenticated, state.errorMessage ?? "Authentication returned false without an error")
        XCTAssertEqual(state.session?.user.role, .client)
        XCTAssertEqual(state.workspaceMode, .client)
        XCTAssertEqual(state.clientTab, .account)
        state.signOut()
    }

    func testTaskCoordinatesAreSentAsPrivateNumericAnswers() async throws {
        let session = makeMockSession { request in
            guard let body = requestBodyData(request),
                  let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any],
                  let answers = json["answers_json"] as? [String: Any],
                  let latitude = answers["latitude"] as? Double,
                  let longitude = answers["longitude"] as? Double else {
                XCTFail("Expected numeric coordinates in answers_json")
                return #"{"task":{"id":"task-map-1"}}"#
            }
            XCTAssertEqual(latitude, 31.776_731, accuracy: 0.000_001)
            XCTAssertEqual(longitude, 35.234_487, accuracy: 0.000_001)
            return #"{"task":{"id":"task-map-1"}}"#
        }
        let api = APIClient(
            apiBaseURL: URL(string: "https://example.test/")!,
            triageBaseURL: URL(string: "https://triage.example.test/")!,
            session: session
        )
        var draft = TaskDraft()
        draft.title = "Repair leak"
        draft.details = "Leak under sink"
        draft.city = "Jerusalem"
        draft.address = "Jaffa Street 10, Jerusalem"
        draft.latitude = 31.776_731
        draft.longitude = 35.234_487

        let taskID = try await api.createTask(draft: draft, token: "token")
        XCTAssertEqual(taskID, "task-map-1")
    }

    func testTaskMapLinksPreserveCoordinatesAndAddressSearch() throws {
        let maps = try XCTUnwrap(URLComponents(url: TaskMapLinks.maps(
            latitude: 32.0853,
            longitude: 34.7818
        ), resolvingAgainstBaseURL: false))
        XCTAssertEqual(maps.host, "maps.apple.com")
        XCTAssertEqual(maps.queryItems?.first(where: { $0.name == "ll" })?.value, "32.0853,34.7818")

        let waze = try XCTUnwrap(URLComponents(url: TaskMapLinks.waze(
            latitude: 32.0853,
            longitude: 34.7818
        ), resolvingAgainstBaseURL: false))
        XCTAssertEqual(waze.queryItems?.first(where: { $0.name == "ll" })?.value, "32.0853,34.7818")
        XCTAssertEqual(waze.queryItems?.first(where: { $0.name == "navigate" })?.value, "yes")

        let address = "Shlomo HaMelekh 88, Tel Aviv"
        let fallback = try XCTUnwrap(URLComponents(url: TaskMapLinks.maps(query: address), resolvingAgainstBaseURL: false))
        XCTAssertEqual(fallback.queryItems?.first(where: { $0.name == "q" })?.value, address)
    }

    func testRelatedServicesAreSentAsArrayWithoutReplacingPrimaryService() async throws {
        let session = makeMockSession { request in
            guard let body = requestBodyData(request),
                  let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any],
                  let answers = json["answers_json"] as? [String: Any],
                  let relatedServices = answers["relatedServices"] as? [String] else {
                XCTFail("Expected relatedServices array in answers_json")
                return #"{"task":{"id":"task-related-1"}}"#
            }
            XCTAssertEqual(json["title"] as? String, "Faucet leak repair")
            XCTAssertEqual(answers["selectedService"] as? String, "Faucet leak repair")
            XCTAssertEqual(relatedServices, ["Toilet leak repair", "Pipe leak repair"])
            return #"{"task":{"id":"task-related-1"}}"#
        }
        let api = APIClient(
            apiBaseURL: URL(string: "https://example.test/")!,
            triageBaseURL: URL(string: "https://triage.example.test/")!,
            session: session
        )
        var draft = TaskDraft()
        draft.categoryID = "plumbing"
        draft.title = "Faucet leak repair"
        draft.answers["selectedService"] = "Faucet leak repair"
        draft.relatedServices = [
            .init(he: "תיקון נזילה באסלה", ru: "Устранение протечки унитаза", en: "Toilet leak repair"),
            .init(he: "תיקון נזילת צינור", ru: "Устранение протечки трубы", en: "Pipe leak repair"),
        ]

        let taskID = try await api.createTask(draft: draft, token: "token")
        XCTAssertEqual(taskID, "task-related-1")
    }

    func testTriageDecodesConcreteEnglishServiceForRussianInput() async throws {
        let session = makeMockSession { request in
            XCTAssertEqual(request.url?.path, "/v1/triage")
            return """
            {"category":"plumbing","service_id":"faucet-leak","service_title":"Faucet leak repair","confident":true,"urgency":"flexible","title":"Faucet leak repair","questions":["When did it start?"],"safety":null}
            """
        }
        let api = APIClient(
            apiBaseURL: URL(string: "https://example.test/")!,
            triageBaseURL: URL(string: "https://triage.example.test/")!,
            session: session
        )

        let result = try await api.triage(text: "протекает кран", locale: .en)
        XCTAssertEqual(result.category, "plumbing")
        XCTAssertEqual(result.serviceID, "faucet-leak")
        XCTAssertEqual(result.serviceTitle, "Faucet leak repair")
        XCTAssertEqual(result.title, "Faucet leak repair")
    }

    func testCloudflareTranslationUsesBoundedBatchAndTargetLocale() async throws {
        let session = makeMockSession { request in
            XCTAssertEqual(request.url?.path, "/v1/translate")
            guard let data = requestBodyData(request),
                  let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                XCTFail("Missing translation body")
                return "{}"
            }
            XCTAssertEqual(body["target_locale"] as? String, "ru")
            XCTAssertEqual(body["texts"] as? [String], ["The faucet leaks"])
            return #"{"target_locale":"ru","source_locales":["en"],"translations":["Протекает кран"]}"#
        }
        let api = APIClient(
            apiBaseURL: URL(string: "https://example.test/")!,
            triageBaseURL: URL(string: "https://triage.example.test/")!,
            session: session
        )

        let result = try await api.translate(texts: ["The faucet leaks"], targetLocale: .ru)
        XCTAssertEqual(result.targetLocale, .ru)
        XCTAssertEqual(result.sourceLocales, ["en"])
        XCTAssertEqual(result.translations, ["Протекает кран"])
    }

    func testChatMessagePostsToAssignedConversationEndpoint() async throws {
        let session = makeMockSession { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/conversations/conv-7/messages")
            return #"{"message":{"id":"msg-7","sender_id":"specialist-1","text":"Могу приехать завтра","created_at":"2026-08-29T10:00:00.000Z"}}"#
        }
        let api = APIClient(
            apiBaseURL: URL(string: "https://example.test/")!,
            triageBaseURL: URL(string: "https://triage.example.test/")!,
            session: session
        )

        let message = try await api.sendMessage(conversationID: "conv-7", text: "Могу приехать завтра", token: "token")
        XCTAssertEqual(message.id, "msg-7")
        XCTAssertEqual(message.text, "Могу приехать завтра")
    }

    func testAppPINRequiresExactlySixDigits() {
        XCTAssertTrue(AppLockService.isValidPIN("482915"))
        XCTAssertFalse(AppLockService.isValidPIN("48291"))
        XCTAssertFalse(AppLockService.isValidPIN("4829157"))
        XCTAssertFalse(AppLockService.isValidPIN("48A915"))
    }

    func testAppPINDigestUsesSalt() {
        let firstSalt = Data(repeating: 0x11, count: 32)
        let secondSalt = Data(repeating: 0x22, count: 32)
        XCTAssertEqual(
            AppLockService.digest(pin: "482915", salt: firstSalt),
            AppLockService.digest(pin: "482915", salt: firstSalt)
        )
        XCTAssertNotEqual(
            AppLockService.digest(pin: "482915", salt: firstSalt),
            AppLockService.digest(pin: "482915", salt: secondSalt)
        )
    }

    func testSpecialistPortfolioAndProfileDetailsDecodeFromProductionShape() async throws {
        let session = makeMockSession { request in
            if request.url?.path.contains("specialists/spec-1") == true {
                return """
                {"portfolio_photos":"[\\"https://cdn.example/work.webp\\"]","portfolio_albums":"[{\\"id\\":\\"boiler-1\\",\\"title\\":\\"Boiler replacement\\",\\"photos\\":[\\"https://cdn.example/boiler-1.webp\\",\\"https://cdn.example/boiler-2.webp\\"],\\"cover\\":\\"https://cdn.example/boiler-1.webp\\"}]","contact_available":true,"whatsapp_available":true,"reviews":[{"id":"r1","rating":5,"text":"Excellent","client_name":"Dana","created_at":"2026-08-01T10:00:00.000Z"}]}
                """
            }
            return """
            {"specialists":[{"id":"spec-1","name":"Dana Repairs","avatar_url":null,"categories":"[\\"plumbing\\"]","bio":"Careful work","rating":4.9,"review_count":12,"completed_jobs_count":18,"verified":1,"available_now":1,"premium":1,"city":"Haifa","portfolio_photos":"[\\"https://cdn.example/work.webp\\"]","portfolio_albums":"[{\\"id\\":\\"boiler-1\\",\\"title\\":\\"Boiler replacement\\",\\"photos\\":[\\"https://cdn.example/boiler-1.webp\\",\\"https://cdn.example/boiler-2.webp\\"],\\"cover\\":\\"https://cdn.example/boiler-1.webp\\"}]"}],"pages":1}
            """
        }
        let api = APIClient(
            apiBaseURL: URL(string: "https://example.test/")!,
            triageBaseURL: URL(string: "https://triage.example.test/")!,
            session: session
        )

        let specialists = try await api.fetchAppSpecialists()
        XCTAssertEqual(specialists.first?.portfolioURLs.first?.absoluteString, "https://cdn.example/work.webp")
        XCTAssertEqual(specialists.first?.portfolioURLs.count, 3)
        XCTAssertEqual(specialists.first?.portfolioProjects.first?.title, "Boiler replacement")
        XCTAssertEqual(specialists.first?.portfolioProjects.first?.photoURLs.count, 2)
        XCTAssertEqual(specialists.first?.portfolioProjects.first?.displayCoverURL?.absoluteString, "https://cdn.example/boiler-1.webp")

        let details = try await api.fetchSpecialistDetails(id: "spec-1")
        XCTAssertTrue(details.contactAvailable)
        XCTAssertTrue(details.whatsappAvailable)
        XCTAssertEqual(details.portfolioURLs.count, 3)
        XCTAssertEqual(details.portfolioProjects.first?.id, "boiler-1")
        XCTAssertEqual(details.portfolioProjects.first?.photoURLs.count, 2)
        XCTAssertEqual(details.reviews.first?.author, "Dana")
    }

    func testSpecialistUsesFirstProjectPhotoAsAvatarAndSortsProfilesWithMediaFirst() async throws {
        let session = makeMockSession { _ in
            """
            {
              "specialists": [
                {"id":"premium-empty","name":"No Media","avatar_url":null,"categories":["plumbing"],"rating":5,"review_count":50,"premium":1,"portfolio_photos":[],"portfolio_albums":[]},
                {"id":"standard-media","name":"Standard Media","avatar_url":null,"categories":["plumbing"],"rating":5,"review_count":100,"premium":0,"portfolio_photos":["https://cdn.example/standard.webp"],"portfolio_albums":[]},
                {"id":"premium-media","name":"Project Media","avatar_url":null,"categories":["plumbing"],"rating":0,"review_count":0,"premium":1,"portfolio_photos":[],"portfolio_albums":[{"id":"project-1","title":"Kitchen","photos":["https://cdn.example/project.webp"]}]}
              ],
              "pages": 1
            }
            """
        }
        let api = APIClient(
            apiBaseURL: URL(string: "https://example.test/")!,
            triageBaseURL: URL(string: "https://triage.example.test/")!,
            session: session
        )

        let specialists = try await api.fetchAppSpecialists()

        XCTAssertEqual(specialists.map(\.id), ["premium-media", "premium-empty", "standard-media"])
        XCTAssertEqual(specialists.first?.displayAvatarURL?.absoluteString, "https://cdn.example/project.webp")
        XCTAssertFalse(specialists[1].hasProfileMedia)
    }

    func testContactRevealKeepsRequiredCamelCasePayload() async throws {
        let session = makeMockSession { request in
            XCTAssertEqual(request.url?.path, "/analytics/specialist-profile-contact")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer client-token")
            guard let data = requestBodyData(request),
                  let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: String] else {
                XCTFail("Missing contact reveal JSON body")
                return #"{"phone":"+972501234567"}"#
            }
            XCTAssertEqual(body["specialistId"], "spec-42")
            XCTAssertEqual(body["eventType"], "phone_reveal")
            XCTAssertEqual(body["visitorId"], "visitor-7")
            XCTAssertEqual(body["path"], "/ios/specialist/spec-42")
            XCTAssertNil(body["specialist_id"])
            XCTAssertNil(body["event_type"])
            return #"{"phone":"+972501234567"}"#
        }
        let api = APIClient(
            apiBaseURL: URL(string: "https://example.test/")!,
            triageBaseURL: URL(string: "https://triage.example.test/")!,
            session: session
        )

        let phone = try await api.revealSpecialistContact(
            id: "spec-42",
            eventType: "phone_reveal",
            visitorID: "visitor-7",
            token: "client-token"
        )

        XCTAssertEqual(phone, "+972501234567")
    }

    func testProfessionalWorkspaceDecodesAuthenticatedServerDataWithoutSamples() async throws {
        let session = makeMockSession { request in
            switch request.url?.path {
            case "/specialists/me":
                return """
                {
                  "specialist": {
                    "id": "spec-real-7",
                    "categories": "[\\\"plumbing\\\"]",
                    "bio": "Real account biography",
                    "rating": 4.7,
                    "review_count": 9,
                    "verified": 1,
                    "city": "Tel Aviv",
                    "available_now": 1,
                    "premium": 1,
                    "avatar_url": "/uploads/me.webp",
                    "portfolio_photos": "[\\\"/uploads/work.webp\\\"]",
                    "portfolio_albums": "[{\\\"id\\\":\\\"bathroom-1\\\",\\\"title\\\":\\\"Bathroom renovation\\\",\\\"photos\\\":[\\\"/uploads/bathroom-before.webp\\\",\\\"/uploads/bathroom-after.webp\\\"],\\\"cover\\\":\\\"/uploads/bathroom-after.webp\\\"}]",
                    "completed_jobs_count": 14,
                    "credits_balance": 37
                  },
                  "user": {"id":"user-real-7","name":"Serhii Ziborov"}
                }
                """
            case "/specialists/me/available-tasks":
                return """
                {"tasks":[{"id":"task-live-1","title":"Live faucet repair","category_slug":"plumbing","description":"Real request","city":"Tel Aviv","client_name":"Dana","created_at":"2026-08-28T10:00:00.000Z","budget_min":300,"budget_max":500,"when_needed":"urgent","attachments":[],"answers_json":"{\\"attachments\\":[\\"/media/file/task/client/leak.webp\\"]}","location":{"latitude":32.08,"longitude":34.78,"approximate":true}}],"pages":1}
                """
            case "/billing/balance":
                return """
                {"balance":37,"transactions":[{"id":"tx-real-1","type":"purchase","amount":50,"task_id":null,"created_at":"2026-08-27T10:00:00.000Z"}]}
                """
            default:
                XCTFail("Unexpected professional endpoint: \(request.url?.path ?? "nil")")
                return "{}"
            }
        }
        let api = APIClient(
            apiBaseURL: URL(string: "https://example.test/")!,
            triageBaseURL: URL(string: "https://triage.example.test/")!,
            session: session
        )

        let profile = try await api.fetchProfessionalProfile(token: "real-token")
        XCTAssertEqual(profile.specialist.id, "spec-real-7")
        XCTAssertEqual(profile.specialist.name, "Serhii Ziborov")
        XCTAssertEqual(profile.specialist.avatarURL?.absoluteString, "https://example.test/uploads/me.webp")
        XCTAssertEqual(profile.specialist.portfolioURLs.count, 3)
        XCTAssertEqual(profile.specialist.portfolioProjects.first?.title, "Bathroom renovation")
        XCTAssertEqual(profile.specialist.portfolioProjects.first?.photoURLs.count, 2)
        XCTAssertEqual(profile.creditsBalance, 37)

        let leads = try await api.fetchProfessionalLeads(token: "real-token")
        XCTAssertEqual(leads.first?.id, "task-live-1")
        XCTAssertEqual(leads.first?.budget, "₪300–500")
        XCTAssertTrue(leads.first?.urgent == true)
        XCTAssertEqual(leads.first?.attachmentURLs.first?.absoluteString, "https://example.test/media/file/task/client/leak.webp")
        XCTAssertEqual(leads.first?.location?.latitude, 32.08)
        XCTAssertTrue(leads.first?.location?.approximate == true)

        let account = try await api.fetchCreditAccount(token: "real-token")
        XCTAssertEqual(account.balance, 37)
        XCTAssertEqual(account.transactions.first?.id, "tx-real-1")
    }

    func testSpecialistWithoutAvatarFallsBackToTheFirstPortfolioPhoto() async throws {
        // The public listing serves portfolio_photos, portfolio_albums, and
        // categories as JSON-encoded strings, which is what production returns.
        let session = makeMockSession { _ in
            #"""
            {"specialists":[
              {"id":"spec-photo","name":"Alex","avatar_url":null,"categories":"[\"tiler\"]","bio":null,
               "rating":0,"review_count":0,"completed_jobs_count":0,"verified":1,"phone_verified":0,
               "license_verified":0,"insurance_verified":0,"portfolio_verified":0,"reviews_verified":0,
               "available_now":1,"premium":1,"city":"Tel Aviv",
               "portfolio_photos":"[\"https://example.test/media/file/portfolio/a/one.jpg\",\"https://example.test/media/file/portfolio/a/two.jpg\"]",
               "portfolio_albums":"[]"},
              {"id":"spec-album","name":"Dmitriy","avatar_url":"","categories":"[\"plumbing\"]","bio":null,
               "rating":0,"review_count":0,"completed_jobs_count":0,"verified":1,"phone_verified":0,
               "license_verified":0,"insurance_verified":0,"portfolio_verified":0,"reviews_verified":0,
               "available_now":1,"premium":1,"city":"Haifa",
               "portfolio_photos":"[]",
               "portfolio_albums":"[{\"id\":\"al1\",\"title\":\"Bathroom\",\"photos\":[\"https://example.test/media/file/portfolio/b/cover.jpg\"]}]"},
              {"id":"spec-empty","name":"Anton","avatar_url":null,"categories":"[\"handyman\"]","bio":null,
               "rating":0,"review_count":0,"completed_jobs_count":0,"verified":0,"phone_verified":0,
               "license_verified":0,"insurance_verified":0,"portfolio_verified":0,"reviews_verified":0,
               "available_now":1,"premium":1,"city":"Ashdod",
               "portfolio_photos":"[]","portfolio_albums":"[]"}
            ],"pages":1}
            """#
        }
        let api = APIClient(
            apiBaseURL: URL(string: "https://example.test/")!,
            triageBaseURL: URL(string: "https://triage.example.test/")!,
            session: session
        )

        let specialists = try await api.fetchAppSpecialists()
        let byID = Dictionary(uniqueKeysWithValues: specialists.map { ($0.id, $0) })

        let photoOnly = try XCTUnwrap(byID["spec-photo"])
        XCTAssertNil(photoOnly.avatarURL)
        XCTAssertEqual(photoOnly.portfolioURLs.count, 2)
        XCTAssertEqual(
            photoOnly.displayAvatarURL?.absoluteString,
            "https://example.test/media/file/portfolio/a/one.jpg"
        )

        // An empty avatar string is not an avatar, and an album cover counts.
        let albumOnly = try XCTUnwrap(byID["spec-album"])
        XCTAssertNil(albumOnly.avatarURL)
        XCTAssertEqual(
            albumOnly.displayAvatarURL?.absoluteString,
            "https://example.test/media/file/portfolio/b/cover.jpg"
        )

        let noMedia = try XCTUnwrap(byID["spec-empty"])
        XCTAssertNil(noMedia.displayAvatarURL)
        XCTAssertFalse(noMedia.hasProfileMedia)

        // Profiles carrying media are ranked ahead of profiles without any.
        XCTAssertEqual(specialists.last?.id, "spec-empty")
    }

    func testUnverifiedProfileIsBlockedFromRespondingWithAdminContact() async throws {
        let session = makeMockSession { _ in
            #"""
            {"task":{"id":"task-1","client_id":"client-1","title":"Leak","status":"open","created_at":"2026-09-01T10:00:00.000Z"},
             "proposals":[],
             "detail":{"contact_available":false,"response_cost_credits":5,"response_available":false,
               "response_available_at":null,"response_blocked_reason":"PROFILE_NOT_VERIFIED",
               "verification_contact":{"phone_display":"+972 50-366-9369","phone_e164":"+972503669369",
                 "whatsapp_url":"https://wa.me/972503669369"}}}
            """#
        }
        let api = APIClient(
            apiBaseURL: URL(string: "https://example.test/")!,
            triageBaseURL: URL(string: "https://triage.example.test/")!,
            session: session
        )

        let task = try await api.fetchTask(id: "task-1", token: "real-token")
        let state = try XCTUnwrap(task.responseState)
        XCTAssertFalse(state.available)
        XCTAssertTrue(state.needsVerification)
        // Verification is arranged with a person, not waited out.
        XCTAssertNil(state.availableAt)
        XCTAssertEqual(state.verificationContact?.phoneDisplay, "+972 50-366-9369")
        XCTAssertEqual(state.verificationContact?.phoneE164, "+972503669369")
        XCTAssertEqual(state.verificationContact?.whatsappURL?.absoluteString, "https://wa.me/972503669369")
    }

    func testSmartSearchRedactsContactDetailsBeforeLeavingTheDevice() {
        let cases: [(String, [String])] = [
            ("Течёт кран, звоните +972 50-366-9369", ["972", "50-366"]),
            ("Кран течёт, пишите на master@example.com", ["@", "example.com"]),
            ("Смотри фото https://photos.example/leak.jpg", ["https", "photos.example"]),
            ("Протечка на Ротшильд 22, кв. 5", ["22", "5"]),
        ]
        for (input, forbidden) in cases {
            let redacted = SmartSearchPrivacy.redact(input)
            for fragment in forbidden {
                XCTAssertFalse(redacted.contains(fragment), "\(fragment) survived in: \(redacted)")
            }
            XCTAssertTrue(SmartSearchPrivacy.isClassifiable(redacted), redacted)
        }

        // What the classifier actually needs is left intact.
        let redacted = SmartSearchPrivacy.redact("Течёт кран на кухне, нужен сантехник, звоните +972501112233")
        XCTAssertTrue(redacted.contains("кран"))
        XCTAssertTrue(redacted.contains("сантехник"))
        XCTAssertFalse(redacted.contains("+972"))
    }

    func testSmartSearchWithNothingLeftToClassifyIsNotSent() {
        let redacted = SmartSearchPrivacy.redact("+972501112233 master@example.com https://example.com")
        XCTAssertFalse(SmartSearchPrivacy.isClassifiable(redacted), redacted)
    }

    func testLeftToRightValuesAreIsolatedForHebrewLayout() {
        // A phone number is almost entirely neutral characters, so in a Hebrew
        // paragraph the system moves the leading "+" to the other end. The
        // isolate says the run is one left-to-right unit.
        let phone = "+972 50-366-9369"
        let isolated = phone.ltrIsolated
        XCTAssertTrue(isolated.hasPrefix("\u{2066}"), "missing isolate start")
        XCTAssertTrue(isolated.hasSuffix("\u{2069}"), "missing isolate end")
        XCTAssertTrue(isolated.contains(phone), "the number itself must be untouched")
        // Only the two invisible marks are added; nothing is reordered.
        XCTAssertEqual(isolated.count, phone.count + 2)

        XCTAssertEqual("".ltrIsolated, "")

        // The optional form is what call sites use, and an absent or empty
        // number must stay absent rather than becoming two invisible marks.
        let missing: String? = nil
        let empty: String? = ""
        let present: String? = "+97250"
        XCTAssertNil(missing.ltrIsolated)
        XCTAssertNil(empty.ltrIsolated)
        XCTAssertEqual(present.ltrIsolated, "\u{2066}+97250\u{2069}")
    }

    func testNotificationsDecodeDestinationAndReadState() async throws {
        let session = makeMockSession { _ in
            """
            {"notifications":[{"id":"n1","kind":"task_assignment","task_id":"task-7","payload":{"specialistName":"Alex","taskTitle":"Leak"},"created_at":"2026-08-01T10:00:00.000Z","read_at":"2026-08-01T11:00:00.000Z"}]}
            """
        }
        let api = APIClient(
            apiBaseURL: URL(string: "https://example.test/")!,
            triageBaseURL: URL(string: "https://triage.example.test/")!,
            session: session
        )

        let notifications = try await api.fetchNotifications(token: "token")
        XCTAssertEqual(notifications.first?.taskID, "task-7")
        XCTAssertEqual(notifications.first?.kind, "task_assignment")
        XCTAssertTrue(notifications.first?.isRead == true)
    }

    func testBlogCatalogDecodesPublishedShapeWithoutCategoryField() async throws {
        let session = makeMockSession { _ in
            """
            {"items":[{"slug":"zamena-trub-v-staroj-kvartire-israel-2026","title_he":"החלפת צנרת","title_en":"Replacing old pipes","title_ru":"Замена старых труб","excerpt_he":"מדריך","excerpt_en":"Guide","excerpt_ru":"Гайд","cover_url":"/images/blog/pipes.webp","publishedAt":"2026-08-01T10:00:00.000Z"}]}
            """
        }
        let api = APIClient(
            apiBaseURL: URL(string: "https://example.test/")!,
            triageBaseURL: URL(string: "https://triage.example.test/")!,
            session: session
        )

        let articles = try await api.fetchBlogArticles()
        XCTAssertEqual(articles.count, 1)
        XCTAssertEqual(articles.first?.categoryID, "plumbing")
        XCTAssertEqual(articles.first?.coverURL?.pathExtension, "webp")
    }

    func testTaskDetailsDecodeOrderNumberAndLifecycleFields() async throws {
        let session = makeMockSession { request in
            XCTAssertEqual(request.url?.path, "/tasks/task-42")
            return """
            {
              "task": {
                "id": "task-42",
                "order_number": 3042,
                "title": "Faucet leak repair",
                "description": "Water drips below the handle",
                "category_id": "plumbing",
                "canonical_category_slug": "plumbing",
                "city": "Haifa",
                "address": "10 Hanassi Boulevard, Haifa",
                "when_needed": "urgent",
                "status": "open",
                "created_at": "2026-08-28T10:00:00.000Z",
                "budget_min": 250,
                "budget_max": 450
              },
              "proposals": [{"id":"proposal-1"}],
              "detail": {
                "order_number": 3042,
                "attachments": ["https://cdn.example/leak.webp"],
                "location": {"latitude":32.8031,"longitude":34.9862,"approximate":false},
                "client": {
                  "id": "client-42",
                  "name": "Dana Cohen",
                  "phone": "+972501234567",
                  "email": "dana@example.com",
                  "client_rating": 4.8,
                  "client_review_count": 12
                },
                "viewer_proposal": {"id":"proposal-1"},
                "viewer_conversation_id": "conversation-42",
                "viewer_premium": false,
                "response_cost_credits": 5,
                "response_available": true,
                "response_available_at": null,
                "response_blocked_reason": null
              }
            }
            """
        }
        let api = APIClient(
            apiBaseURL: URL(string: "https://example.test/")!,
            triageBaseURL: URL(string: "https://triage.example.test/")!,
            session: session
        )

        let task = try await api.fetchTask(id: "task-42", token: "token")
        XCTAssertEqual(task.orderNumber, 3042)
        XCTAssertEqual(task.description, "Water drips below the handle")
        XCTAssertEqual(task.address, "10 Hanassi Boulevard, Haifa")
        XCTAssertEqual(task.whenNeeded, "urgent")
        XCTAssertEqual(task.status, .proposalReceived)
        XCTAssertEqual(task.proposalCount, 1)
        XCTAssertEqual(task.attachmentURLs.first?.absoluteString, "https://cdn.example/leak.webp")
        XCTAssertEqual(task.location?.longitude, 34.9862)
        XCTAssertFalse(task.location?.approximate ?? true)
        XCTAssertEqual(task.client?.name, "Dana Cohen")
        XCTAssertEqual(task.client?.phone, "+972501234567")
        XCTAssertEqual(task.client?.email, "dana@example.com")
        XCTAssertEqual(task.client?.rating, 4.8)
        XCTAssertEqual(task.client?.reviewCount, 12)
        XCTAssertEqual(task.viewerConversationID, "conversation-42")
        XCTAssertTrue(task.responseState?.available == true)
        XCTAssertEqual(task.responseState?.costCredits, 5)
        XCTAssertTrue(task.responseState?.alreadySubmitted == true)
    }

    func testAdminProfessionalRequestsUseOwnActingSpecialistProfile() async throws {
        let session = makeMockSession { request in
            XCTAssertEqual(
                URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                    .queryItems?
                    .first(where: { $0.name == "acting_specialist_id" })?
                    .value,
                "admin-spec-1"
            )
            XCTAssertEqual(request.url?.path, "/specialists/me/available-tasks")
            return #"{"tasks":[],"pages":0}"#
        }
        let api = APIClient(
            apiBaseURL: URL(string: "https://example.test/")!,
            triageBaseURL: URL(string: "https://triage.example.test/")!,
            session: session
        )

        let leads = try await api.fetchProfessionalLeads(
            token: "admin-token",
            actingSpecialistID: "admin-spec-1"
        )
        XCTAssertTrue(leads.isEmpty)
    }

    func testProfessionalCanSubmitProposalWithOptionalMessageAndPrice() async throws {
        let session = makeMockSession { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/proposals")
            guard let data = requestBodyData(request),
                  let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                XCTFail("Missing proposal JSON body")
                return #"{"proposal":{"id":"proposal-live-1"}}"#
            }
            XCTAssertEqual(body["task_id"] as? String, "task-live-1")
            XCTAssertEqual(body["message"] as? String, "I can arrive this evening")
            XCTAssertEqual(body["price"] as? Int, 420)
            return #"{"proposal":{"id":"proposal-live-1"},"unlock_cost":5}"#
        }
        let api = APIClient(
            apiBaseURL: URL(string: "https://example.test/")!,
            triageBaseURL: URL(string: "https://triage.example.test/")!,
            session: session
        )

        let proposalID = try await api.submitProposal(
            taskID: "task-live-1",
            message: "I can arrive this evening",
            price: 420,
            token: "specialist-token"
        )
        XCTAssertEqual(proposalID, "proposal-live-1")
    }

    func testProfessionalCanAcceptWithdrawAndCompleteWorkThroughLifecycleEndpoints() async throws {
        let session = makeMockSession { request in
            let data = requestBodyData(request)
            let body = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
            switch (request.url?.path, request.httpMethod) {
            case ("/proposals/proposal-7", "PATCH"):
                let status = body?["status"] as? String
                XCTAssertTrue(["accepted", "rejected"].contains(status))
                return """
                {"proposal":{"id":"proposal-7","status":"\(status ?? "pending")"}}
                """
            case ("/tasks/task-7/complete", "PATCH"):
                XCTAssertEqual(body?["amount"] as? Int, 780)
                return #"{"task":{"id":"task-7","status":"done"}}"#
            default:
                XCTFail("Unexpected lifecycle request: \(request.httpMethod ?? "") \(request.url?.path ?? "")")
                return #"{"error":"unexpected"}"#
            }
        }
        let api = APIClient(
            apiBaseURL: URL(string: "https://example.test/")!,
            triageBaseURL: URL(string: "https://triage.example.test/")!,
            session: session
        )

        try await api.updateProposal(id: "proposal-7", status: "accepted", token: "specialist-token")
        try await api.updateProposal(id: "proposal-7", status: "rejected", token: "specialist-token")
        try await api.completeProfessionalTask(id: "task-7", amount: 780, token: "specialist-token")
    }

    @MainActor
    func testPublishingRoutesClientToActiveRequests() async {
        let session = makeMockSession { request in
            if request.httpMethod == "POST" {
                return #"{"task":{"id":"task-new-1"}}"#
            }
            return #"{"tasks":[{"id":"task-new-1","title":"Repair faucet","category_id":"plumbing","city":"Haifa","status":"open","created_at":"2026-08-29T10:00:00.000Z","proposal_count":0}]}"#
        }
        let state = AppState(api: APIClient(
            apiBaseURL: URL(string: "https://example.test/")!,
            triageBaseURL: URL(string: "https://triage.example.test/")!,
            session: session
        ))
        state.session = AuthSession(
            token: "client-token",
            user: SessionUser(id: "client-1", name: "Dana", phone: "+972500000000", role: .client, locale: .en)
        )
        state.taskDraft.categoryID = "plumbing"
        state.taskDraft.title = "Repair faucet"
        state.taskDraft.city = "Haifa"
        state.taskDraft.address = "10 Hanassi Boulevard"

        let published = await state.publishTask()
        XCTAssertTrue(published)
        XCTAssertEqual(state.clientTab, .tasks)
        XCTAssertEqual(state.clientTasks.first?.id, "task-new-1")
        state.signOut()
    }

    func testTaskCancellationUsesRealLifecycleEndpoint() async throws {
        let session = makeMockSession { request in
            XCTAssertEqual(request.httpMethod, "PATCH")
            XCTAssertEqual(request.url?.path, "/tasks/task-42/cancel")
            return #"{"task":{"id":"task-42"}}"#
        }
        let api = APIClient(
            apiBaseURL: URL(string: "https://example.test/")!,
            triageBaseURL: URL(string: "https://triage.example.test/")!,
            session: session
        )

        try await api.cancelTask(id: "task-42", token: "token")
    }

    func testLogoutAndAccountDeletionUseAuthenticatedServerContracts() async throws {
        var calls: [String] = []
        let session = makeMockSession { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer session-token")
            calls.append("\(request.httpMethod ?? "") \(request.url?.path ?? "")")
            if request.url?.path == "/auth/account" {
                guard let data = requestBodyData(request),
                      let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: String] else {
                    XCTFail("Missing account deletion confirmation")
                    return #"{"ok":true,"scheduled_for":"2026-09-30T10:00:00.000Z"}"#
                }
                XCTAssertEqual(body["confirmation"], "DELETE")
                XCTAssertEqual(body["code"], "654321")
                return #"{"ok":true,"scheduled_for":"2026-09-30T10:00:00.000Z"}"#
            }
            if request.url?.path == "/auth/account/deletion-code" {
                return #"{"ok":true,"phone_hint":"••••9369"}"#
            }
            return #"{"ok":true}"#
        }
        let api = APIClient(
            apiBaseURL: URL(string: "https://example.test/")!,
            triageBaseURL: URL(string: "https://triage.example.test/")!,
            session: session
        )

        try await api.logout(token: "session-token")
        let hint = try await api.sendAccountDeletionCode(token: "session-token")
        try await api.requestAccountDeletion(code: "654321", token: "session-token")

        XCTAssertEqual(hint, "••••9369")
        XCTAssertEqual(calls, ["POST /auth/logout", "POST /auth/account/deletion-code", "DELETE /auth/account"])
    }

    func testPersonalDetailsAndNotificationPreferencesPersistOnServer() async throws {
        let session = makeMockSession { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
            guard let data = requestBodyData(request),
                  let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                XCTFail("Missing JSON body")
                return "{}"
            }
            switch request.url?.path {
            case "/auth/me":
                XCTAssertEqual(request.httpMethod, "PATCH")
                XCTAssertEqual(body["name"] as? String, "Dana Cohen")
                XCTAssertEqual(body["preferred_city"] as? String, "Haifa")
                return #"{"user":{"id":"client-1","name":"Dana Cohen","phone":"+972501234567","role":"client","preferred_city":"Haifa"}}"#
            case "/notifications/preferences":
                XCTAssertEqual(request.httpMethod, "PATCH")
                XCTAssertEqual(body["task_updates"] as? Bool, true)
                XCTAssertEqual(body["chat_messages"] as? Bool, false)
                XCTAssertEqual(body["nearby_jobs"] as? Bool, true)
                return #"{"preferences":{"task_updates":true,"chat_messages":false,"nearby_jobs":true}}"#
            default:
                XCTFail("Unexpected persistence endpoint")
                return "{}"
            }
        }
        let api = APIClient(
            apiBaseURL: URL(string: "https://example.test/")!,
            triageBaseURL: URL(string: "https://triage.example.test/")!,
            session: session
        )

        let user = try await api.updateAccount(name: "Dana Cohen", preferredCity: "Haifa", token: "token")
        XCTAssertEqual(user.preferredCity, "Haifa")
        let preferences = try await api.updateNotificationPreferences(
            NotificationPreferences(taskUpdates: true, chatMessages: false, nearbyJobs: true),
            token: "token"
        )
        XCTAssertFalse(preferences.chatMessages)
    }

    func testTaskDetailsDecodeRichProposalAssignmentAndJobRecord() async throws {
        let session = makeMockSession { _ in
            """
            {
              "task": {
                "id":"task-complete-1","title":"Leak repair","category_id":"plumbing",
                "city":"Haifa","status":"done","created_at":"2026-08-31T10:00:00.000Z",
                "completion_amount":1450,
                "completion_requested_at":"2026-08-31T12:00:00.000Z",
                "completion_confirmed_at":"2026-08-31T13:00:00.000Z"
              },
              "proposals":[{
                "id":"proposal-1","specialist_id":"spec-1","specialist_name":"Ivan",
                "specialist_avatar_url":"/media/file/avatar/ivan.webp","specialist_rating":4.9,
                "specialist_review_count":159,"specialist_phone_verified":true,
                "specialist_license_verified":false,"price":1200,"message":"Can arrive today",
                "status":"accepted","created_at":"2026-08-31T10:30:00.000Z"
              }],
              "detail": {
                "accepted_specialist_contact": {
                  "specialist_id":"spec-1","user_id":"user-1","name":"Ivan",
                  "phone":"+972501234567","whatsapp":"+972501234567",
                  "avatar_url":"/media/file/avatar/ivan.webp"
                },
                "completion_record": {
                  "specialist_final_amount":1450,"specialist_note":"Replaced the valve",
                  "specialist_submitted_at":"2026-08-31T12:00:00.000Z",
                  "client_paid_amount":1400,"client_note":"Discount agreed",
                  "client_confirmed_at":"2026-08-31T13:00:00.000Z","expense_amount":350,
                  "media":[
                    {"kind":"specialist_after","url":"/media/file/completion/spec-after.webp?expires=1&signature=x"},
                    {"kind":"client_after","url":"/media/file/completion/client-after.webp?expires=1&signature=y"}
                  ]
                }
              }
            }
            """
        }
        let api = APIClient(
            apiBaseURL: URL(string: "https://example.test/")!,
            triageBaseURL: URL(string: "https://triage.example.test/")!,
            session: session
        )

        let task = try await api.fetchTask(id: "task-complete-1", token: "token")
        XCTAssertEqual(task.proposals.first?.specialistName, "Ivan")
        XCTAssertEqual(task.proposals.first?.price, 1200)
        XCTAssertTrue(task.proposals.first?.trust.phoneVerified == true)
        XCTAssertEqual(task.acceptedSpecialist?.phone, "+972501234567")
        XCTAssertEqual(task.completion?.specialistFinalAmount, 1450)
        XCTAssertEqual(task.completion?.clientPaidAmount, 1400)
        XCTAssertEqual(task.completion?.expenseAmount, 350)
        XCTAssertEqual(task.completion?.specialistPhotoURLs.count, 1)
        XCTAssertEqual(task.completion?.clientPhotoURLs.count, 1)
    }

    func testCompletionPayloadKeepsSpecialistAndClientAmountsSeparate() async throws {
        let requestedAt = Date(timeIntervalSince1970: 1_788_177_600)
        let session = makeMockSession { request in
            XCTAssertEqual(request.httpMethod, "PATCH")
            XCTAssertEqual(request.url?.path, "/tasks/task-1/completion/confirm")
            guard let data = requestBodyData(request),
                  let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                XCTFail("Missing completion body")
                return "{}"
            }
            XCTAssertEqual(body["client_paid_amount"] as? Int, 1400)
            XCTAssertEqual(body["client_note"] as? String, "Discount agreed")
            XCTAssertEqual(body["photo_keys"] as? [String], ["completion/client/result.jpg"])
            XCTAssertNil(body["specialist_final_amount"])
            return #"{"task":{"id":"task-1","title":"Leak repair","category_id":"plumbing","city":"Haifa","status":"done","created_at":"2026-08-31T10:00:00.000Z","completion_amount":1450,"completion_requested_at":"2026-08-31T12:00:00.000Z","completion_confirmed_at":"2026-08-31T13:00:00.000Z"}}"#
        }
        let api = APIClient(
            apiBaseURL: URL(string: "https://example.test/")!,
            triageBaseURL: URL(string: "https://triage.example.test/")!,
            session: session
        )

        let task = try await api.resolveTaskCompletion(
            id: "task-1",
            requestedAt: requestedAt,
            confirm: true,
            clientPaidAmount: 1400,
            clientNote: "Discount agreed",
            photoKeys: ["completion/client/result.jpg"],
            token: "token"
        )
        XCTAssertEqual(task.completion?.specialistFinalAmount, 1450)
    }

    func testPrivacyManifestIsBundledAndDeclaresNoTracking() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        XCTAssertEqual(plist["NSPrivacyTracking"] as? Bool, false)
        XCTAssertFalse((plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? []).isEmpty)
    }

    @MainActor
    func testUniversalLinksRouteTasksAndSpecialistsInsideTheApp() {
        let state = AppState(sessionStore: TestSessionStore())
        XCTAssertTrue(state.handleUniversalLink(URL(string: "https://kablay.co.il/ru/task/task-42")!))
        XCTAssertEqual(state.pendingNotificationDestination?.taskID, "task-42")

        XCTAssertTrue(state.handleUniversalLink(URL(string: "https://kablay.co.il/en/specialists/spec-7")!))
        XCTAssertEqual(state.pendingSpecialistDestination?.id, "spec-7")
        XCTAssertEqual(state.workspaceMode, .client)
        XCTAssertFalse(state.handleUniversalLink(URL(string: "https://example.com/en/task/task-42")!))
    }

    func testBundledMobileContractContainsEveryCriticalSchema() {
        XCTAssertEqual(MobileContract.version, "1.0.0")
        XCTAssertEqual(
            MobileContract.schemaNames,
            ["Task", "TaskDetailResponse", "Proposal", "Specialist", "Completion", "Notification", "CreditAccount", "Catalog"]
        )
        XCTAssertTrue(MobileContract.validateBundledSnapshot())
    }

    private func makeMockSession(body: @escaping (URLRequest) -> String) -> URLSession {
        makeMockSession(statusCode: 200, body: body)
    }

    private func makeMockSession(
        statusCode: Int,
        body: @escaping (URLRequest) -> String
    ) -> URLSession {
        MockURLProtocol.handler = { request in
            let data = Data(body(request).utf8)
            let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, data)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private func requestBodyData(_ request: URLRequest) -> Data? {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return nil }

    stream.open()
    defer { stream.close() }
    var data = Data()
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4_096)
    defer { buffer.deallocate() }

    while stream.hasBytesAvailable {
        let count = stream.read(buffer, maxLength: 4_096)
        if count < 0 { return nil }
        if count == 0 { break }
        data.append(buffer, count: count)
    }
    return data
}

private final class TestSessionStore: SessionStoring {
    private var session: AuthSession?

    func loadSession() -> AuthSession? { session }
    func saveSession(_ session: AuthSession) throws { self.session = session }
    func clearSession() { session = nil }
}

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw APIError.invalidResponse }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
