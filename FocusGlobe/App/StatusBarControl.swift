import SwiftUI
#if canImport(UIKit)
import UIKit
import ObjectiveC   // class_getInstanceMethod / method_exchangeImplementations

// MARK: - Screen-scoped status-bar style (no private API)

/// FocusGlobe uses the SwiftUI `WindowGroup` lifecycle, so there is no custom
/// root `UIHostingController` to subclass, and SwiftUI still ships no public
/// per-screen status-bar modifier. `.preferredColorScheme` *does* drive the
/// status bar — but it flips the WHOLE window's trait (darkening the tab bar and
/// every other surface), which is exactly the global regression we must avoid.
///
/// Instead we consult a single shared override from the PUBLIC
/// `UIViewController.preferredStatusBarStyle` getter, installed once via the
/// Objective-C runtime (`method_exchangeImplementations` — public symbols, no
/// private API, App-Store-safe). When the override is `nil` (everywhere except
/// the Home screen) each controller returns its normal appearance-derived style,
/// so no other screen is affected. Home opts in with `.lightStatusBar()`.
enum StatusBarOverride {
    /// `nil` → follow the system (appearance-derived). Non-nil → force this style
    /// for whichever controller the system queries, so the resolved style is the
    /// same regardless of SwiftUI's (undocumented) internal controller nesting.
    static var style: UIStatusBarStyle? {
        didSet {
            guard oldValue != style else { return }
            refreshAllScenes()
        }
    }

    /// Install the getter override exactly once. Idempotent.
    static func installIfNeeded() { _ = installOnce }

    private static let installOnce: Void = {
        guard let original = class_getInstanceMethod(
                UIViewController.self, #selector(getter: UIViewController.preferredStatusBarStyle)),
              let replacement = class_getInstanceMethod(
                UIViewController.self, #selector(UIViewController.fg_preferredStatusBarStyle)) else { return }
        method_exchangeImplementations(original, replacement)
    }()

    /// Ask every live window's root controller to re-query the style, so a
    /// change animates in immediately (no flicker, no relaunch).
    private static func refreshAllScenes() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.rootViewController?.setNeedsStatusBarAppearanceUpdate()
            }
        }
    }
}

extension UIViewController {
    /// Swapped with `preferredStatusBarStyle`: returns the shared override when
    /// one is active, otherwise the original implementation (now reachable under
    /// this selector after the exchange).
    @objc func fg_preferredStatusBarStyle() -> UIStatusBarStyle {
        if let forced = StatusBarOverride.style { return forced }
        return self.fg_preferredStatusBarStyle()   // original impl (exchanged)
    }
}

// MARK: - View modifier

private struct LightStatusBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                StatusBarOverride.installIfNeeded()
                StatusBarOverride.style = .lightContent
            }
            .onDisappear {
                // Only relinquish if we're still the owner — avoids clobbering a
                // sibling screen that set its own style during a transition.
                if StatusBarOverride.style == .lightContent { StatusBarOverride.style = nil }
            }
    }
}

extension View {
    /// Force light (white) status-bar content while this screen is on-screen,
    /// in BOTH appearances, then relinquish on disappear. Used by Home, whose
    /// Sky is always dark, so black status-bar icons in Light Mode would be
    /// unreadable. Screen-scoped: no other tab is affected.
    func lightStatusBar() -> some View { modifier(LightStatusBarModifier()) }
}
#else
extension View {
    func lightStatusBar() -> some View { self }
}
#endif
