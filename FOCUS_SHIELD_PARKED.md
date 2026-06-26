# Focus Shield — PARKED for v1.0

The **Focus Shield** app-blocking feature (Apple **Family Controls** / Screen
Time) is **temporarily parked** for the v1.0 App Store / TestFlight release.

## Why

App-blocking uses the **Family Controls** capability. Shipping it requires the
**Family Controls *Distribution* entitlement**, which Apple must approve for the
account. The standard App Store provisioning profiles do **not** include it, so
an archive that requests `com.apple.developer.family-controls` (in the app or any
embedded extension) **fails to distribute to TestFlight**. Rather than block the
launch waiting on Apple's approval, the feature is parked and will be reintroduced
in a future update once the Distribution entitlement is granted.

## What the user sees now

- **Settings → Focus Shield:** a premium, **disabled "Soon…" card** —
  *"Block distracting apps"* / *"Soon… keep social, video and games out of your
  focus journeys"* with a gold **SOON** badge. Tapping it only shows a brief
  *"Coming soon ✨"* note; it never opens a picker or requests permission.
- **Boarding pass:** a small, static, **disabled "App blocking — Soon…"** teaser
  (non-interactive; no picker, no permission).
- **Active journey:** the shield button is **not shown**.
- Nothing requests Family Controls authorization, opens the `FamilyActivityPicker`,
  starts DeviceActivity monitoring, or applies shields.

## What was disabled / removed (and what was kept)

### App source — gated behind `FOCUS_SHIELD_ENABLED` (a Swift flag, intentionally **unset**)

All Family-Controls-using code in `FocusGlobe/FocusShield/` compiles **only** when
the `FOCUS_SHIELD_ENABLED` active-compilation condition is set. It is **not set in
any build configuration**, so the parked path compiles instead:

| File | Parked behavior |
|------|-----------------|
| `FocusShieldService.swift` | A no-op stub `FocusShieldService` with the same public API (`applyForJourney`, `clear`, `reconcile`, …) so journey/lifecycle code is unchanged. `isSupported == false`. No FamilyControls import. |
| `FocusShieldSelectionStore.swift` | Entire file behind the flag (the App-Group store + ManagedSettings engine). |
| `FocusShieldPickerView.swift` | Entire file behind the flag (the FamilyActivityPicker wrapper). |
| `FocusShieldSettingsSection.swift` | Full version behind the flag; the parked `#else` renders the disabled **"Soon…"** Settings card. |
| `FocusShieldBoardingRow.swift` | Entire file behind the flag; no longer placed on the boarding pass. |
| `FocusShieldControl.swift` | Entire file behind the flag; no longer shown in the active-journey controls. |

Call sites kept (compile against the no-op stub): `AppModel.focusShield`,
`FocusSessionViewModel` (apply/clear), `FocusGlobeApp` (reconcile),
`SettingsView` (renders the "Soon…" card). Boarding's interactive row and the
active-journey shield button were removed.

> The source files are **preserved in the repo** — only the compiled behavior
> changes (the parked `#else` paths).

### Xcode project — extension targets removed from distribution

The three Screen Time extension **targets** were removed from the Xcode project so
nothing requiring Family Controls is built or embedded in the archive:

- `FocusGlobeDeviceActivityMonitorExtension`
- `FocusGlobeShieldConfigurationExtension`
- `FocusGlobeShieldActionExtension`

`project.pbxproj` was restored to the pre-extension state (commit `dfd8a2c`) — this
cleanly drops the three targets, their build phases, their `Embed App Extensions`
entries, their target dependencies, and their per-target Family Controls
entitlements. The app target's `CODE_SIGN_ENTITLEMENTS = FocusGlobe/FocusGlobe.entitlements`
was re-added so the **App Group is preserved**.

> The extension **source files are preserved on disk** (orphaned, not compiled):
> `FocusGlobeDeviceActivityMonitorExtension/`, `FocusGlobeShieldConfigurationExtension/`,
> `FocusGlobeShieldActionExtension/` (the wired versions), plus the original
> `FocusGlobeShieldExtensions/` reference copies.

### Entitlements

- **App (`FocusGlobe/FocusGlobe.entitlements`):** removed
  `com.apple.developer.family-controls`; **kept** the App Group
  `group.com.focusglobe.app`.
- **Widget (`FocusGlobeWidgetsExtension.entitlements`):** untouched — App Group only.
- The orphaned extension `.entitlements` files still exist on disk (for future
  restore) but are not referenced by any target.

## Not touched

AdMob, RevenueCat / subscriptions / paywall, Maps, location, notifications, audio,
**widgets**, App Group IDs, bundle IDs, AdMob IDs, RevenueCat product IDs, and
iPad / Mac support were **not changed** (beyond removing the parked UI call sites).

## How to re-enable later (once Apple approves Family Controls Distribution)

1. **Apple:** obtain the **Family Controls (Distribution)** entitlement for the
   account and a provisioning profile that includes it.
2. **App entitlement:** add back to `FocusGlobe/FocusGlobe.entitlements`:
   ```xml
   <key>com.apple.developer.family-controls</key>
   <true/>
   ```
   (keep the App Group.)
3. **Swift flag:** add `FOCUS_SHIELD_ENABLED` to the app target's
   **Swift Compiler → Active Compilation Conditions** (Debug and/or Release as
   desired). This re-activates the full `FocusGlobe/FocusShield/` implementation
   and the live Settings section; re-add the boarding row / active-journey control
   call sites if you want those surfaces back (see git history around `dfd8a2c`).
4. **Recreate the 3 extension targets** in Xcode (File ▸ New ▸ Target):
   - **Device Activity Monitor Extension** → use
     `FocusGlobeDeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift`
     (or `FocusGlobeShieldExtensions/FocusGlobeDeviceActivityMonitor.swift`).
   - **Shield Configuration Extension** → `…/ShieldConfigurationExtension.swift`.
   - **Shield Action Extension** → `…/ShieldActionExtension.swift`.
   Restore each target's `Info.plist` (`NSExtensionPrincipalClass`),
   `.entitlements` (Family Controls), **App Group** `group.com.focusglobe.app`, and
   add the shared `FocusGlobe/FocusShield/FocusShieldSelectionStore.swift` to each
   target's membership. Full details are in **FOCUS_SHIELD_SETUP.md**.
5. **Capabilities to restore:** Family Controls (app + DeviceActivityMonitor
   extension, and the Shield extensions to be safe); App Groups on all of them.
6. Archive and distribute — now that the Distribution entitlement is approved.

See **FOCUS_SHIELD_SETUP.md** for the complete original setup (targets, Info.plist
keys, App Group wiring, testing) and **WIDGETS_SETUP.md** for the App Group the
widgets share.
