import Combine
import SwiftUI

/// Drives the Focus Session screen. Owns the timer engine and translates
/// elapsed time into everything the UI and the (provider-independent) map need:
/// progress, journey phase, remaining time/distance and the vehicle's
/// interpolated position. It never references a map SDK.
@MainActor
final class FocusSessionViewModel: ObservableObject {
    let route: Route
    let intention: String?

    let timer: SessionTimerService

    @Published var pureMode: Bool = false
    @Published var mapStyle: MapDisplayStyle = .night
    @Published private(set) var isPaused = false
    @Published var showCancelConfirm = false
    @Published private(set) var didLand = false
    @Published private(set) var landingSummary: LandingSummary?

    @Published private(set) var progress: Double = 0

    private weak var appModel: AppModel?
    private var cancellable: AnyCancellable?
    private var started = false
    private var resumeAfterCancelDismiss = false

    init(journey: Journey) {
        self.route = journey.route
        self.intention = journey.intention
        self.timer = SessionTimerService(total: journey.route.duration)
    }

    // MARK: - Lifecycle

    func attach(appModel: AppModel) {
        guard self.appModel == nil else { return }
        self.appModel = appModel
        pureMode = appModel.settings.pureModeDefault
        mapStyle = appModel.settings.mapStyle
    }

    func setMapStyle(_ style: MapDisplayStyle) {
        mapStyle = style
        appModel?.haptics.tap()
    }

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

    var remainingSeconds: Int { max(0, Int(timer.remaining.rounded(.up))) }
    var remainingTimeText: String { Formatters.countdown(remainingSeconds) }

    /// Coarse minutes label for the big "Time Remaining" readout (e.g. "25 min").
    var remainingMinutesText: String {
        let m = Int((Double(remainingSeconds) / 60).rounded(.up))
        return "\(max(0, m)) min"
    }

    var remainingDistanceKm: Double { route.approximateDistanceKm * (1 - progress) }
    var remainingDistanceText: String { Formatters.distance(km: remainingDistanceKm) }

    var progressPercentText: String { "\(Int((progress * 100).rounded()))%" }

    private var vehicleCoordinate: GeoCoordinate {
        GeoMath.interpolate(from: route.origin, to: route.destination, fraction: progress)
    }

    var mapData: JourneyMapData {
        JourneyMapData(
            origin: route.origin,
            destination: route.destination,
            vehicle: vehicleCoordinate,
            progress: progress,
            bearingDegrees: GeoMath.bearingDegrees(from: route.origin, to: route.destination),
            mood: route.mood,
            theme: route.colorTheme,
            followsVehicle: true,
            isMoving: !isPaused && timer.isRunning,
            style: mapStyle
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
        appModel?.cancelJourney(route: route,
                                focusedSeconds: Int(timer.elapsed.rounded()),
                                intention: intention)
    }

    // MARK: - Landing

    private func land() {
        guard !didLand, let appModel else { return }
        appModel.sound.stop()
        appModel.haptics.landing()
        let summary = appModel.completeJourney(
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
