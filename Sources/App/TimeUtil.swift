import Foundation

enum TimeUtil {
    static func calendar(_ tz: TimeZone) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal
    }

    /// Calendar-day difference between the local date in `tz` and the local date
    /// in `home` for the same instant. +1 means `tz` is already on the next day.
    static func dayOffset(of instant: Date, in tz: TimeZone, relativeTo home: TimeZone) -> Int {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let target = calendar(tz).dateComponents([.year, .month, .day], from: instant)
        let base = calendar(home).dateComponents([.year, .month, .day], from: instant)
        guard let t = utc.date(from: target), let b = utc.date(from: base) else { return 0 }
        return utc.dateComponents([.day], from: b, to: t).day ?? 0
    }

    /// Offset of `tz` relative to `home` at `instant`, e.g. "+15h", "-9:30".
    static func relativeOffsetString(from home: TimeZone, to tz: TimeZone, at instant: Date) -> String {
        let minutes = (tz.secondsFromGMT(for: instant) - home.secondsFromGMT(for: instant)) / 60
        if minutes == 0 { return "±0h" }
        let sign = minutes < 0 ? "-" : "+"
        let h = abs(minutes) / 60
        let m = abs(minutes) % 60
        return m == 0 ? "\(sign)\(h)h" : "\(sign)\(h):\(String(format: "%02d", m))"
    }

    /// Whether the user's locale uses 12-hour time.
    static let usesAMPM: Bool = {
        let format = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? ""
        return format.contains("a")
    }()

    // DateFormatter honors an explicit timeZone; Date.FormatStyle's timeZone
    // is ignored when rendered through SwiftUI Text, so all zone-sensitive
    // strings go through these cached formatters.
    private static var formatters: [String: DateFormatter] = [:]

    private static func formatter(template: String, tz: TimeZone, locale: Locale) -> DateFormatter {
        let key = "\(template)|\(tz.identifier)|\(locale.identifier)"
        if let cached = formatters[key] { return cached }
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = tz
        f.setLocalizedDateFormatFromTemplate(template)
        formatters[key] = f
        return f
    }

    static func timeString(_ date: Date, in tz: TimeZone, locale: Locale = .autoupdatingCurrent) -> String {
        formatter(template: "jmm", tz: tz, locale: locale).string(from: date)
    }

    static func weekdayString(_ date: Date, in tz: TimeZone, locale: Locale = .autoupdatingCurrent) -> String {
        formatter(template: "EEE", tz: tz, locale: locale).string(from: date)
    }

    static func monthDayString(_ date: Date, in tz: TimeZone, locale: Locale = .autoupdatingCurrent) -> String {
        formatter(template: "MMMd", tz: tz, locale: locale).string(from: date)
    }

    static func fullDateString(_ date: Date, in tz: TimeZone, locale: Locale = .autoupdatingCurrent) -> String {
        formatter(template: "EEEMMMd", tz: tz, locale: locale).string(from: date)
    }
}
