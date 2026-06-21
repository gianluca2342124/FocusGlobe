import SwiftUI

/// A quick-select "what do you want to focus on?" option shown at check-in. The
/// chosen focus is mandatory before take-off and carries through the session as
/// the journey's intention. Each preset has a distinct accent + icon so the
/// selector feels premium.
struct FocusPreset: Identifiable, Hashable {
    let title: String
    let systemImage: String
    let accent: Color
    var id: String { title }

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
