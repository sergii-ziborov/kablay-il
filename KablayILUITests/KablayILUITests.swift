import CoreLocation
import XCTest

final class KablayILUITests: XCTestCase {
    @MainActor
    func testAppStoreScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.staticTexts["KABLAY"].waitForExistence(timeout: 5))
        keepScreenshot(app, named: "01-kablay-catalog")

        let field = app.textFields["For example: water under the sink"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("faucet is leaking under the handle")
        let dismiss = app.buttons["Dismiss keyboard"]
        if dismiss.waitForExistence(timeout: 3) { dismiss.tap() }
        app.buttons["Smart search"].tap()
        acceptSmartSearchConsentIfNeeded(app)
        XCTAssertTrue(app.staticTexts["We found the right service"].waitForExistence(timeout: 10))
        keepScreenshot(app, named: "02-kablay-smart-search")

        app.buttons["Continue to request"].tap()
        XCTAssertTrue(app.navigationBars["New request"].waitForExistence(timeout: 5))
        keepScreenshot(app, named: "03-kablay-request")

        app.tabBars.buttons["Catalog"].tap()
        let specialists = app.staticTexts["Recommended specialists"]
        for _ in 0..<6 where !specialists.exists { app.swipeUp() }
        XCTAssertTrue(specialists.waitForExistence(timeout: 5))
        let ivan = app.staticTexts["Ivan Kamenca"].firstMatch
        XCTAssertTrue(ivan.waitForExistence(timeout: 10))
        ivan.tap()
        XCTAssertTrue(app.navigationBars["Ivan Kamenca"].waitForExistence(timeout: 10))
        keepScreenshot(app, named: "04-kablay-specialist")
    }

    @MainActor
    func testRussianCatalogServiceOpensPrefilledRequest() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launch()

        XCTAssertTrue(app.staticTexts["KABLAY"].waitForExistence(timeout: 5))

        let plumbing = app.staticTexts["Сантехник"].firstMatch
        XCTAssertTrue(plumbing.waitForExistence(timeout: 5))
        plumbing.tap()

        XCTAssertTrue(app.navigationBars["Сантехник"].waitForExistence(timeout: 5))
        let service = app.staticTexts["Протечка из трубы"].firstMatch
        XCTAssertTrue(service.waitForExistence(timeout: 5))
        service.tap()

        XCTAssertTrue(app.navigationBars["Новая заявка"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Протечка из трубы"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Заявка"].isSelected)
    }

    @MainActor
    func testSpecialistCardsFitCompactScreen() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launch()

        let sectionTitle = app.staticTexts["Проверенные мастера"]
        for _ in 0..<6 where !sectionTitle.exists {
            app.swipeUp()
        }
        XCTAssertTrue(sectionTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Ivan Kamenca"].waitForExistence(timeout: 10))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Compact specialist cards on iPhone SE"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testRequestValidationAndLocationTools() throws {
        let device = XCUIDevice.shared
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .location)
        device.location = XCUILocation(location: CLLocation(
            latitude: 32.0853,
            longitude: 34.7818
        ))
        defer { device.location = nil }

        addUIInterruptionMonitor(withDescription: "Location permission") { alert in
            for title in ["Allow While Using App", "Allow Once", "Разрешить при использовании приложения"] {
                let button = alert.buttons[title]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }
        app.launchArguments = ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launch()

        let plumbing = app.staticTexts["Сантехник"].firstMatch
        XCTAssertTrue(plumbing.waitForExistence(timeout: 5))
        plumbing.tap()
        let service = app.staticTexts["Протечка из трубы"].firstMatch
        XCTAssertTrue(service.waitForExistence(timeout: 5))
        service.tap()

        let continueButton = app.buttons["Продолжить"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.tap()

        XCTAssertTrue(app.textFields["Город"].waitForExistence(timeout: 5))
        let currentLocation = app.buttons["Определить моё место"]
        XCTAssertTrue(currentLocation.exists)
        let map = app.otherElements["task-location-map"]
        XCTAssertTrue(map.exists)

        // A regular tap first brings the map fully on screen and verifies that
        // MapKit forwards a manual pin selection to the request draft.
        map.tap()
        let manualPointSelected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value BEGINSWITH %@", "selected|"),
            object: map
        )
        XCTAssertEqual(XCTWaiter.wait(for: [manualPointSelected], timeout: 5), .completed)
        let manualCoordinate = map.value as? String

        currentLocation.tap()
        // Trigger the interruption monitor if iOS presents the first-use
        // location prompt outside the application process.
        app.tap()
        let currentPointSelected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "selected|32.085300,34.781800"),
            object: map
        )
        XCTAssertEqual(XCTWaiter.wait(for: [currentPointSelected], timeout: 12), .completed)
        let detectedCoordinate = map.value as? String
        XCTAssertNotEqual(detectedCoordinate, manualCoordinate)
    }

    @MainActor
    func testEnglishSmartSearchSelectsFaucetServiceAndDismissesKeyboard() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let field = app.textFields["For example: water under the sink"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("протекает кран")

        let dismiss = app.buttons["Dismiss keyboard"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 3))
        dismiss.tap()
        XCTAssertFalse(dismiss.exists)

        let search = app.buttons["Smart search"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        acceptSmartSearchConsentIfNeeded(app)
        XCTAssertTrue(app.staticTexts["We found the right service"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Faucet leak repair"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Plumbing"].firstMatch.exists)
        app.buttons["Continue to request"].tap()
        XCTAssertTrue(app.tabBars.buttons["Request"].isSelected)
        XCTAssertTrue(app.navigationBars["New request"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Find the exact service"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Find with smart search"].exists)
        XCTAssertTrue(app.staticTexts["Faucet leak repair"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Related services"].waitForExistence(timeout: 5))

        let pipe = app.buttons["Leak from pipe"].firstMatch
        let faucet = app.buttons["Leak from faucet / mixer"].firstMatch
        XCTAssertTrue(pipe.waitForExistence(timeout: 5))
        pipe.tap()
        XCTAssertEqual(pipe.value as? String, "selected")
        XCTAssertTrue(faucet.waitForExistence(timeout: 3))
        faucet.tap()
        XCTAssertEqual(faucet.value as? String, "selected")
        for _ in 0..<3 where !app.staticTexts["Faucet leak repair"].firstMatch.exists {
            app.swipeDown()
        }
        XCTAssertTrue(app.staticTexts["Faucet leak repair"].firstMatch.exists)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Related services are multi-select supplements"
        attachment.lifetime = .keepAlways
        add(attachment)

        for _ in 0..<3 where !app.staticTexts["Additional details"].exists {
            app.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["Additional details"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testRealSpecialistPortfolioAndContactsLoad() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launch()

        let specialists = app.staticTexts["Проверенные мастера"]
        for _ in 0..<6 where !specialists.exists { app.swipeUp() }
        XCTAssertTrue(specialists.waitForExistence(timeout: 5))
        let specialist = app.staticTexts["Ivan Kamenca"].firstMatch
        XCTAssertTrue(specialist.waitForExistence(timeout: 10))
        specialist.tap()

        XCTAssertTrue(app.buttons["Показать телефон"].waitForExistence(timeout: 10) || app.buttons["Открыть WhatsApp"].exists)

        let galleryTitle = app.staticTexts["Галерея проектов"]
        for _ in 0..<8 where !galleryTitle.exists { app.swipeUp() }
        XCTAssertTrue(galleryTitle.waitForExistence(timeout: 10))

        let project = app.buttons["Замена ремонт бойлера"].firstMatch
        XCTAssertTrue(project.waitForExistence(timeout: 10))
        project.tap()
        XCTAssertTrue(app.navigationBars["Замена ремонт бойлера"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["project-photo-0"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testGuidesLoadSeparateNativeCatalog() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        app.tabBars.buttons["Guides"].tap()
        XCTAssertTrue(app.navigationBars["Guides & blog"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Plumbing guide"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Articles unavailable"].exists)
    }

    /// Screenshots for the iPad listing.
    ///
    /// The iPhone flow leans on Smart Search, which needs a network round trip
    /// and a keyboard-dismiss button that the iPad layout does not draw. This
    /// walks the catalog instead, so the four shots are deterministic.
    @MainActor
    func testIPadAppStoreScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.staticTexts["KABLAY"].waitForExistence(timeout: 10))
        keepScreenshot(app, named: "ipad-01-catalog")

        app.buttons["Guides"].firstMatch.tap()
        sleep(4)
        keepScreenshot(app, named: "ipad-02-guides")

        app.buttons["Request"].firstMatch.tap()
        sleep(3)
        keepScreenshot(app, named: "ipad-03-request")

        app.buttons["Catalog"].firstMatch.tap()
        let specialists = app.staticTexts["Recommended specialists"]
        for _ in 0..<6 where !specialists.exists { app.swipeUp() }
        let ivan = app.staticTexts["Ivan Kamenca"].firstMatch
        if ivan.waitForExistence(timeout: 10) {
            // The name sits inside a card, so it reports as not hittable.
            ivan.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            sleep(4)
        }
        keepScreenshot(app, named: "ipad-04-specialist")
    }

    /// Captures the same public surfaces in the two other App Store locales.
    /// Set KABLAY_SCREENSHOT_LOCALE to ru or he at test time. These images do
    /// not include an account, customer address, chat, or private task.
    @MainActor
    func testLocalizedAppStoreScreenshots() throws {
        guard let language = ProcessInfo.processInfo.environment["KABLAY_SCREENSHOT_LOCALE"] else {
            throw XCTSkip("Set KABLAY_SCREENSHOT_LOCALE to ru or he")
        }
        let labels: (catalog: String, guides: String, request: String, plumbing: String)
        switch language {
        case "ru":
            labels = ("Каталог", "Гайды", "Заявка", "Сантехник")
        case "he":
            labels = ("קטלוג", "מדריכים", "בקשה", "אינסטלטור")
        default:
            throw XCTSkip("Set KABLAY_SCREENSHOT_LOCALE to ru or he")
        }

        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", language == "he" ? "he_IL" : "ru_RU"]
        app.launch()

        XCTAssertTrue(app.staticTexts["KABLAY"].waitForExistence(timeout: 10))
        sleep(12) // Let first-boot simulator banners leave the screen.
        keepScreenshot(app, named: "\(language)-01-catalog")

        app.buttons[labels.guides].firstMatch.tap()
        sleep(4)
        keepScreenshot(app, named: "\(language)-02-guides")

        app.buttons[labels.request].firstMatch.tap()
        sleep(3)
        keepScreenshot(app, named: "\(language)-03-request")

        app.buttons[labels.catalog].firstMatch.tap()
        if ProcessInfo.processInfo.environment["KABLAY_SCREENSHOT_DEVICE"] == "ipad" {
            let ivan = app.staticTexts["Ivan Kamenca"].firstMatch
            XCTAssertTrue(ivan.waitForExistence(timeout: 10))
            ivan.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(app.navigationBars["Ivan Kamenca"].waitForExistence(timeout: 10))
            keepScreenshot(app, named: "\(language)-04-specialist")
            return
        }
        let plumbing = app.staticTexts[labels.plumbing].firstMatch
        XCTAssertTrue(plumbing.waitForExistence(timeout: 10))
        plumbing.tap()
        XCTAssertTrue(app.navigationBars[labels.plumbing].waitForExistence(timeout: 10))
        keepScreenshot(app, named: "\(language)-04-plumbing")
    }

    @MainActor
    func testPhoneLoginDoesNotDropDigits() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        app.tabBars.buttons["Account"].tap()
        app.buttons["Sign in by phone"].tap()

        let field = app.textFields["050-000-0000"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("0501234567")
        XCTAssertEqual(String((field.value as? String ?? "").filter(\.isNumber)), "0501234567")
        XCTAssertTrue(app.buttons["Get code"].isEnabled)
    }

    /// Private App Review evidence for the actual StoreKit purchase screens.
    /// Credentials are supplied at test time and never stored in this project.
    @MainActor
    func testAppReviewPurchaseScreenshots() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let phone = environment["KABLAY_REVIEW_PHONE"],
              let code = environment["KABLAY_REVIEW_OTP"] else {
            throw XCTSkip("App Review credentials were not supplied")
        }

        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        if app.staticTexts["Welcome back"].waitForExistence(timeout: 3) {
            for digit in "123456" { app.buttons[String(digit)].tap() }
        }

        let signIn = app.buttons["Sign in by phone"]
        if app.tabBars.buttons["Account"].exists {
            for _ in 0..<4 {
                app.tabBars.buttons["Account"].tap()
                if signIn.waitForExistence(timeout: 5) { break }
            }
            XCTAssertTrue(signIn.exists, "The Account tab must show the phone sign-in action")
            if signIn.exists {
                signIn.tap()
                let digits = phone.filter(\.isNumber)
                let localPhone = digits.hasPrefix("972") ? "0" + String(digits.dropFirst(3)) : digits
                let field = app.textFields["050-000-0000"]
                XCTAssertTrue(field.waitForExistence(timeout: 5))
                field.tap()
                field.typeText(String(localPhone))
                if app.buttons["Done"].exists { app.buttons["Done"].tap() }
                app.buttons["Get code"].tap()

                let codeField = app.textFields["123456"]
                XCTAssertTrue(codeField.waitForExistence(timeout: 15))
                codeField.tap()
                codeField.typeText(code)
                if app.buttons["Done"].exists { app.buttons["Done"].tap() }
                app.buttons["Sign in"].tap()
            }
        }

        if app.staticTexts["Protect your account"].waitForExistence(timeout: 5) {
            for digit in "123456" { app.buttons[String(digit)].tap() }
            app.buttons["Continue"].tap()
            for digit in "123456" { app.buttons[String(digit)].tap() }
            let faceID = app.switches["Unlock with Face ID"]
            if faceID.exists { faceID.tap() }
            app.buttons["Save PIN"].tap()
        }

        let profile = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profile.waitForExistence(timeout: 20))
        profile.tap()
        let credits = app.staticTexts["Credits"].firstMatch
        XCTAssertTrue(credits.waitForExistence(timeout: 10))
        credits.tap()
        XCTAssertTrue(app.navigationBars["Credits"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Top up credits"].waitForExistence(timeout: 20))
        keepScreenshot(app, named: "review-credits")

        app.navigationBars["Credits"].buttons.element(boundBy: 0).tap()
        let premium = app.staticTexts["KABLAY Premium"].firstMatch
        XCTAssertTrue(premium.waitForExistence(timeout: 10))
        premium.tap()
        XCTAssertTrue(app.navigationBars["Premium"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Auto-renews every month"].waitForExistence(timeout: 20))
        keepScreenshot(app, named: "review-premium-monthly")
    }

    private func acceptSmartSearchConsentIfNeeded(_ app: XCUIApplication) {
        let consent = app.buttons["Agree and continue"]
        if consent.waitForExistence(timeout: 3) {
            XCTAssertTrue(app.staticTexts["Smart Search and AI"].exists)
            consent.tap()
        }
    }

    private func keepScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
