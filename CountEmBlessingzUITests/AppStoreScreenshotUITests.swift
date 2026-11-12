import XCTest

/// Produces the App Store screenshots (iPhone 6.9": 1320 x 2868) from the real app with demo data.
/// Skipped in normal runs. Run it with:
///   TEST_RUNNER_SCREENSHOT_DIR=/some/folder xcodebuild test -scheme CountEmBlessingzUI \
///     -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:CountEmBlessingzUITests/AppStoreScreenshotUITests
/// (see docs/app-store/screenshots.md).
final class AppStoreScreenshotUITests: XCTestCase {
    private var app: XCUIApplication!
    private var outputDirectory: String!

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard let directory = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else {
            throw XCTSkip("Set TEST_RUNNER_SCREENSHOT_DIR to generate screenshots")
        }
        outputDirectory = directory
    }

    private func launch(theme: String, extra: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = ["-seedDemo", "-demoFresh", "-demoTheme", theme] + extra
        app.launch()
    }

    private func save(_ name: String, theme: String) throws {
        let directory = "\(outputDirectory!)/\(theme)"
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        try app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(directory)/\(name).png"))
    }

    private func settle(_ seconds: UInt32 = 3) { sleep(seconds) }

    private func shoot(theme: String) throws {
        launch(theme: theme)
        XCTAssertTrue(app.buttons["tab-0"].waitForExistence(timeout: 60))
        XCTAssertTrue(app.buttons["share-all"].waitForExistence(timeout: 30), "Home should be fully loaded")
        settle()
        try save("01-home", theme: theme)

        app.buttons["tab-1"].tap(); settle()
        try save("02-insights", theme: theme)

        app.buttons["tab-2"].tap(); settle()
        try save("03-hall-of-fame", theme: theme)

        app.buttons["tab-3"].tap(); settle()
        try save("05-vibes", theme: theme)

        app.buttons["tab-0"].tap()
        app.buttons["add-blessing"].tap()
        let name = app.textFields["name-field"]
        XCTAssertTrue(name.waitForExistence(timeout: 20))
        name.tap(); name.typeText("Aunt Mei")
        let amount = app.textFields["amount-field"]
        amount.tap(); amount.typeText("888")
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Chinese New Year'")).firstMatch.tap()
        if app.keyboards.count > 0, app.buttons["Done"].exists { app.buttons["Done"].tap() }   // close the keyboard for a clean shot
        settle()
        try save("04-add-blessing", theme: theme)
        app.terminate()

        launch(theme: theme, extra: ["-demoImport"])
        // Some themes upper-case their titles, so match without regard to case.
        let title = app.staticTexts.matching(NSPredicate(format: "label ==[c] 'Review import'")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 60))
        settle()
        try save("06-import-review", theme: theme)
    }

    func testJade() throws { try shoot(theme: "jade") }
    func testGrand() throws { try shoot(theme: "grand") }
    func testQuiet() throws { try shoot(theme: "quiet") }
}
