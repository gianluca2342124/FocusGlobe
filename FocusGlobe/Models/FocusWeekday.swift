import SwiftUI

/// A day of the week the pilot plans to fly.
///
/// Stored as ISO-8601 weekday numbers — 1 = Monday … 7 = Sunday. That is the
/// whole reason this type exists rather than an array of strings: "Monday" is a
/// localized label, and persisting one would break the moment FocusGlobe ships
/// a second language or a pilot changes their region. The number is stable
/// across locales, calendars and releases; the label is derived at read time
/// from the device's own calendar, so it translates on the day the app does.
enum FocusWeekday: Int, CaseIterable, Identifiable, Codable, Comparable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    var id: Int { rawValue }

    static func < (a: FocusWeekday, b: FocusWeekday) -> Bool { a.rawValue < b.rawValue }

    /// `Calendar`'s symbol arrays are indexed from Sunday (index 0), while these
    /// cases are numbered from Monday (1). `rawValue % 7` is that shift: Monday
    /// 1 → 1, Saturday 6 → 6, Sunday 7 → 0.
    private var calendarSymbolIndex: Int { rawValue % 7 }

    /// The catalog key for the narrow-button label. English, fixed, and never
    /// persisted — `rawValue` is the identity.
    var shortLabelKey: String {
        ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][rawValue - 1]
    }

    /// The narrow-button label, in the language FocusGlobe is set to.
    ///
    /// TRANSLATED, NOT DERIVED. This used to read
    /// `Calendar.current.shortWeekdaySymbols`, which is wrong twice over: it
    /// answers in the DEVICE language, so a Spanish app on an English phone
    /// printed Mon Tue Wed; and even asked in the right language it returns
    /// CLDR's abbreviated forms, which are not what belongs on seven buttons
    /// 46 points wide. Portuguese abbreviates to D S T Q Q S S — three
    /// ambiguous pairs — and Spanish to lun/mar/mié where L M X J V S D is what
    /// a Spanish speaker expects to tap.
    ///
    /// So the compact set is DESIGNED per language and lives in the catalog,
    /// where it can be read and argued with, next to the comment that says what
    /// it is for.
    var shortLabel: String { FocusLocalization.string(shortLabelKey) }

    /// The spoken name, for VoiceOver. `Calendar` is exactly right here — it
    /// has all eleven languages' weekday names and there is nothing to design —
    /// as long as it is asked in the SELECTED language rather than the phone's.
    var fullLabel: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = FocusLocalization.currentLocale
        let symbols = calendar.weekdaySymbols
        guard symbols.count == 7 else { return shortLabel }
        return symbols[calendarSymbolIndex]
    }

    /// The schedule onboarding opens on.
    ///
    /// Mon · Wed · Fri — three days, which is exactly the three-flights-a-week
    /// rhythm the results screen has always assumed, so the default answer and
    /// the default plan agree instead of quietly contradicting each other.
    static let defaultSchedule: [FocusWeekday] = [.monday, .wednesday, .friday]

    /// Decode a persisted schedule, dropping anything outside 1…7 and any
    /// duplicate, so a corrupt array can never produce a bad flights-per-week.
    static func schedule(from raw: [Int]?) -> [FocusWeekday] {
        guard let raw else { return [] }
        return Array(Set(raw.compactMap(FocusWeekday.init(rawValue:)))).sorted()
    }

    static func rawValues(_ days: [FocusWeekday]) -> [Int] {
        days.sorted().map(\.rawValue)
    }

    /// "L · X · V" — the results screen's Rhythm value, in the selected
    /// language. A composed String rather than a view, which is why it resolves
    /// through `FocusLocalization` instead of `LocalizedStringKey`.
    static func label(_ days: [FocusWeekday], separator: String = " · ") -> String {
        days.sorted().map(\.shortLabel).joined(separator: separator)
    }
}

// MARK: - The weekday selector

/// One control, two homes: the first-run "Which days do you want to focus?"
/// screen and the results screen's Rhythm editor. Building it once is what
/// guarantees the two can never disagree about what a schedule is or how it is
/// picked — the editor is the same question, asked again.
///
/// At least one day always stays selected. The last remaining day refuses to
/// deselect rather than the CTA quietly disabling itself, so the pilot is never
/// left looking at a dead button wondering what they did.
struct WeekdayPicker: View {
    @Binding var selection: [FocusWeekday]
    var onChange: () -> Void = {}

    var body: some View {
        HStack(spacing: 6) {
            ForEach(FocusWeekday.allCases) { day in
                let isOn = selection.contains(day)
                Button {
                    toggle(day)
                } label: {
                    // The KEY, not the resolved string: a view redraws when the
                    // environment locale changes, and the language capsule on
                    // the Welcome screen can change it while this control is
                    // already on screen in the results editor.
                    Text(LocalizedStringKey(day.shortLabelKey))
                        .font(.system(size: 13.5, weight: isOn ? .bold : .semibold))
                        .foregroundStyle(isOn ? Color(hex: 0x14120E) : .white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isOn ? Color(hex: 0xF4EFE4) : .white.opacity(0.07))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(isOn ? .clear : .white.opacity(0.13), lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(SoftPressStyle())
                .accessibilityLabel(day.fullLabel)
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func toggle(_ day: FocusWeekday) {
        var next = selection
        if let i = next.firstIndex(of: day) {
            // Never empty: a plan with no days has no rhythm to describe and
            // would make the chart's target zero.
            guard next.count > 1 else { return }
            next.remove(at: i)
        } else {
            next.append(day)
        }
        selection = next.sorted()
        onChange()
    }
}
