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

    func testDragCityLabelToReorder() {
        let app = launchSeededApp()
        let taipei = app.staticTexts["Taipei"].firstMatch
        let cairo = app.staticTexts["Cairo"].firstMatch
        XCTAssertTrue(taipei.waitForExistence(timeout: 5))
        XCTAssertTrue(cairo.exists)
        XCTAssertLessThan(taipei.frame.minY, cairo.frame.minY)

        // Short hold, then movement: must start the drag before the context
        // menu's longer stationary-press threshold would fire.
        cairo.press(forDuration: 0.4, thenDragTo: taipei)

        let reordered = NSPredicate { _, _ in
            cairo.frame.minY < taipei.frame.minY
        }
        let done = XCTNSPredicateExpectation(predicate: reordered, object: nil)
        XCTAssertEqual(
            XCTWaiter.wait(for: [done], timeout: 5), .completed,
            "Cairo should sit above Taipei after the drag"
        )
    }

    func testStationaryLongPressShowsOptionsMenu() {
        let app = launchSeededApp()
        let boston = app.staticTexts["Boston"].firstMatch
        XCTAssertTrue(boston.waitForExistence(timeout: 5))

        boston.press(forDuration: 1.2)

        XCTAssertTrue(
            app.buttons["Remove City"].waitForExistence(timeout: 3),
            "A stationary long press should open the city options menu"
        )
        XCTAssertTrue(app.buttons["Set as Home"].exists)
    }
}
