import Combine
import Foundation
import Network

/// FocusGlobe's one connectivity monitor.
///
/// ## Why this exists
///
/// `FocusOnlineModel.availability` already has a `.networkUnavailable` case, but
/// it is REACTIVE: it is only reached after a Supabase request has already
/// failed and been categorised as a network error. That is the right thing for
/// reporting what went wrong, and the wrong thing for deciding whether to try —
/// a pilot in Airplane Mode pressing Continue got a silent `return`, because
/// nothing had failed yet so nothing knew they were offline.
///
/// This answers the other question: is there a usable path RIGHT NOW, before we
/// commit the pilot to a flow that cannot work.
///
/// ## Three states, not two
///
/// `NWPathMonitor` does not report synchronously — there is a window at launch
/// where nothing is known. Collapsing that into "offline" would block a
/// perfectly connected pilot for the first fraction of a second after opening
/// the app, so `unknown` is its own state and is treated as PERMISSIVE
/// everywhere: only `isDefinitelyOffline` gates anything, and it is true solely
/// when the monitor has affirmatively reported an unsatisfied path.
///
/// Server-side failures are NOT this type's business. A reachable network with a
/// paused Supabase project stays `online` here and continues to be reported by
/// `OnlineState` in the existing friendly way.
@MainActor
final class FocusConnectivity: ObservableObject {

    enum Reachability: Equatable {
        /// The monitor has not reported yet. Never treated as offline.
        case unknown
        /// A usable path exists.
        case online
        /// The monitor affirmatively reports no usable path.
        case offline
    }

    @Published private(set) var reachability: Reachability = .unknown

    /// The ONE gate any caller should use. False while `unknown`, on purpose.
    var isDefinitelyOffline: Bool { reachability == .offline }

    /// The single line shown when an Online action is attempted without a
    /// connection. Deliberately about the FEATURE, not about the stack — no
    /// backend name, no error code, no "something went wrong".
    static let offlineMessage = "Internet connection required for Online flights."

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.focusglobe.connectivity", qos: .utility)
    private var started = false

    /// Start once, at launch. Idempotent — a second call is a no-op rather than
    /// a second monitor, which is the whole reason this is owned by `AppModel`
    /// and not created inside a view.
    func start() {
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = { [weak self] path in
            let next: Reachability = (path.status == .satisfied) ? .online : .offline
            Task { @MainActor [weak self] in
                guard let self, self.reachability != next else { return }
                self.reachability = next
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        // One monitor for the app's lifetime; cancelled if it is ever torn down
        // so no path-watching outlives the object.
        monitor.cancel()
    }
}
