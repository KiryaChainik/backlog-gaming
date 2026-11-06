//
//  DateFormatting.swift
//  Backlog_Gaming
//

import Foundation

enum AppDateFormatting {
    static let locale = Locale(identifier: "ru_RU")
    private static let calendar = Calendar(identifier: .gregorian)

    /// Индексы 1…12. Единый вид в UI: ровно три буквы, без склонений (`мар`, а не `марта`).
    private static let monthTriples = ["", "янв", "фев", "мар", "апр", "май", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"]

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.calendar = calendar
        f.dateFormat = format
        return f
    }

    private static let timeFormatter = makeFormatter("HH:mm")
    private static let weekdayFormatter = makeFormatter("EEEE")

    private static func ymd(_ date: Date) -> (y: Int, m: Int, d: Int) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 0, c.month ?? 1, c.day ?? 0)
    }

    private static func monthToken(_ month: Int) -> String {
        guard month >= 1, month <= 12 else { return "" }
        return monthTriples[month]
    }

    static func dayMonth(_ date: Date) -> String {
        let (_, m, d) = ymd(date)
        return "\(d) \(monthToken(m))"
    }

    static func weekdayDayMonth(_ date: Date) -> String {
        let wd = weekdayFormatter.string(from: date)
        return "\(wd), \(dayMonth(date))"
    }

    static func monthYear(_ date: Date) -> String {
        let (y, m, _) = ymd(date)
        return "\(monthToken(m)) \(y)"
    }

    static func abbreviated(_ date: Date, includesTime: Bool = false) -> String {
        let (y, m, d) = ymd(date)
        let base = "\(d) \(monthToken(m)) \(y)"
        return includesTime ? "\(base), \(timeFormatter.string(from: date))" : base
    }

    static func timeOnly(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }
}
