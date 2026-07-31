import XCTest
@testable import ZoneClock

final class TimeUtilTests: XCTestCase {
    let taipei = TimeZone(identifier: "Asia/Taipei")!
    let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
    let cairo = TimeZone(identifier: "Africa/Cairo")!
    let kathmandu = TimeZone(identifier: "Asia/Kathmandu")!

    /// 2026-07-31 22:00 in Taipei (UTC+8) == 2026-07-31 14:00 UTC.
    var taipei10pm: Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = taipei
        return cal.date(from: DateComponents(year: 2026, month: 7, day: 31, hour: 22))!
    }

    func testDayOffsetBehindHome() {
        // 10 PM Friday in Taipei is 7 AM Friday in Los Angeles: same day.
        XCTAssertEqual(TimeUtil.dayOffset(of: taipei10pm, in: losAngeles, relativeTo: taipei), 0)
        // 8 AM Saturday in Taipei is 5 PM Friday in Los Angeles: -1 day.
        let saturday8am = taipei10pm.addingTimeInterval(10 * 3600)
        XCTAssertEqual(TimeUtil.dayOffset(of: saturday8am, in: losAngeles, relativeTo: taipei), -1)
    }

    func testDayOffsetAheadOfHome() {
        // 10 PM Friday in Los Angeles is 1 PM Saturday in Taipei: +1 day.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = losAngeles
        let la10pm = cal.date(from: DateComponents(year: 2026, month: 7, day: 31, hour: 22))!
        XCTAssertEqual(TimeUtil.dayOffset(of: la10pm, in: taipei, relativeTo: losAngeles), 1)
    }

    func testRelativeOffsetWholeHours() {
        // Taipei is UTC+8 year-round; LA is UTC-7 in July (DST): 15 hours apart.
        XCTAssertEqual(
            TimeUtil.relativeOffsetString(from: taipei, to: losAngeles, at: taipei10pm), "-15h")
        XCTAssertEqual(
            TimeUtil.relativeOffsetString(from: losAngeles, to: taipei, at: taipei10pm), "+15h")
        XCTAssertEqual(
            TimeUtil.relativeOffsetString(from: taipei, to: taipei, at: taipei10pm), "±0h")
    }

    func testRelativeOffsetFractionalHours() {
        // Kathmandu is UTC+5:45, Taipei UTC+8: 2h15 behind.
        XCTAssertEqual(
            TimeUtil.relativeOffsetString(from: taipei, to: kathmandu, at: taipei10pm), "-2:15")
    }

    func testTimeStringRendersInTargetZone() {
        let en = Locale(identifier: "en_US")
        // 10 PM Friday in Taipei renders as that wall time in Taipei...
        XCTAssertEqual(TimeUtil.timeString(taipei10pm, in: taipei, locale: en), "10:00\u{202F}PM")
        // ...and as 7 AM in Los Angeles, not the device-local time.
        // U+202F is the narrow no-break space ICU puts before AM/PM.
        XCTAssertEqual(TimeUtil.timeString(taipei10pm, in: losAngeles, locale: en), "7:00\u{202F}AM")
        XCTAssertEqual(TimeUtil.weekdayString(taipei10pm, in: losAngeles, locale: en), "Fri")
        // Cairo is UTC+3 in July: 5 PM.
        XCTAssertEqual(TimeUtil.timeString(taipei10pm, in: cairo, locale: en), "5:00\u{202F}PM")
    }

    func testSearchMatchesCityAndRegionPrefixes() {
        let ashland = City(
            name: "Ashland", region: "Oregon", country: "United States",
            tzID: "America/Los_Angeles", population: 20_861)
        let cairoCity = City(
            name: "Cairo", region: "Cairo", country: "Egypt",
            tzID: "Africa/Cairo", population: 9_606_916)
        let entries = [cairoCity, ashland].map {
            CityDB.Entry(city: $0, words: CityDB.fold("\($0.name) \($0.region) \($0.country)"))
        }
        XCTAssertEqual(CityDB.search("ashland or", in: entries).map(\.name), ["Ashland"])
        XCTAssertEqual(CityDB.search("cai", in: entries).map(\.name), ["Cairo"])
        XCTAssertEqual(CityDB.search("ashland texas", in: entries), [])
        // Empty query returns everything in rank order.
        XCTAssertEqual(CityDB.search("", in: entries).count, 2)
    }
}
