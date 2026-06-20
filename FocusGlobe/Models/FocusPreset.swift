import Foundation

/// A quick-select "what do you want to focus on?" option shown at check-in.
/// The user can pick one or type their own; the chosen text carries through the
/// session as the journey's intention.
struct FocusPreset: Identifiable, Hashable {
    let title: String
    let systemImage: String
    var id: String { title }

    static let all: [FocusPreset] = [
        FocusPreset(title: "Work",      systemImage: "briefcase.fill"),
        FocusPreset(title: "Study",     systemImage: "book.fill"),
        FocusPreset(title: "Meditate",  systemImage: "leaf.fill"),
        FocusPreset(title: "Exercise",  systemImage: "figure.run"),
        FocusPreset(title: "Read",      systemImage: "books.vertical.fill"),
        FocusPreset(title: "Deep Work", systemImage: "brain.head.profile"),
        FocusPreset(title: "Create",    systemImage: "paintbrush.pointed.fill"),
        FocusPreset(title: "Journal",   systemImage: "pencil.and.outline"),
        FocusPreset(title: "Fly",       systemImage: "paperplane.fill"),
        FocusPreset(title: "Reflect",   systemImage: "moon.stars.fill"),
    ]
}
