import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension View {
    /// Keeps the display awake (disables the system idle timer) while `active` is
    /// true AND this view is on-screen, and restores normal auto-lock the moment
    /// the view disappears, `active` flips false, or the app leaves the
    /// foreground. This is intentionally scoped — it NEVER disables auto-lock
    /// globally; only an active focus journey applies it, and returning Home tears
    /// it down. iOS / Mac Catalyst honour `isIdleTimerDisabled`; other platforms
    /// are a no-op.
    func keepScreenAwake(_ active: Bool) -> some View {
        modifier(ScreenAwakeModifier(active: active))
    }
}

private struct ScreenAwakeModifier: ViewModifier {
    let active: Bool
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onAppear { apply(active && scenePhase == .active) }
            .onDisappear { apply(false) }
            .onChange(of: active) { _, now in apply(now && scenePhase == .active) }
            .onChange(of: scenePhase) { _, phase in
                // Re-assert on return to the foreground; relax when leaving it, so
                // no assertion is ever leaked while the app is backgrounded.
                apply(active && phase == .active)
            }
    }

    @MainActor private func apply(_ on: Bool) {
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = on
        #endif
    }
}
