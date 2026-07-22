import SwiftUI
#if canImport(UIKit)
import UIKit

// MARK: - Screen-scoped status-bar style (supported container, no private API)

/// FocusGlobe uses the SwiftUI `WindowGroup` lifecycle, so there is no custom
/// root `UIHostingController` to subclass and SwiftUI still ships no public
/// per-screen status-bar modifier. `.preferredColorScheme` *does* drive the
/// status bar — but it flips the WHOLE window's trait (darkening the tab bar and
/// every other surface), the global regression we must avoid.
///
/// The supported fix is a **container view controller we own**. Once, at launch,
/// we slot a `StatusBarContainerController` between the window and SwiftUI's
/// hosting controller (a normal parent/child reparent — public UIKit API, no
/// `method_exchangeImplementations`, App-Store-safe). The container is the object
/// iOS queries for the status-bar style:
///
///  • When no screen has opted in (every tab except Home) it forwards to the
///    hosted SwiftUI controller via `childForStatusBarStyle`, so the bar tracks
///    the app's own appearance exactly as before — no global Dark is forced.
///  • Home opts in with `.lightStatusBar()`, which sets a `.lightContent`
///    override; the container then answers `.lightContent` itself, so Home's
///    always-dark Sky keeps white, readable icons in BOTH appearances.
///
/// Changing the override animates in immediately (`setNeedsStatusBarAppearance`),
/// and a tab change never reparents anything, so there is no flicker. AdMob,
/// Sign in with Apple and system sheets present on top of the hosted controller
/// and set their own status-bar appearance untouched.
final class StatusBarContainerController: UIViewController {

    /// The live container (weak — the window owns it). Home talks to this.
    private(set) static weak var shared: StatusBarContainerController?

    /// `nil` → follow the hosted app's appearance (default, non-Home tabs).
    /// Non-nil → force this style regardless of appearance (Home → white).
    var overrideStyle: UIStatusBarStyle? {
        didSet {
            guard oldValue != overrideStyle else { return }
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    private let hosted: UIViewController

    init(hosting hosted: UIViewController) {
        self.hosted = hosted
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Opaque neutral base so the reparent instant can never flash white; the
        // hosted view covers it edge-to-edge immediately anyway.
        view.backgroundColor = UIColor(red: 0.094, green: 0.090, blue: 0.129, alpha: 1)
        addChild(hosted)
        hosted.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosted.view)
        NSLayoutConstraint.activate([
            hosted.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosted.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosted.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosted.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        hosted.didMove(toParent: self)
    }

    // Following the app → defer to the hosted controller (its style follows the
    // window trait / chosen appearance). Overriding → answer here directly.
    override var childForStatusBarStyle: UIViewController? {
        overrideStyle == nil ? hosted : nil
    }
    override var preferredStatusBarStyle: UIStatusBarStyle {
        overrideStyle ?? hosted.preferredStatusBarStyle
    }
    // Hidden state always tracks the hosted app.
    override var childForStatusBarHidden: UIViewController? { hosted }

    /// Reparent the window's current root under a fresh container, once. Safe to
    /// call repeatedly (no-op after the first success, and while the window/root
    /// isn't ready yet). Never touches WindowGroup, scenePhase or onOpenURL.
    static func installIfNeeded(from probe: UIView) {
        guard shared == nil,
              let window = probe.window,
              let root = window.rootViewController,
              !(root is StatusBarContainerController)
        else { return }
        let container = StatusBarContainerController(hosting: root)
        shared = container
        window.rootViewController = container
    }
}

// MARK: - Installer (finds the window, reparents once)

/// A zero-size probe placed in the SwiftUI hierarchy. As soon as it is in a
/// window it installs the container, retrying for a few runloops in case the
/// window isn't attached on the very first layout pass.
struct StatusBarInstaller: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ProbeController { ProbeController() }
    func updateUIViewController(_ vc: ProbeController, context: Context) { vc.tryInstall() }

    final class ProbeController: UIViewController {
        private var attempts = 0
        override func viewDidLoad() {
            super.viewDidLoad()
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
        }
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            tryInstall()
        }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            tryInstall()
        }
        func tryInstall() {
            guard StatusBarContainerController.shared == nil, attempts < 12 else { return }
            attempts += 1
            StatusBarContainerController.installIfNeeded(from: view)
            if StatusBarContainerController.shared == nil {
                DispatchQueue.main.async { [weak self] in self?.tryInstall() }
            }
        }
    }
}

// MARK: - View modifier

private struct LightStatusBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear { StatusBarContainerController.shared?.overrideStyle = .lightContent }
            .onDisappear {
                // Only relinquish if we're still the owner — avoids clobbering a
                // sibling screen that set its own style during a transition.
                if StatusBarContainerController.shared?.overrideStyle == .lightContent {
                    StatusBarContainerController.shared?.overrideStyle = nil
                }
            }
    }
}

extension View {
    /// Force light (white) status-bar content while this screen is on-screen, in
    /// BOTH appearances, then relinquish on disappear. Used by Home, whose Sky is
    /// always dark, so black status-bar icons in Light Mode would be unreadable.
    /// Screen-scoped: no other tab is affected.
    func lightStatusBar() -> some View { modifier(LightStatusBarModifier()) }

    /// Install the status-bar container once (place near the app root). A no-op
    /// zero-size representable that reparents the window root on first layout.
    func installStatusBarContainer() -> some View {
        background(StatusBarInstaller().frame(width: 0, height: 0).accessibilityHidden(true))
    }
}
#else
extension View {
    func lightStatusBar() -> some View { self }
    func installStatusBarContainer() -> some View { self }
}
#endif
