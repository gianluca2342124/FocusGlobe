// ============================================================================
//  Focus Shield is PARKED for v1.0 distribution.
//
//  The full Screen Time implementation below compiles ONLY when the
//  `FOCUS_SHIELD_ENABLED` Swift flag is set (it is intentionally NOT set in any
//  build configuration). Until Apple grants the Family Controls **Distribution**
//  entitlement, the app ships with the no-op stub in the `#else` branch — no
//  FamilyControls / ManagedSettings / DeviceActivity usage, no authorization, no
//  picker, no shields. See FOCUS_SHIELD_PARKED.md to re-enable.
// ============================================================================

#if FOCUS_SHIELD_ENABLED
import Foundation
import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif
#if canImport(ManagedSettings)
import ManagedSettings
#endif
#if canImport(DeviceActivity)
import DeviceActivity
#endif

/// Coordinates FocusGlobe's app-blocking "Focus Shield" with Apple's Screen Time
/// APIs. Owns authorization, applies/clears shields around a journey, and starts
/// a DeviceActivity backstop so shields are removed even if the app is killed.
///
/// The public surface is available on every platform; on unsupported ones (Mac
/// "Designed for iPad", or anywhere FamilyControls is missing) every method is a
/// safe no-op and `isSupported` is `false`, so callers never need `#if`.
@MainActor
final class FocusShieldService: ObservableObject {

    enum AuthState: Equatable { case notDetermined, denied, approved, unavailable }

    enum ClearReason: String {
        case landing, cancel, expired
        case noActiveJourney = "no_active_journey"
        case userDisabled = "user_disabled"
    }

    // Observable state the SwiftUI surfaces bind to.
    @Published private(set) var authState: AuthState = .notDetermined
    @Published private(set) var isEnabled: Bool = false
    @Published private(set) var selectionCount: Int = 0
    @Published private(set) var isShieldActive: Bool = false

    /// Whether Screen Time blocking is usable at all. `false` on Mac (Designed
    /// for iPad) and wherever FamilyControls is unavailable.
    static var isSupported: Bool {
        #if canImport(FamilyControls)
        if ProcessInfo.processInfo.isiOSAppOnMac { return false }
        return true
        #else
        return false
        #endif
    }
    var isSupported: Bool { Self.isSupported }

    init() {
        isEnabled = FocusShieldShared.isEnabled
        selectionCount = FocusShieldShared.selectionCount
        isShieldActive = FocusShieldShared.isShieldActive
        refreshAuthorization()
    }

    // MARK: - Authorization

    func refreshAuthorization() {
        #if canImport(FamilyControls)
        guard isSupported else { authState = .unavailable; return }
        // Equality checks (not a switch) so this stays warning-free regardless
        // of any future FamilyControls `AuthorizationStatus` cases: the three
        // known states are handled explicitly and anything else (including
        // `.notDetermined` and any unknown future case) reads as not-determined.
        let status = AuthorizationCenter.shared.authorizationStatus
        if status == .approved {
            authState = .approved
        } else if status == .denied {
            authState = .denied
        } else {
            authState = .notDetermined
        }
        #else
        authState = .unavailable
        #endif
    }

    /// Request Screen Time / Family Controls authorization. Safe to call from a
    /// button; never spams (the system only prompts once per state).
    func requestAuthorization() async {
        #if canImport(FamilyControls)
        guard isSupported else { authState = .unavailable; return }
        FocusShieldLog.event("focus_shield_authorization_requested")
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authState = .approved
            FocusShieldLog.event("focus_shield_authorization_granted")
        } catch {
            refreshAuthorization()
            if authState != .approved { authState = .denied }
            FocusShieldLog.event("focus_shield_authorization_denied")
        }
        #else
        authState = .unavailable
        #endif
    }

    // MARK: - Selection

    #if canImport(FamilyControls)
    /// The user's current blocked selection (opaque tokens — never inspected).
    func currentSelection() -> FamilyActivitySelection {
        FocusShieldSelectionStore.loadSelection()
    }

    /// Persist a new selection. If a journey is live with shields active, the
    /// change is applied immediately.
    func updateSelection(_ selection: FamilyActivitySelection) {
        FocusShieldSelectionStore.saveSelection(selection)
        selectionCount = FocusShieldShared.selectionCount
        #if canImport(ManagedSettings)
        if isShieldActive { FocusShieldEngine.apply(selection) }
        #endif
    }
    #endif

    func setEnabled(_ on: Bool) {
        isEnabled = on
        FocusShieldShared.isEnabled = on
    }

    // MARK: - Journey lifecycle

    /// Apply shields for a starting journey and arm the DeviceActivity backstop
    /// for its duration. No-op unless supported, enabled, authorized and the
    /// selection is non-empty.
    func applyForJourney(durationSeconds: Int) {
        #if canImport(FamilyControls) && canImport(ManagedSettings)
        guard isSupported, isEnabled else { return }
        refreshAuthorization()
        guard authState == .approved else { return }
        let selection = FocusShieldSelectionStore.loadSelection()
        let count = selection.applicationTokens.count
            + selection.categoryTokens.count
            + selection.webDomainTokens.count
        guard count > 0 else { return }

        FocusShieldEngine.apply(selection)
        let now = Date()
        FocusShieldShared.isShieldActive = true
        FocusShieldShared.startedAt = now
        FocusShieldShared.endsAt = now.addingTimeInterval(TimeInterval(durationSeconds))
        isShieldActive = true
        startMonitoring(durationSeconds: durationSeconds)
        #endif
    }

    /// Clear every FocusGlobe shield and stop monitoring. Idempotent; only logs
    /// when a shield was actually active.
    func clear(reason: ClearReason) {
        #if canImport(FamilyControls) && canImport(ManagedSettings)
        guard isSupported else { return }
        guard FocusShieldShared.isShieldActive else { isShieldActive = false; return }
        FocusShieldEngine.clear()
        stopMonitoring()
        FocusShieldShared.isShieldActive = false
        FocusShieldShared.startedAt = nil
        FocusShieldShared.endsAt = nil
        isShieldActive = false
        FocusShieldLog.event("focus_shield_cleared reason=\(reason.rawValue)")
        #endif
    }

    /// User toggled Focus Shield off mid-journey — clear now and stay off until
    /// the next journey explicitly re-applies.
    func disableForActiveJourney() { clear(reason: .userDisabled) }

    /// Reconcile persisted shield state at launch / foreground. Clears stale
    /// shields when no journey is in flight, or when the planned end has passed.
    func reconcile(activeJourneyInFlight: Bool) {
        #if canImport(FamilyControls) && canImport(ManagedSettings)
        guard isSupported else { return }
        refreshAuthorization()
        selectionCount = FocusShieldShared.selectionCount
        isEnabled = FocusShieldShared.isEnabled
        isShieldActive = FocusShieldShared.isShieldActive
        guard FocusShieldShared.isShieldActive else { return }
        let expired = FocusShieldShared.endsAt.map { Date() >= $0 } ?? true
        if !activeJourneyInFlight {
            clear(reason: expired ? .expired : .noActiveJourney)
        } else if expired {
            clear(reason: .expired)
        }
        #endif
    }

    // MARK: - DeviceActivity monitoring (kill-safe backstop)

    private func startMonitoring(durationSeconds: Int) {
        #if canImport(DeviceActivity)
        let center = DeviceActivityCenter()
        let calendar = Calendar.current
        let now = Date()
        // Apple requires intervals ≥ 15 min; shorter journeys still clear precisely
        // in-app on landing — this is only the kill-safe ceiling.
        let minSeconds = FocusShieldShared.minMonitoringMinutes * 60
        let endDate = now.addingTimeInterval(TimeInterval(max(durationSeconds, minSeconds)))
        let startComponents = calendar.dateComponents([.hour, .minute, .second], from: now)
        let endComponents = calendar.dateComponents([.hour, .minute, .second], from: endDate)
        let schedule = DeviceActivitySchedule(intervalStart: startComponents,
                                              intervalEnd: endComponents,
                                              repeats: false)
        do {
            try center.startMonitoring(DeviceActivityName(FocusShieldShared.activityName), during: schedule)
            FocusShieldLog.event("focus_shield_device_activity_started")
        } catch {
            FocusShieldLog.event("focus_shield_device_activity_failed")
        }
        #endif
    }

    private func stopMonitoring() {
        #if canImport(DeviceActivity)
        DeviceActivityCenter().stopMonitoring([DeviceActivityName(FocusShieldShared.activityName)])
        FocusShieldLog.event("focus_shield_device_activity_ended")
        #endif
    }
}

#else

import Foundation

/// PARKED no-op stub of `FocusShieldService` (Focus Shield disabled for v1.0).
///
/// Same public surface the app calls (`applyForJourney`, `clear`, `reconcile`,
/// …) so journey/lifecycle code compiles unchanged — but it does nothing, never
/// touches Family Controls, and reports `isSupported == false`. The Settings
/// section shows a "Soon…" card instead. See FOCUS_SHIELD_PARKED.md.
@MainActor
final class FocusShieldService: ObservableObject {

    enum AuthState: Equatable { case notDetermined, denied, approved, unavailable }

    enum ClearReason: String {
        case landing, cancel, expired
        case noActiveJourney = "no_active_journey"
        case userDisabled = "user_disabled"
    }

    @Published private(set) var authState: AuthState = .unavailable
    @Published private(set) var isEnabled: Bool = false
    @Published private(set) var selectionCount: Int = 0
    @Published private(set) var isShieldActive: Bool = false

    /// Always false while parked — the feature is unavailable in this build.
    static var isSupported: Bool { false }
    var isSupported: Bool { false }

    init() {}

    func refreshAuthorization() {}
    func setEnabled(_ on: Bool) {}
    func applyForJourney(durationSeconds: Int) {}
    func clear(reason: ClearReason) {}
    func disableForActiveJourney() {}
    func reconcile(activeJourneyInFlight: Bool) {}
}

#endif
