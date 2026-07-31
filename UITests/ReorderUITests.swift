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

    func testEditSheetSetsHomeAndRemoves() {
        let app = launchSeededApp()
        let edit = app.buttons["Edit"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()

        let sheetBoston = app.buttons.containing(.staticText, identifier: "Boston").firstMatch
        XCTAssertTrue(sheetBoston.waitForExistence(timeout: 3))
        sheetBoston.tap()
        XCTAssertTrue(
            app.staticTexts["Home"].waitForExistence(timeout: 3),
            "Tapping a city in the edit sheet should mark it as home"
        )

        let sheetCairo = app.buttons.containing(.staticText, identifier: "Cairo").firstMatch
        sheetCairo.swipeLeft()
        let delete = app.buttons["Delete"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()

        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(
            app.staticTexts["Boston"].firstMatch.waitForExistence(timeout: 3))
        XCTAssertFalse(
            app.staticTexts["Cairo"].firstMatch.exists,
            "Cairo should be gone from the board after deletion"
        )
    }
}
