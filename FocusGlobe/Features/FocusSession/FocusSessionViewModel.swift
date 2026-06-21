import Combine
import SwiftUI

/// Drives the Focus Session screen. Owns the timer engine and translates
/// elapsed time into everything the UI and the (provider-independent) map need:
/// progress, journey phase, remaining time/distance and the vehicle's
/// interpolated position. It never references a map SDK.
@MainActor
final class FocusSessionViewModel: ObservableObject {
    let origin: JourneyOrigin
    let route: Route
    let intention: String?

    let timer: SessionTimerService

    @Published var pureMode: Bool = false
    @Published var mapStyle: MapDisplayStyle = .graphite
    /// Camera behaviour the user can toggle in-session (follow vs. full route).
    @Published var cameraMode: JourneyCameraMode = .follow
    /// A gentle 3D tilt of the follow camera (where Google supports it).
    @Published var tilted = false
    /// `true` once the user pans the map, until they tap Recenter.
    @Published private(set) var followInterrupted = false
    @Published private(set) var isPaused = false
    @Published var showCancelConfirm = false
    @Published private(set) var didLand = false
    @Published private(set) var landingSummary: LandingSummary?

    @Published private(set) var progress: Double = 0

    /// One-shot token bumped to ask the map to (re)apply the camera now.
    private(set) var cameraToken = 0

    /// The real journey span: the user's live origin → the destination.
    let journeyDistanceKm: Double

    private weak var appModel: AppModel?
    private var cancellable: AnyCancellable?
    private var started = false
    private var resumeAfterCancelDismiss = false

    init(journey: Journey) {
        self.origin = journey.origin
        self.route = journey.route
        self.intention = journey.intention
        self.timer = SessionTimerService(total: journey.route.duration)
        self.journeyDistanceKm = GeoMath.distanceKm(from: journey.origin.coordinate,
                                                    to: journey.route.destination)
    }

    // MARK: - Lifecycle

    func attach(appModel: AppModel) {
        guard self.appModel == nil else { return }
        self.appModel = appModel
        pureMode = appModel.settings.pureModeDefault
        // Always begin the flight on the premium dark style, regardless of the
        // saved style or the app's Light/Dark appearance — the map must never go
        // bright/white in flight. The user can still switch via the in-session menu.
        mapStyle = appModel.settings.mapStyle.isDark ? appModel.settings.mapStyle : .graphite
    }

    func setMapStyle(_ style: MapDisplayStyle) {
        mapStyle = style
        appModel?.haptics.tap()
    }

    // MARK: - Camera controls

    /// Re-engage following and snap the camera back to the balloon.
    func recenter() {
        cameraMode = .follow
        followInterrupted = false
        cameraToken &+= 1
        appModel?.haptics.tap()
    }

    /// Pull back to frame the whole journey (origin → destination).
    func showFullRoute() {
        cameraMode = .overview
        followInterrupted = false
        cameraToken &+= 1
        appModel?.haptics.tap()
    }

    /// Toggle a gentle 3D tilt on the follow camera.
    func toggleTilt() {
        tilted.toggle()
        cameraToken &+= 1
        appModel?.haptics.tap()
    }

    /// Called by the map when the user pans by hand — stop following until they
    /// tap Recenter, FocusFlight-style.
    func userInteractedWithMap() {
        guard cameraMode == .follow, !followInterrupted else { return }
        followInterrupted = true
    }

    /// Whether a "Recenter" affordance should be offered.
    var showsRecenter: Bool { cameraMode == .overview || followInterrupted }

    func startIfNeeded() {
        guard !started, let appModel else { return }
        started = true

        cancellable = timer.$elapsed
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.progress = self.timer.progress
            }
        timer.onFinish = { [weak self] in self?.land() }

        appModel.analytics.log(.journeyStarted, ["route": route.id, "minutes": route.durationMinutes])
        appModel.haptics.takeoff()
        appModel.sound.playAmbient(named: route.ambientSoundName)
        timer.start()
    }

    func tearDown() {
        cancellable?.cancel()
        if !didLand { timer.stop() }
        appModel?.sound.stop()
    }

    /// Call when the scene becomes active so a backgrounded session catches up.
    func refresh() { timer.refresh() }

    // MARK: - Derived display values

    var phase: JourneyPhase { JourneyPhase(progress: progress) }

    /// A calm, FocusGlobe-flavoured status for the top pill.
    var statusLabel: String {
        switch phase {
        case .boarding, .takingOff: return "Taking off"
        case .cruising:             return "Drifting"
        case .approaching:          return "Landing soon"
        case .landing:              return "Landing"
        }
    }

    var remainingSeconds: Int { max(0, Int(timer.remaining.rounded(.up))) }
    var remainingTimeText: String { Formatters.countdown(remainingSeconds) }

    /// Coarse minutes label for the big "Time Remaining" readout (e.g. "25 min").
    var remainingMinutesText: String {
        let m = Int((Double(remainingSeconds) / 60).rounded(.up))
        return "\(max(0, m)) min"
    }

    var remainingDistanceKm: Double { journeyDistanceKm * (1 - progress) }
    var remainingDistanceText: String { Formatters.distance(km: remainingDistanceKm) }

    var progressPercentText: String { "\(Int((progress * 100).rounded()))%" }

    private var vehicleCoordinate: GeoCoordinate {
        GeoMath.interpolate(from: origin.coordinate, to: route.destination, fraction: progress)
    }

    var mapData: JourneyMapData {
        JourneyMapData(
            origin: origin.coordinate,
            destination: route.destination,
            vehicle: vehicleCoordinate,
            progress: progress,
            bearingDegrees: GeoMath.bearingDegrees(from: origin.coordinate, to: route.destination),
            mood: route.mood,
            theme: route.colorTheme,
            followsVehicle: true,
            isMoving: !isPaused && timer.isRunning,
            style: mapStyle,
            cameraMode: cameraMode,
            tilted: tilted,
            cameraToken: cameraToken
        )
    }

    // MARK: - Controls

    func togglePause() { isPaused ? resume() : pause() }

    private func pause() {
        guard !isPaused, !didLand else { return }
        isPaused = true
        timer.pause()
        appModel?.sound.pause()
        appModel?.haptics.pause()
        appModel?.analytics.log(.journeyPaused, ["route": route.id])
    }

    private func resume() {
        guard isPaused, !didLand else { return }
        isPaused = false
        timer.resume()
        appModel?.sound.resume()
        appModel?.haptics.resume()
        appModel?.analytics.log(.journeyResumed, ["route": route.id])
    }

    func togglePureMode() {
        pureMode.toggle()
        appModel?.haptics.tap()
    }

    func requestCancel() {
        if !isPaused {
            resumeAfterCancelDismiss = true
            pause()
        } else {
            resumeAfterCancelDismiss = false
        }
        showCancelConfirm = true
    }

    func dismissCancel() {
        showCancelConfirm = false
        if resumeAfterCancelDismiss { resume() }
    }

    /// Records the cancellation. The caller dismisses the cover afterwards.
    func confirmCancel() {
        showCancelConfirm = false
        timer.stop()
        appModel?.sound.stop()
        appModel?.cancelJourney(origin: origin, route: route,
                                focusedSeconds: Int(timer.elapsed.rounded()),
                                intention: intention)
    }

    // MARK: - Landing

    private func land() {
        guard !didLand, let appModel else { return }
        appModel.sound.stop()
        appModel.haptics.landing()
        let summary = appModel.completeJourney(
            origin: origin,
            route: route,
            focusedSeconds: Int(timer.total.rounded()),
            intention: intention
        )
        landingSummary = summary
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            didLand = true
        }
    }
}
