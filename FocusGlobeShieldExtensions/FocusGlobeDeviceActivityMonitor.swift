import Foundation
#if canImport(DeviceActivity)
import DeviceActivity
#endif

// ============================================================================
//  Device Activity Monitor Extension — the kill-safe backstop
//
//  When a journey starts, the app schedules a DeviceActivity interval for the
//  journey's duration. If the app is killed or suspended, this extension still
//  runs at the interval boundaries — so FocusGlobe's shields are guaranteed to
//  be cleared when the journey should be over, never left on permanently.
//
//  TARGET: add this file to the **FocusGlobeDeviceActivityMonitor** extension
//  target, along with the shared `FocusShieldSelectionStore.swift`. Point the
//  extension's Info.plist `NSExtensionPrincipalClass` at this class. See
//  FOCUS_SHIELD_SETUP.md.
// ============================================================================

#if canImport(DeviceActivity)

@available(iOS 16.0, *)
final class FocusGlobeDeviceActivityMonitor: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity.rawValue == FocusShieldShared.activityName else { return }
        // Re-assert the shields in case the app was killed immediately after
        // starting the journey (so blocking is never silently skipped).
        if FocusShieldShared.isShieldActive {
            FocusShieldEngine.apply(FocusShieldSelectionStore.loadSelection())
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity.rawValue == FocusShieldShared.activityName else { return }
        // The journey's scheduled window has ended — clear every FocusGlobe shield
        // even if the app isn't running.
        FocusShieldEngine.clear()
        FocusShieldShared.isShieldActive = false
        FocusShieldShared.startedAt = nil
        FocusShieldShared.endsAt = nil
        FocusShieldLog.event("focus_shield_cleared reason=expired")
    }
}

#endif
