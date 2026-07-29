import Foundation
#if canImport(DeviceActivity)
import DeviceActivity
#endif

// ============================================================================
//  Device Activity Monitor Extension — the kill-safe backstop
//
//  When a journey starts, `FocusShieldService.startMonitoring(durationSeconds:)`
//  schedules a DeviceActivity interval for the journey's length. If the app is
//  killed or suspended mid-flight, this extension still runs at the interval
//  boundaries — so FocusGlobe's shields are guaranteed to be cleared when the
//  journey should be over, and can never be left applied permanently.
//
//  ⚠️ NOT YET IN THE XCODE PROJECT. The app already ARMS this schedule, but
//  without a Device Activity Monitor target nothing handles `intervalDidEnd`,
//  so today the backstop is inert: shields survive an app kill until the next
//  launch calls `FocusShieldService.reconcile(...)`. To finish the wiring:
//
//    1. Xcode ▸ File ▸ New ▸ Target ▸ **Device Activity Monitor Extension**,
//       named `FocusGlobeDeviceActivityMonitorExtension` so it adopts this
//       folder (the Info.plist and .entitlements here are already correct).
//       Creating it through Xcode — rather than hand-editing project.pbxproj —
//       is what registers the Family Controls capability against the App ID.
//    2. Add `FOCUS_SHIELD_ENABLED` to the new target's Swift
//       Active Compilation Conditions (it is already set on the app target).
//    3. Add `FocusGlobe/FocusShield/FocusShieldSelectionStore.swift` to the new
//       target's membership — it is the shared contract that defines
//       `FocusShieldShared`, `FocusShieldEngine` and `FocusShieldSelectionStore`
//       used below, and it lives behind the same flag.
//    4. Give the target the App Group `group.com.focusglobe.app` so it can read
//       what the app wrote.
//
//  See FOCUS_SHIELD_SETUP.md and FOCUS_SHIELD_PARKED.md.
// ============================================================================

#if canImport(DeviceActivity) && FOCUS_SHIELD_ENABLED

/// The class name must match `NSExtensionPrincipalClass` in this folder's
/// Info.plist (`$(PRODUCT_MODULE_NAME).DeviceActivityMonitorExtension`).
@available(iOS 16.0, *)
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {

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
        // The journey's scheduled window has ended — clear every FocusGlobe
        // shield even if the app isn't running.
        FocusShieldEngine.clear()
        FocusShieldShared.isShieldActive = false
        FocusShieldShared.startedAt = nil
        FocusShieldShared.endsAt = nil
        FocusShieldLog.event("focus_shield_cleared reason=expired")
    }
}

#endif
