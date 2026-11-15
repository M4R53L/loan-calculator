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

    func testDefaultLoanShowsItsPayment() {
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        // Linked to the CPI at 1.6% a year, the default when offline
        XCTAssertTrue(hero.label.contains("1,101.09"), hero.label)
        shot("1-top")
    }

    /// Tapping a field selects its number, so what is typed replaces it
    func testTypingReplacesTheRate() {
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        let cases = [("field.prime", "5.5", "5.5"), ("field.margin", "12.25", "12.25"),
                     ("field.inflation", "2.5", "2.5")]
        for (id, typed, expected) in cases {
            let field = app.textFields[id]
            scroll(to: field)
            field.tap()
            shot("rate-\(id)-selected")
            field.typeText(typed)
            XCTAssertEqual(field.value as? String, expected)
            shot("rate-\(id)-typed")
            // Close the keyboard, which can cover the next field
            app.buttons["סיום"].tap()
        }
    }

    /// Everything is on screen at once, with no scrolling: for the default
    /// loan, and for the tallest one, with grace months on top of linkage
    func testEverythingFitsOnOneScreen() {
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        let window = app.windows.firstMatch.frame
        let cost = app.descendants(matching: .any)["costSummary"]
        func assertFits(_ name: String) {
            XCTAssertTrue(cost.waitForExistence(timeout: 3))
            // Clear of the home indicator's 34 points
            XCTAssertLessThanOrEqual(cost.frame.maxY, window.maxY - 34, "\(name): cost card cut off")
            print("FIT \(name): card ends at \(cost.frame.maxY) of \(window.maxY), headline \(hero.frame)")
            XCTAssertGreaterThanOrEqual(hero.frame.minY, window.minY, "\(name): headline cut off")
            // The rates and the last payment share one row
            let figures = ["ריבית שנתית", "עלות אשראי שנתית", "תשלום אחרון"].map { label in
                app.descendants(matching: .any)
                    .matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch.frame
            }
            XCTAssertEqual(Set(figures.map(\.minY)).count, 1, "\(name): figures on more than one row")
            // And so do the parts of the cost
            let parts = ["קרן", "הצמדה"].map { label in
                app.descendants(matching: .any)
                    .matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch.frame
            }
            XCTAssertEqual(Set(parts.map(\.minY)).count, 1, "\(name): parts on more than one row")
            shot("fit-\(name)")
        }
        assertFits("default")

        app.buttons["גרייס"].tap()
        assertFits("tallest")

        // The longest last payment: the largest balloon at the highest rate
        let amount = app.textFields["field.principal"], margin = app.textFields["field.margin"]
        amount.tap()
        amount.typeText("400000")
        margin.tap()
        margin.typeText("45.25")
        app.buttons["סיום"].tap()
        app.buttons["בלון"].tap()
        assertFits("widest")
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
        app.buttons["כמה אלווה"].tap()
        XCTAssertTrue(hero.waitForExistence(timeout: 3))
        XCTAssertTrue(hero.label.contains("תוכלו ללוות"), hero.label)
        // 1,000 a month over 60 months at the default rates, linked at 1.6%
        XCTAssertTrue(hero.label.contains("45,409"), hero.label)
        XCTAssertTrue(app.staticTexts["תשלום חודשי רצוי"].exists)
        shot("4-borrow")
    }

    func testShareOffersAnImage() {
        app.buttons["שיתוף כתמונה"].tap()
        // The share sheet offers to set a contact's photo only for a picture
        let assign = app.descendants(matching: .any).matching(
            NSPredicate(format: "label IN %@", ["Assign to Contact", "שיוך לאיש קשר"])
        ).firstMatch
        XCTAssertTrue(assign.waitForExistence(timeout: 10))
        shot("9-share")
    }

    /// Typing a new amount passes through values out of range, such as 9
    /// on the way to 94,000. The headline shows --- and nothing moves.
    func testInvalidAmountExplainsItselfAndResetRecovers() {
        let field = app.textFields["field.principal"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let cost = app.descendants(matching: .any)["costSummary"]
        field.tap()
        let heroBefore = hero.frame, costBefore = cost.frame
        field.typeText("9")
        XCTAssertTrue(app.staticTexts["הסכום צריך להיות 15,000 עד 400,000 ₪"].waitForExistence(timeout: 3))
        XCTAssertTrue(hero.label.contains("אין חישוב"), hero.label)
        // Same place and height; only the width changes, as --- is narrower
        XCTAssertEqual(hero.frame.minY, heroBefore.minY)
        XCTAssertEqual(hero.frame.height, heroBefore.height)
        XCTAssertEqual(cost.frame, costBefore)
        shot("7-invalid")

        field.typeText("4000")
        XCTAssertTrue(hero.label.contains("2,070.04"), hero.label)
        XCTAssertEqual(hero.frame.minY, heroBefore.minY)
        XCTAssertEqual(cost.frame, costBefore)
        shot("7-valid-again")

        app.buttons["איפוס"].tap()
        let confirm = app.buttons["איפוס הנתונים"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        shot("8-reset")
        confirm.tap()
        XCTAssertTrue(hero.waitForExistence(timeout: 3))
        XCTAssertTrue(hero.label.contains("1,101.09"), hero.label)
    }
}
