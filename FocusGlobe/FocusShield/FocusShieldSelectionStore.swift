// PARKED for v1.0 distribution — compiles only with the `FOCUS_SHIELD_ENABLED`
// Swift flag (intentionally unset). See FOCUS_SHIELD_PARKED.md.
#if FOCUS_SHIELD_ENABLED
import Foundation
import os
#if canImport(FamilyControls)
import FamilyControls
#endif
#if canImport(ManagedSettings)
import ManagedSettings
#endif

// ============================================================================
//  Focus Shield — shared core
//
//  Constants, on-device logging, App-Group persistence of the user's blocked
//  selection + journey flags, and the ManagedSettings apply/clear engine.
//
//  SHARED FILE: this single file is the contract between the app and the three
//  Screen Time extensions (DeviceActivityMonitor, ShieldConfiguration,
//  ShieldAction). Add it to the **target membership of ALL of those targets**
//  (see FOCUS_SHIELD_SETUP.md). It depends only on Foundation / FamilyControls /
//  ManagedSettings (all guarded by `canImport`), never on the app's UI layer.
//
//  PRIVACY: a FamilyActivitySelection's tokens are opaque, private system data.
//  We persist only the selection blob (so the OS can re-resolve it) plus small
//  integer counts. We never decode app names, and nothing here is ever sent to
//  analytics, ads, RevenueCat, or any network.
// ============================================================================

enum FocusShieldShared {
    /// Shared App Group (same one the widgets use) so the extensions can read
    /// what the app writes.
    static let appGroupID = "group.com.focusglobe.app"
    /// Our own isolated ManagedSettings store — FocusGlobe only ever touches its
    /// own shields, never the user's other Screen Time settings.
    static let storeName = "FocusGlobeShield"
    /// The DeviceActivity schedule that bounds a single journey.
    static let activityName = "FocusGlobeJourney"
    /// Apple requires DeviceActivity monitoring intervals to be at least 15
    /// minutes; shorter journeys clamp the *backstop* window to this (the app
    /// still clears precisely on landing — see FocusShieldService).
    static let minMonitoringMinutes = 15

    enum Key {
        static let selection      = "fg.focusShield.selection"      // FamilyActivitySelection JSON
        static let enabled        = "fg.focusShield.enabled"        // Bool — use shields on journeys
        static let active         = "fg.focusShield.active"         // Bool — shields currently applied
        static let startedAt      = "fg.focusShield.startedAt"      // Double (epoch)
        static let endsAt         = "fg.focusShield.endsAt"         // Double (epoch)
        static let appCount       = "fg.focusShield.appCount"
        static let categoryCount  = "fg.focusShield.categoryCount"
        static let domainCount    = "fg.focusShield.domainCount"
    }

    /// App-Group defaults, with a safe fallback so nothing ever crashes if the
    /// group isn't linked yet (the feature simply behaves as "off").
    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    // MARK: Journey flags (no FamilyControls dependency — safe everywhere)

    static var isEnabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }
    static var isShieldActive: Bool {
        get { defaults.bool(forKey: Key.active) }
        set { defaults.set(newValue, forKey: Key.active) }
    }
    static var startedAt: Date? {
        get { let t = defaults.double(forKey: Key.startedAt); return t > 0 ? Date(timeIntervalSince1970: t) : nil }
        set { defaults.set(newValue?.timeIntervalSince1970 ?? 0, forKey: Key.startedAt) }
    }
    static var endsAt: Date? {
        get { let t = defaults.double(forKey: Key.endsAt); return t > 0 ? Date(timeIntervalSince1970: t) : nil }
        set { defaults.set(newValue?.timeIntervalSince1970 ?? 0, forKey: Key.endsAt) }
    }
    static var counts: (apps: Int, categories: Int, domains: Int) {
        (defaults.integer(forKey: Key.appCount),
         defaults.integer(forKey: Key.categoryCount),
         defaults.integer(forKey: Key.domainCount))
    }
    /// Total number of selected items (apps + categories + web domains).
    static var selectionCount: Int {
        let c = counts; return c.apps + c.categories + c.domains
    }
}

// MARK: - On-device debug logging (counts only; never tokens / app names)

enum FocusShieldLog {
    private static let logger = Logger(subsystem: "com.focusglobe.app", category: "FocusShield")

    /// Emits one of the agreed `focus_shield_*` debug events. Uses the unified
    /// log (on-device, private) and a DEBUG console print — never the analytics
    /// pipeline, ads, RevenueCat or any network.
    static func event(_ message: String) {
        logger.log("📵 [focus_shield] \(message, privacy: .public)")
        #if DEBUG
        print("📵 [focus_shield] \(message)")
        #endif
    }
}

#if canImport(FamilyControls)

// MARK: - Selection persistence (App Group)

/// Reads/writes the user's blocked `FamilyActivitySelection` to the shared App
/// Group, plus the small integer counts the UI / shield screen display. All
/// encode/decode failures degrade gracefully to an empty selection.
@available(iOS 16.0, *)
enum FocusShieldSelectionStore {

    static func loadSelection() -> FamilyActivitySelection {
        guard let data = FocusShieldShared.defaults.data(forKey: FocusShieldShared.Key.selection) else {
            return FamilyActivitySelection()
        }
        do {
            return try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        } catch {
            FocusShieldLog.event("selection_decode_failed")
            return FamilyActivitySelection()
        }
    }

    static func saveSelection(_ selection: FamilyActivitySelection) {
        let apps = selection.applicationTokens.count
        let cats = selection.categoryTokens.count
        let domains = selection.webDomainTokens.count
        do {
            let data = try JSONEncoder().encode(selection)
            FocusShieldShared.defaults.set(data, forKey: FocusShieldShared.Key.selection)
        } catch {
            FocusShieldLog.event("selection_encode_failed")
        }
        FocusShieldShared.defaults.set(apps, forKey: FocusShieldShared.Key.appCount)
        FocusShieldShared.defaults.set(cats, forKey: FocusShieldShared.Key.categoryCount)
        FocusShieldShared.defaults.set(domains, forKey: FocusShieldShared.Key.domainCount)
        FocusShieldLog.event("focus_shield_selection_saved count=\(apps + cats + domains)")
    }
}

#endif

#if canImport(ManagedSettings) && canImport(FamilyControls)

// MARK: - Shield engine (apply / clear ManagedSettings)

/// Applies and clears FocusGlobe's shields on its **own named** ManagedSettings
/// store. Shared by the app (start/stop a journey) and the DeviceActivity
/// monitor extension (the kill-safe backstop that clears when the interval ends).
@available(iOS 16.0, *)
enum FocusShieldEngine {
    static var store: ManagedSettingsStore {
        ManagedSettingsStore(named: ManagedSettingsStore.Name(FocusShieldShared.storeName))
    }

    /// Shield the apps / categories / web domains in `selection`. Empty buckets
    /// are set to `nil` so we never shield "everything" by accident.
    static func apply(_ selection: FamilyActivitySelection) {
        let s = store
        let apps = selection.applicationTokens
        let categories = selection.categoryTokens
        let domains = selection.webDomainTokens

        s.shield.applications = apps.isEmpty ? nil : apps
        // Direct (non-ternary) assignment so the generic `ActivityCategoryPolicy`
        // type infers cleanly from the property.
        if categories.isEmpty {
            s.shield.applicationCategories = nil
        } else {
            s.shield.applicationCategories = .specific(categories)
        }
        s.shield.webDomains = domains.isEmpty ? nil : domains

        FocusShieldLog.event("focus_shield_applied apps=\(apps.count) categories=\(categories.count) domains=\(domains.count)")
    }

    /// Remove every FocusGlobe shield. Only ever touches our own named store, so
    /// the user's other Screen Time configuration is untouched.
    static func clear() {
        let s = store
        s.shield.applications = nil
        s.shield.applicationCategories = nil
        s.shield.webDomains = nil
        s.shield.webDomainCategories = nil
        s.clearAllSettings()
    }
}

#endif

#endif
