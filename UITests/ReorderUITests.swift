import XCTest

final class ReorderUITests: XCTestCase {
    func testDragCityLabelToReorder() {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_CITIES"] = [
            "Taipei|Taiwan|Taiwan|Asia/Taipei",
            "Boston|Massachusetts|United States|America/New_York",
            "Cairo|Cairo|Egypt|Africa/Cairo",
        ].joined(separator: ";")
        app.launch()

        let taipei = app.staticTexts["Taipei"].firstMatch
        let cairo = app.staticTexts["Cairo"].firstMatch
        XCTAssertTrue(taipei.waitForExistence(timeout: 5))
        XCTAssertTrue(cairo.exists)
        XCTAssertLessThan(taipei.frame.minY, cairo.frame.minY)

        cairo.press(forDuration: 1.0, thenDragTo: taipei)

        let reordered = NSPredicate { _, _ in
            cairo.frame.minY < taipei.frame.minY
        }
        let done = XCTNSPredicateExpectation(predicate: reordered, object: nil)
        XCTAssertEqual(
            XCTWaiter.wait(for: [done], timeout: 5), .completed,
            "Cairo should sit above Taipei after the drag"
        )
    }
}
