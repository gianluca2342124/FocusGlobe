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

    /// Active flight default is "Dark Earth" (dark/premium Apple Standard).
    @Published var mapStyle: MapDisplayStyle = .terra
    /// Whether map labels/POIs are shown (Labels toggle in the map controls).
    @Published var labelsOn: Bool = true
    /// Whether this session's journey audio is muted (volume only — pause/resume
    /// and the loop are unaffected).
    @Published private(set) var isMuted: Bool = false
    /// Camera behaviour the user can toggle in-session (follow vs. full route).
    @Published var cameraMode: JourneyCameraMode = .follow
    /// A gentle 3D tilt of the follow camera. Journeys start in 3D by default.
    @Published var tilted = true
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
    /// Set the instant the journey finishes so the completion → interstitial →
    /// Landing transition can't be entered twice.
    private var landing = false
    private var resumeAfterCancelDismiss = false
    /// The balloon skin asset captured at attach time so the map marker renders
    /// the user's selected skin (falls back to the default art if missing).
    private var skinAssetName: String = BalloonSkin.default.assetName

    init(journey: Journey) {
        self.origin = journey.origin
        self.route = journey.route
        self.intention = journey.intention
        // Resume support: seed elapsed when continuing an unfinished journey.
        self.timer = SessionTimerService(total: journey.route.duration,
                                         startElapsed: TimeInterval(journey.resumeElapsedSeconds ?? 0))
        self.journeyDistanceKm = GeoMath.distanceKm(from: journey.origin.coordinate,
                                                    to: journey.route.destination)
    }

    // MARK: - Lifecycle

    func attach(appModel: AppModel) {
        guard self.appModel == nil else { return }
        self.appModel = appModel
        skinAssetName = appModel.selectedSkin.assetName
        // The active flight defaults to "Dark Earth" (dark/premium). A bottom
        // scrim in FocusSessionView keeps readouts legible. The user can switch
        // styles and toggle labels via the in-session menu.
        mapStyle = .terra
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
        appModel.uiSound.play(.journeyStart)
        // Preload the journey-complete interstitial now so it's ready by landing.
        appModel.ads.preloadInterstitial(isPro: appModel.isPro)
        appModel.sound.startJourney(option: appModel.selectedJourneyAudio)
        timer.start()
        // Focus Shield: block the user's chosen apps for the remaining journey
        // time (handles resume — shields last until this journey actually lands).
        appModel.focusShield.applyForJourney(durationSeconds: Int(timer.remaining.rounded()))
    }

    func tearDown() {
        cancellable?.cancel()
        // Always stop the engine timer (idempotent). Landing an endless flight
        // early leaves the repeating tick scheduled otherwise — a quiet leak.
        timer.stop()
        if !didLand {
            // Backstop: the journey view went away without landing — make sure no
            // shields are left behind (idempotent; a no-op if already cleared).
            appModel?.focusShield.clear(reason: .cancel)
        }
        appModel?.sound.stop()
    }

    /// Call when the scene becomes active so a backgrounded session catches up.
    func refresh() { timer.refresh() }

    // MARK: - Derived display values

    var phase: JourneyPhase { JourneyPhase(progress: progress) }

    /// A calm, FocusGlobe-flavoured status for the top pill.
    var statusLabel: String {
        switch phase {
        case .boarding, .takingOff: return "Focusing"
        case .cruising:             return "In flight"
        case .approaching:          return "In flight"
        case .landing:              return "Arriving"
        }
    }

    var remainingSeconds: Int { max(0, Int(timer.remaining.rounded(.up))) }
    var remainingTimeText: String { Formatters.countdown(remainingSeconds) }

    // MARK: - Live display model (read inside the flight's TimelineView)
    //
    // These read the wall clock on every access, so they are always current
    // regardless of the @Published tick cadence — the fix for "frozen" readouts.
    // The visible active-flight UI uses ONLY these, never the map-era readouts.

    /// Total symbolic flight distance (km) for the chosen duration — the single
    /// source for the visible distance (never the geographic origin→dest span).
    var totalFlightKm: Double { route.approximateDistanceKm }
    var liveProgress: Double { timer.liveProgress }
    var liveRemainingSeconds: Int { max(0, Int(timer.liveRemaining.rounded(.up))) }
    var liveElapsedSeconds: Int { Int(timer.liveElapsed.rounded(.down)) }
    var liveRemainingKm: Double { max(0, totalFlightKm * (1 - liveProgress)) }
    var liveTraveledKm: Double { FlightRouteFactory.traveledKm(elapsedSeconds: liveElapsedSeconds) }

    /// Completion backstop: if the live clock has reached the full duration but
    /// the repeating timer's callback was starved (heavy render frame), land now.
    /// Idempotent — `land()` guards against a second completion.
    func finishIfDue() {
        guard !didLand, !landing, timer.liveProgress >= 1 else { return }
        land()
    }

    /// Coarse remaining-time label for the big "Time Remaining" readout.
    /// Under an hour it reads as whole minutes ("33 min"); from an hour up it
    /// reads as hours + zero-padded minutes ("1h 05m", "2h 14m", "8h 42m") so a
    /// long journey never shows an unwieldy raw minute count like "522 min".
    var remainingMinutesText: String {
        let totalMinutes = max(0, Int((Double(remainingSeconds) / 60).rounded(.up)))
        if totalMinutes < 60 { return "\(totalMinutes) min" }
        return String(format: "%dh %02dm", totalMinutes / 60, totalMinutes % 60)
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
            cameraToken: cameraToken,
            skinAssetName: skinAssetName,
            labelsOn: labelsOn
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

    /// Toggle map labels/POIs (re-applies the map style configuration).
    func toggleLabels() {
        labelsOn.toggle()
        appModel?.haptics.tap()
    }

    // MARK: - Audio mute

    /// `true` when no journey audio is effectively playing — either muted in this
    /// session or the global Sound setting is off (so the button reflects it).
    var isAudioMuted: Bool { isMuted || !(appModel?.settings.soundEnabled ?? true) }

    var muteIconName: String { isAudioMuted ? "speaker.slash.fill" : "speaker.wave.2.fill" }

    func toggleMute() {
        isMuted.toggle()
        appModel?.sound.setMuted(isMuted)
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

    /// Leave the journey before landing. Saved as a resumable snapshot so the
    /// user can continue (or discard) from Home. The caller dismisses the cover.
    func confirmCancel() {
        showCancelConfirm = false
        saveResumeSnapshot()
        timer.stop()
        appModel?.sound.stop()
        // Leaving before landing → drop the shields (a paused/resumable journey
        // is not "in flight").
        appModel?.focusShield.clear(reason: .cancel)
    }

    // MARK: - Resume snapshot

    /// Persist a lightweight snapshot so an unfinished journey can be resumed
    /// (called when leaving the journey or when the app is backgrounded).
    func persistForResume() { saveResumeSnapshot() }

    /// End an open-ended (Infinity) flight now, banking it as a **completed**
    /// session — streak, history, missions and rewards all count, exactly like a
    /// timer running out. Safe no-op if the flight already landed.
    func landNow() {
        guard !didLand, !landing else { return }
        land()
    }

    private func saveResumeSnapshot() {
        guard let appModel, !didLand else { return }
        let elapsed = Int(timer.elapsed.rounded())
        let total = Int(timer.total.rounded())
        guard elapsed > 0, elapsed < total else { return }   // nothing to resume / already done
        appModel.saveResumableJourney(origin: origin, route: route, intention: intention,
                                      elapsedSeconds: elapsed,
                                      skinAssetName: appModel.selectedSkin.assetName,
                                      soundID: appModel.selectedJourneyAudio.id)
    }

    // MARK: - Landing

    private func land() {
        guard !didLand, !landing, let appModel else { return }
        landing = true
        appModel.sound.stop()
        appModel.focusShield.clear(reason: .landing)   // journey complete → unblock apps
        appModel.clearResumableJourney()   // completed → no longer resumable
        // Bank the journey now (rewards/streak/history) regardless of any ad.
        landingSummary = appModel.completeJourney(
            origin: origin,
            route: route,
            // Bank what was actually flown. The timer clamps elapsed == total on
            // a natural finish, so this only differs for "Land now" on an
            // endless flight — which must never bank the full 12-hour cap.
            focusedSeconds: Int(timer.elapsed.rounded()),
            intention: intention
        )
        // Reveal the Landing screen (with its postcard) immediately. The single
        // interstitial for free users is deferred to the moment they LEAVE the
        // Landing screen, and is skipped if they chose to watch the rewarded
        // "double miles" ad — so two ads never stack in one landing.
        revealLanding()
    }

    /// Reveal the Landing screen (after the optional completion interstitial).
    private func revealLanding() {
        guard let appModel else { return }
        appModel.haptics.landing()
        appModel.uiSound.play(.landing)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            didLand = true
        }
    }
}
