import XCTest

final class ReorderUITests: XCTestCase {
    private func launchSeededApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_CITIES"] = [
            "Taipei|Taiwan|Taiwan|Asia/Taipei",
            "Boston|Massachusetts|United States|America/New_York",
            "Cairo|Cairo|Egypt|Africa/Cairo",
        ].joined(separator: ";")
        app.launch()
        return app
    }

    func testHoldAndDragReordersRows() {
        let app = launchSeededApp()
        let taipei = app.staticTexts["Taipei"].firstMatch
        let cairo = app.staticTexts["Cairo"].firstMatch
        XCTAssertTrue(taipei.waitForExistence(timeout: 5))
        XCTAssertTrue(cairo.exists)
        XCTAssertLessThan(taipei.frame.minY, cairo.frame.minY)

        cairo.press(
            forDuration: 0.6, thenDragTo: taipei,
            withVelocity: .slow, thenHoldForDuration: 0.5
        )

        let reordered = NSPredicate { _, _ in
            cairo.frame.minY < taipei.frame.minY
        }
        let done = XCTNSPredicateExpectation(predicate: reordered, object: nil)
        XCTAssertEqual(
            XCTWaiter.wait(for: [done], timeout: 5), .completed,
            "Cairo should sit above Taipei after the drag"
        )
    }

    func testHomeRowIsDraggableToo() {
        let app = launchSeededApp()
        let taipei = app.staticTexts["Taipei"].firstMatch
        let boston = app.staticTexts["Boston"].firstMatch
        XCTAssertTrue(taipei.waitForExistence(timeout: 5))
        XCTAssertLessThan(taipei.frame.minY, boston.frame.minY)

        taipei.press(forDuration: 0.6, thenDragTo: boston)

        let reordered = NSPredicate { _, _ in
            boston.frame.minY < taipei.frame.minY
        }
        let done = XCTNSPredicateExpectation(predicate: reordered, object: nil)
        XCTAssertEqual(
            XCTWaiter.wait(for: [done], timeout: 5), .completed,
            "The home row should drag below Boston"
        )
    }

    func testOptionsMenuOpensFromButton() {
        let app = launchSeededApp()
        let options = app.buttons["options-Boston"].firstMatch
        XCTAssertTrue(options.waitForExistence(timeout: 5))

        options.tap()

        XCTAssertTrue(
            app.buttons["Remove City"].waitForExistence(timeout: 3),
            "The options button should open the city menu"
        )
        XCTAssertTrue(app.buttons["Set as Home"].exists)
    }
}
