import SwiftUI

/// A quick-select "what do you want to focus on?" option shown at check-in. The
/// chosen focus is mandatory before take-off and carries through the session as
/// the journey's intention. Each preset has a distinct accent + icon so the
/// selector feels premium.
struct FocusPreset: Identifiable, Hashable {
    /// The English title, which is simultaneously this preset's identity (it is
    /// what `id` returns, what onboarding compares, and what
    /// `applyOnboardingSelections` persists) and its catalog key. It is
    /// therefore never replaced by a translation — `localizedTitle` is.
    let title: String
    let systemImage: String
    let accent: Color
    var id: String { title }

    /// The title to SHOW, in the language FocusGlobe is set to. For composing
    /// into a String; inside a view body use `Text(LocalizedStringKey(title))`.
    var localizedTitle: String { FocusLocalization.string(title) }

    /// The noun this focus becomes inside the results screen's goal sentence:
    /// Read → "reading", Meditate → "meditation". English keys — each language
    /// then supplies whatever part of speech ITS sentence needs, which is why
    /// French answers "lire" and German "zum Lesen".
    ///
    /// Falls back to the lowercased title so a preset added tomorrow still
    /// produces a sentence rather than an empty slot.
    var routineNounKey: String {
        switch title {
        case "Fly":      return "focus"
        case "Work":     return "work"
        case "Study":    return "study"
        case "Meditate": return "meditation"
        case "Exercise": return "exercise"
        case "Read":     return "reading"
        case "Create":   return "creative work"
        case "Reflect":  return "reflection"
        default:         return title.lowercased()
        }
    }

    static let all: [FocusPreset] = [
        FocusPreset(title: "Fly",      systemImage: "paperplane.fill",          accent: Color(hex: 0x5B6CF0)),
        FocusPreset(title: "Work",     systemImage: "briefcase.fill",           accent: Color(hex: 0x3E8EE6)),
        FocusPreset(title: "Study",    systemImage: "book.fill",                accent: Color(hex: 0xE0A23E)),
        FocusPreset(title: "Meditate", systemImage: "leaf.fill",                accent: Color(hex: 0x34C79E)),
        FocusPreset(title: "Exercise", systemImage: "figure.run",               accent: Color(hex: 0xF2795A)),
        FocusPreset(title: "Read",     systemImage: "books.vertical.fill",      accent: Color(hex: 0x9C86E8)),
        FocusPreset(title: "Create",   systemImage: "paintbrush.pointed.fill",  accent: Color(hex: 0xE8728C)),
        FocusPreset(title: "Reflect",  systemImage: "moon.stars.fill",          accent: Color(hex: 0x7E91AE)),
    ]
}
