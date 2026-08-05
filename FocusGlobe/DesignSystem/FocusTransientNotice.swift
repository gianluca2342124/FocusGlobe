import SwiftUI

/// FocusGlobe's brief, self-dismissing notice.
///
/// The visual language is not new: it is the same capsule the flight already
/// uses for its invite/social pills — `.ultraThinMaterial`, a hairline white
/// border, 13 pt semibold white — so a message on the pre-flight step reads as
/// the same app speaking. No new accent colour is introduced.
///
/// This is for a fact the pilot needs for about two seconds ("Online needs a
/// connection"), never for an error that needs a decision. Anything requiring a
/// choice belongs in a real dialog.
struct FocusNoticePill: View {
    let message: String

    var body: some View {
        Text(verbatim: message)
            .font(.system(size: 13, weight: .semibold, design: .default))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().fill(Color.black.opacity(0.18)).clipShape(Capsule()))
            .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
    }
}

/// The state a screen keeps for its notice.
///
/// It carries a generation counter as well as the text, and that is the point:
/// tapping an unavailable action five times raises the SAME sentence five
/// times, and a plain `String?` would compare equal each time, so the dismiss
/// timer would never restart and the notice would vanish mid-jab. Bumping the
/// generation makes each raise a distinct value, which restarts the timer while
/// still rendering exactly one pill — refreshed, never stacked.
struct FocusNoticeState: Equatable {
    private(set) var text: String?
    private var generation = 0

    init() {}

    mutating func show(_ message: String) {
        text = message
        generation &+= 1
    }

    mutating func clear() {
        text = nil
    }
}

private struct FocusTransientNoticeModifier: ViewModifier {
    @Binding var notice: FocusNoticeState
    let alignment: Alignment
    let inset: CGFloat
    /// Long enough to read one short sentence, short enough not to linger.
    let duration: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dismissTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: alignment) {
                if let text = notice.text {
                    FocusNoticePill(message: text)
                        .padding(alignment == .top ? .top : .bottom, inset)
                        .padding(.horizontal, AppSpacing.screen)
                        // A live region so VoiceOver speaks it without the pilot
                        // having to go looking for a pill that is about to leave.
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(text)
                        .allowsHitTesting(false)
                        .transition(reduceMotion
                                    ? .opacity
                                    : .opacity.combined(with: .offset(y: alignment == .top ? -8 : 8)))
                }
            }
            .animation(reduceMotion ? .none : AppMotion.content, value: notice)
            .onChange(of: notice) { _, current in
                dismissTask?.cancel()
                guard let text = current.text else { dismissTask = nil; return }
                AccessibilityNotification.Announcement(text).post()
                dismissTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                    guard !Task.isCancelled else { return }
                    notice.clear()
                }
            }
            // Nothing may outlive the screen that raised it.
            .onDisappear {
                dismissTask?.cancel()
                dismissTask = nil
            }
    }
}

extension View {
    /// Show `notice` as a brief pill, auto-dismissing after `duration`.
    ///
    /// Raising the same message again refreshes it rather than adding a second
    /// one. `inset` positions it near the control that raised it — this is
    /// deliberately not a screen-corner toast.
    func focusTransientNotice(
        _ notice: Binding<FocusNoticeState>,
        alignment: Alignment = .bottom,
        inset: CGFloat = 96,
        duration: Double = 2.6
    ) -> some View {
        modifier(FocusTransientNoticeModifier(notice: notice,
                                              alignment: alignment,
                                              inset: inset,
                                              duration: duration))
    }
}
