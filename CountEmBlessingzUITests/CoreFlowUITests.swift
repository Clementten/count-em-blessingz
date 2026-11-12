import XCTest

/// End-to-end checks on the real app. Launch flags (DEBUG builds only):
/// `-uiTesting` = empty in-memory store, first launch; `-seedDemo` = demo data, already onboarded.
final class CoreFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // The first saved blessing can ask for notification permission; answer it so tests never stall.
        addUIInterruptionMonitor(withDescription: "System alert") { alert in
            for title in ["Don’t Allow", "Don't Allow", "Allow", "OK"] where alert.buttons[title].exists {
                alert.buttons[title].tap()
                return true
            }
            return false
        }
    }

    // MARK: Helpers

    private func launch(_ arguments: [String], extra: [String] = []) {
        app.launchArguments = arguments + extra
        app.launch()
    }

    /// Anything on screen whose accessibility label contains `text`.
    private func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    private func button(containing text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    @discardableResult
    private func appears(_ element: XCUIElement, _ timeout: TimeInterval = 40, _ message: String = "",
                         file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let found = element.waitForExistence(timeout: timeout)
        XCTAssertTrue(found, "Expected \(element) to appear. \(message)\n\(found ? "" : String(app.debugDescription.prefix(2500)))", file: file, line: line)
        return element
    }

    private func tab(_ index: Int) -> XCUIElement { app.buttons["tab-\(index)"] }

    // MARK: First run

    func testFirstRunOnboardingThenAddBlessingShowsInListAndInsights() {
        launch(["-uiTesting"])

        let search = appears(app.textFields["Search countries"])
        search.tap(); search.typeText("Malaysia")
        appears(button(containing: "Malaysia")).tap()
        app.buttons["Continue"].tap()

        appears(button(containing: "Quiet Fortune")).tap()
        app.buttons["Start counting"].tap()

        appears(app.buttons["add-blessing"]).tap()
        let name = appears(app.textFields["name-field"])
        name.tap(); name.typeText("Aunt Mei")
        let amount = app.textFields["amount-field"]
        amount.tap(); amount.typeText("88")
        app.buttons["save-blessing"].tap()

        appears(button(containing: "Aunt Mei"), 40, "The new blessing should be in the Home list")
        tab(1).tap()
        appears(element(containing: "Aunt Mei"), 40, "…and in the Insights legend")
    }

    func testVibeStepHasABackButton() {
        launch(["-uiTesting"])
        appears(app.textFields["Search countries"])
        app.buttons["Continue"].tap()
        appears(button(containing: "Quiet Fortune"))
        app.buttons["Back"].tap()
        appears(app.textFields["Search countries"], 20, "Back returns to the country step")
    }

    // MARK: Tabs keep their place (the reported bug)

    func testSwitchingTabsKeepsWhereYouWere() {
        launch(["-seedDemo"])

        // Open a profile from Home, leave the tab, come back: still on the profile.
        appears(button(containing: "Aunt Mei")).tap()
        let lifetime = appears(element(containing: "Lifetime"), 20, "Profile should open")
        tab(2).tap()
        appears(element(containing: "Milestones"), 20, "Hall of Fame")
        tab(0).tap()
        XCTAssertTrue(lifetime.waitForExistence(timeout: 10) && lifetime.isHittable, "Home tab must still be on the profile")

        // Tapping the tab you are already on does not throw you back to the main screen.
        tab(0).tap()
        XCTAssertTrue(element(containing: "Lifetime").isHittable)

        // Back to Home's list; a search typed there survives a trip through another tab.
        app.navigationBars.buttons.firstMatch.tap()
        let searchField = appears(app.textFields["Search name, note or occasion"])
        searchField.tap(); searchField.typeText("Mei")
        tab(1).tap()
        appears(element(containing: "By person").exists ? element(containing: "By person") : app.staticTexts["Insights"], 20)
        tab(0).tap()
        XCTAssertEqual(appears(app.textFields["Search name, note or occasion"]).value as? String, "Mei")
    }

    // MARK: Settings

    func testChangingTheVibeRetitlesTheTabs() {
        launch(["-seedDemo", "-demoTheme", "jade"])
        appears(tab(0))
        XCTAssertTrue(tab(0).staticTexts["Blessings"].exists, "Jade & Gold calls the first tab Blessings")
        tab(3).tap()
        appears(button(containing: "The Grand Ledger")).tap()
        appears(tab(0).staticTexts["Ledger"], 20, "The Grand Ledger calls it Ledger")
    }

    func testChangingCurrencyConvertsEveryAmount() {
        launch(["-seedDemo"])
        tab(3).tap()
        appears(app.buttons["country-row"]).tap()

        let search = appears(app.textFields["Search countries"])
        search.tap(); search.typeText("United States")
        appears(button(containing: "United States")).tap()

        let rate = appears(app.textFields["rate-field"], 20, "The rate sheet appears before anything changes")
        rate.tap()
        let separator = Locale.current.decimalSeparator ?? "."
        rate.typeText("0\(separator)21")
        appears(app.buttons["Convert 15 blessings"]).tap()

        appears(element(containing: "Converted at 1 MYR"), 20, "A toast confirms the rate")
        XCTAssertTrue(app.buttons["country-row"].label.contains("USD"))
        tab(0).tap()
        appears(element(containing: "USD").exists ? element(containing: "USD") : element(containing: "$"), 20)
        let total = app.descendants(matching: .any).matching(NSPredicate(format: "label MATCHES '.*2.?052.*'")).firstMatch
        appears(total, 20, "9,776 × 0.21 = 2,052.96")
    }

    // MARK: Sharing and import

    func testHomeHasAShareButtonThatOpensTheShareSheet() {
        launch(["-seedDemo"])
        appears(app.buttons["share-all"]).tap()
        let sheet = app.otherElements["ActivityListView"]
        let copy = app.buttons["Copy"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 20) || copy.waitForExistence(timeout: 5), "The system share sheet should open")
    }

    func testImportReviewSelectionChangesTheFooterAndCancelChangesNothing() {
        launch(["-seedDemo", "-demoImport"])
        appears(element(containing: "Review import"))
        appears(button(containing: "Import 4 of 6"), 20, "Four entries are ticked by default")

        button(containing: "Merry Christmas").tap()                       // untick one
        appears(button(containing: "Import 3 of 6"), 10)

        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["add-blessing"].waitForExistence(timeout: 20), "Back on Home")
        XCTAssertTrue(element(containing: "9,776").exists || element(containing: "9.776").exists, "The pot is unchanged")
    }

    // MARK: Accessibility

    func testLargestTextSizeKeepsTheMainControlsReachable() {
        launch(["-seedDemo"], extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        appears(tab(0))
        for index in 0..<4 { XCTAssertTrue(tab(index).isHittable, "Tab \(index) must stay tappable at the largest text size") }
        XCTAssertTrue(app.buttons["add-blessing"].isHittable)
        XCTAssertTrue(tab(3).staticTexts.firstMatch.label.count > 0)
    }
}
