import XCTest

/// Drives the real app: the screens and controls unit tests cannot reach.
@MainActor
final class LoanCalculatorUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
    }

    /// Saves a screenshot when a folder is passed in TEST_RUNNER_SHOTS.
    private func shot(_ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["SHOTS"] else { return }
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
    }

    private func scroll(to element: XCUIElement, maxSwipes: Int = 12) {
        var swipes = 0
        while !element.exists || !element.isHittable {
            guard swipes < maxSwipes else { return XCTFail("\(element) not reached") }
            app.swipeUp(velocity: .slow)
            swipes += 1
        }
    }

    private var hero: XCUIElement { app.descendants(matching: .any)["hero"] }
    private var bar: XCUIElement { app.descendants(matching: .any)["paymentBar"] }

    func testDefaultLoanShowsItsPayment() {
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        XCTAssertTrue(hero.label.contains("1,099.63"), hero.label)
        XCTAssertFalse(bar.exists)
        shot("1-top")
    }

    func testPaymentBarAppearsOnceHeadlineScrollsAway() {
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(bar.waitForExistence(timeout: 3))
        XCTAssertTrue(bar.label.contains("1,099.63"), bar.label)
        shot("2-scrolled")

        app.swipeDown()
        app.swipeDown()
        app.swipeDown()
        XCTAssertTrue(bar.waitForNonExistence(timeout: 3))
    }

    func testEveryTrackGivesAResult() {
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        let spitzer = hero.label
        scroll(to: app.buttons["בלון"])
        app.buttons["בלון"].tap()
        app.buttons["גרייס"].tap()
        shot("3-grace")
        app.swipeDown()
        app.swipeDown()
        app.swipeDown()
        XCTAssertTrue(hero.waitForExistence(timeout: 3))
        XCTAssertNotEqual(hero.label, spitzer)
        XCTAssertTrue(hero.label.contains("גרייס"), hero.label)
    }

    func testBorrowModeAnswersWithALoanAmount() {
        app.buttons["כמה אוכל ללוות"].tap()
        XCTAssertTrue(hero.waitForExistence(timeout: 3))
        XCTAssertTrue(hero.label.contains("תוכלו ללוות"), hero.label)
        // 1,000 a month over 60 months at the default rates
        XCTAssertTrue(hero.label.contains("45,469"), hero.label)
        XCTAssertTrue(app.staticTexts["תשלום חודשי רצוי"].exists)
        shot("4-borrow")
    }

    func testScheduleListsEveryMonth() {
        let link = app.buttons["לוח סילוקין"]
        scroll(to: link)
        shot("5-costs")
        link.tap()
        XCTAssertTrue(app.navigationBars["לוח סילוקין"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["חודש 1"].exists)
        shot("6-schedule")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(link.waitForExistence(timeout: 3))
    }

    func testInvalidAmountExplainsItselfAndResetRecovers() {
        let field = app.textFields["field.principal"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("9")
        XCTAssertTrue(app.staticTexts["הסכום צריך להיות 15,000 עד 400,000 ₪"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["noResult"].exists)
        shot("7-invalid")

        app.buttons["איפוס"].tap()
        let confirm = app.buttons["איפוס הנתונים"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        shot("8-reset")
        confirm.tap()
        XCTAssertTrue(hero.waitForExistence(timeout: 3))
        XCTAssertTrue(hero.label.contains("1,099.63"), hero.label)
    }

    func testSavedScenarioShowsTheDifference() {
        let save = app.buttons["שמירה להשוואה"]
        scroll(to: save)
        save.tap()
        // The same loan compared with itself differs by nothing. A row's label
        // and value read as one element, so match on part of the label.
        let unchanged = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "ללא שינוי"))
        XCTAssertTrue(unchanged.firstMatch.waitForExistence(timeout: 3))
        let remove = app.buttons["הסרת התרחיש השמור"]
        scroll(to: remove)
        shot("9-compare")
        remove.tap()
        XCTAssertTrue(save.waitForExistence(timeout: 3))
    }
}
