import Foundation

/// Money, quantities and dates the way the clinic reads them (PRD §7: numbers first, estimates labelled).
nonisolated struct ClinicFormatters: Sendable {
    let currency: String
    let timeZone: TimeZone
    let locale: Locale
    let clock: Clock

    init(currency: String, timeZone: TimeZone, locale: Locale = .current, clock: Clock = SystemClock()) {
        self.currency = currency
        self.timeZone = timeZone
        self.locale = locale
        self.clock = clock
    }

    /// "$1,234.50"
    func money(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: currency).locale(locale))
    }

    /// "$12,420": the value tiles show no cents (f6).
    func wholeMoney(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: currency).precision(.fractionLength(0)).locale(locale))
    }

    /// "54 cartridges", "1 box", "2.5 bags"
    func quantity(_ amount: Decimal, unit: String) -> String {
        "\(number(amount)) \(unit)"
    }

    /// "54", "2.5": at most two decimals, no trailing zeros.
    func number(_ amount: Decimal) -> String {
        amount.formatted(.number.precision(.fractionLength(0...2)).locale(locale))
    }

    /// "Dec 1, 2026"
    func date(_ date: Date) -> String {
        date.formatted(style.month(.abbreviated).day().year())
    }

    /// "Oct 1 · 3:14 PM"
    func dateTime(_ date: Date) -> String {
        let day = date.formatted(style.month(.abbreviated).day())
        let time = date.formatted(style.hour().minute())
        return "\(day) · \(time)"
    }

    /// "Dec 1, 2026" for a Postgres `date`.
    func date(_ day: CalendarDay) -> String {
        date(day.start(in: timeZone))
    }

    /// "Thursday, October 2" for the Home eyebrow (f6).
    func weekday(_ date: Date) -> String {
        date.formatted(style.weekday(.wide).month(.wide).day())
    }

    /// "December 2026" for an expiry month (a Postgres `date` on the first of the month).
    func month(_ expiryMonth: CalendarDay) -> String {
        expiryMonth.start(in: timeZone).formatted(style.month(.wide).year())
    }

    /// An empty date style in the clinic's locale and time zone; callers add the fields.
    private var style: Date.FormatStyle {
        Date.FormatStyle(date: nil, time: nil, locale: locale, timeZone: timeZone)
    }

    /// "in 12 days", "today", "Expired" (PRD §6.4 expiry card).
    func daysLeft(_ days: Int) -> String {
        switch days {
        case ..<0: "Expired"
        case 0: "today"
        case 1: "in 1 day"
        default: "in \(days) days"
        }
    }

    /// Whole days from today (clinic time zone) to the last day of the expiry month, like the
    /// database's `days_to_expiry`.
    func daysToExpiry(month expiryMonth: CalendarDay) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let today = calendar.startOfDay(for: clock.now)
        let lastDay = expiryMonth.lastDayOfMonth.start(in: timeZone)
        return calendar.dateComponents([.day], from: today, to: lastDay).day ?? 0
    }
}
