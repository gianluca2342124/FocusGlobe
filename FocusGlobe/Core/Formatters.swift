import Foundation

/// Centralised, locale-aware formatting helpers. Keeping these in one place
/// keeps every screen visually consistent and easy to localise later.
enum Formatters {

    // MARK: - Time

    /// A countdown clock. `MM:SS` under an hour, `H:MM:SS` for longer journeys.
    static func countdown(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let hours = s / 3600
        let minutes = (s % 3600) / 60
        let secs = s % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    /// A **live** flight clock that visibly ticks every second: `MM:SS` under an
    /// hour ("24:59"), then compact `1h 12m` for longer flights. Used for the
    /// active-flight readouts so the value is never seen frozen on whole minutes.
    static func flightClock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        if s < 3600 { return String(format: "%d:%02d", s / 60, s % 60) }
        return FocusLocalization.string("%lldh %02lldm", s / 3600, (s % 3600) / 60)
    }

    /// Remaining time, human first: "1h 12m" → "33 min" → "59s". Rounds minutes
    /// **up** so a fresh 25-minute flight reads "25 min", and the final minute
    /// counts down live in seconds.
    static func flightTimeRemaining(_ seconds: Int) -> String {
        let s = max(0, seconds)
        if s >= 3600 { return FocusLocalization.string("%lldh %02lldm", s / 3600, (s % 3600) / 60) }
        if s >= 60 { return "\((s + 59) / 60) min" }
        return "\(s)s"
    }

    /// Elapsed time, human first: "45s" → "12 min" → "1h 12m". Rounds minutes
    /// **down**, and the opening minute counts up live in seconds.
    static func flightTimeElapsed(_ seconds: Int) -> String {
        let s = max(0, seconds)
        if s >= 3600 { return FocusLocalization.string("%lldh %02lldm", s / 3600, (s % 3600) / 60) }
        if s >= 60 { return "\(s / 60) min" }
        return "\(s)s"
    }

    /// Flight distance, calm and whole: "41 km" (grouped beyond thousands);
    /// one decimal only while under a single kilometre ("0.4 km").
    static func flightDistanceKm(_ km: Double) -> String {
        let v = max(0, km)
        if v < 1 { return FocusLocalization.string("%.1f km", v) }
        let n = NSNumber(value: v.rounded())
        return (grouping.string(from: n) ?? "\(Int(v))") + " km"
    }

    /// A friendly duration label, e.g. "5 min", "1h", "1h 30m", "12h".
    static func durationLabel(minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) min" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    /// Longer, spoken-style duration used on passes & summaries.
    static func longDurationLabel(minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) minutes" }
        let h = minutes / 60
        let m = minutes % 60
        let hourWord = h == 1 ? "hour" : "hours"
        if m == 0 { return "\(h) \(hourWord)" }
        return "\(h) \(hourWord) \(m) min"
    }

    // MARK: - Distance & miles

    private static let grouping: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    /// Distance in kilometres, e.g. "1,240 km". Shows one decimal under 10 km.
    static func distance(km: Double) -> String {
        if km < 10 {
            return FocusLocalization.string("%.1f km", km)
        }
        let n = NSNumber(value: km.rounded())
        return (grouping.string(from: n) ?? "\(Int(km))") + " km"
    }

    /// Live in-flight distance. One decimal under 100 km so the value visibly
    /// moves with every timer tick ("73.8 km"); grouped whole km beyond.
    static func flightKm(_ km: Double) -> String {
        if km < 100 {
            return FocusLocalization.string("%.1f km", max(0, km))
        }
        let n = NSNumber(value: km.rounded())
        return (grouping.string(from: n) ?? "\(Int(km))") + " km"
    }

    /// Focus miles, grouped, e.g. "12,480".
    static func miles(_ value: Int) -> String {
        grouping.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    // MARK: - Dates

    private static let mediumDate: DateFormatter = {
        let f = DateFormatter()
        // Without this the styles resolve against the DEVICE language, so a
        // pilot running FocusGlobe in German on an English phone saw English
        // month names in an otherwise German logbook.
        f.locale = FocusLocalization.currentLocale
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    static func dateTime(_ date: Date) -> String {
        mediumDate.string(from: date)
    }

    /// A contextual greeting based on the local time of day.
    ///
    /// Uses the device's time zone by default; pass a `timeZone` to greet by the
    /// origin city's local time once city time-zones are available. Ranges:
    /// 05:00–11:59 morning · 12:00–16:59 afternoon · 17:00–21:59 evening ·
    /// 22:00–04:59 night.
    static func greeting(at date: Date = Date(), timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default:      return "Good night"
        }
    }
}
