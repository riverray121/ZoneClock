import XCTest

final class ReorderUITests: XCTestCase {
    private static let defaultCities = [
        "Taipei|Taiwan|Taiwan|Asia/Taipei",
        "Boston|Massachusetts|United States|America/New_York",
        "Cairo|Cairo|Egypt|Africa/Cairo",
    ]

    private func launchSeededApp(cities: [String] = ReorderUITests.defaultCities) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_CITIES"] = cities.joined(separator: ";")
        app.launch()
        return app
    }

    func testHoldAndDragReordersAndChangesHome() {
        let app = launchSeededApp()
        let taipei = app.staticTexts["Taipei"].firstMatch
        let cairo = app.staticTexts["Cairo"].firstMatch
        XCTAssertTrue(taipei.waitForExistence(timeout: 5))
        XCTAssertTrue(cairo.exists)
        XCTAssertLessThan(taipei.frame.minY, cairo.frame.minY)
        XCTAssertTrue(app.images["home-Taipei"].exists)

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
        XCTAssertTrue(
            app.images["home-Cairo"].waitForExistence(timeout: 3),
            "The top city should become home"
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

    func testSwipeLeftRevealsDelete() {
        let app = launchSeededApp()
        let boston = app.staticTexts["Boston"].firstMatch
        XCTAssertTrue(boston.waitForExistence(timeout: 5))

        // Start right of the name so the 90pt leftward drag stays on screen.
        let bBase = boston.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let bStart = bBase.withOffset(CGVector(dx: 55, dy: 0))
        bStart.press(forDuration: 0.05, thenDragTo: bBase.withOffset(CGVector(dx: -35, dy: 0)))
        let remove = app.buttons["swipe-delete-Boston"].firstMatch
        XCTAssertTrue(
            remove.waitForExistence(timeout: 3),
            "Swiping left should reveal the delete button"
        )
        remove.tap()

        let gone = NSPredicate { _, _ in
            !app.staticTexts["Boston"].firstMatch.exists
        }
        let done = XCTNSPredicateExpectation(predicate: gone, object: nil)
        XCTAssertEqual(
            XCTWaiter.wait(for: [done], timeout: 5), .completed,
            "Boston should be removed from the board"
        )
    }

    func testSwipeRightMakesHome() {
        let app = launchSeededApp()
        let cairo = app.staticTexts["Cairo"].firstMatch
        XCTAssertTrue(cairo.waitForExistence(timeout: 5))
        XCTAssertTrue(app.images["home-Taipei"].exists)

        let cStart = cairo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        cStart.press(forDuration: 0.05, thenDragTo: cStart.withOffset(CGVector(dx: 90, dy: 0)))
        let home = app.buttons["swipe-home-Cairo"].firstMatch
        XCTAssertTrue(
            home.waitForExistence(timeout: 3),
            "Swiping right should reveal the home button"
        )
        home.tap()

        XCTAssertTrue(
            app.images["home-Cairo"].waitForExistence(timeout: 3),
            "Cairo should move to the top and become home"
        )
        XCTAssertLessThan(
            cairo.frame.minY, app.staticTexts["Taipei"].firstMatch.frame.minY)
    }

    func testVerticalScrollWorksFromCityColumn() {
        let manyCities = [
            "Taipei|Taiwan|Taiwan|Asia/Taipei",
            "Boston|Massachusetts|United States|America/New_York",
            "Cairo|Cairo|Egypt|Africa/Cairo",
            "London|England|United Kingdom|Europe/London",
            "Sydney|New South Wales|Australia|Australia/Sydney",
            "Tokyo|Tokyo|Japan|Asia/Tokyo",
            "Paris|Ile-de-France|France|Europe/Paris",
            "Denver|Colorado|United States|America/Denver",
            "Mumbai|Maharashtra|India|Asia/Kolkata",
        ]
        let app = launchSeededApp(cities: manyCities)
        let taipei = app.staticTexts["Taipei"].firstMatch
        XCTAssertTrue(taipei.waitForExistence(timeout: 5))
        let before = taipei.frame.minY

        // A quick drag on the label column, no hold first, must scroll.
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.6))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.25))
        start.press(forDuration: 0.05, thenDragTo: end)

        let scrolled = NSPredicate { _, _ in
            !taipei.exists || taipei.frame.minY < before - 50
        }
        let done = XCTNSPredicateExpectation(predicate: scrolled, object: nil)
        XCTAssertEqual(
            XCTWaiter.wait(for: [done], timeout: 5), .completed,
            "Swiping on the city column should scroll the board"
        )
    }
}

