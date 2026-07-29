# Focus Shield — PARKED for v1.0

> ## ⚠️ SUPERSEDED — Focus Shield has been UN-parked in the project
>
> Everything below describes the *parked* state and is **no longer what the
> repository does**. Verified against `FocusGlobe.xcodeproj/project.pbxproj`:
>
> | Step from "How to re-enable later" | Status |
> |---|---|
> | 2 · `com.apple.developer.family-controls` in the app entitlements | **done** (plus `…family-controls.app-and-website-usage`) |
> | 3 · `FOCUS_SHIELD_ENABLED` compilation condition | **done — set on the FocusGlobe app target, BOTH Debug and Release** |
> | 4 · Shield **Configuration** Extension target | **done** — builds, embedded in *Embed Foundation Extensions*, correct `NSExtensionPointIdentifier`, principal class and entitlements |
> | 4 · Shield **Action** Extension target | **done** — same, verified |
> | 4 · **Device Activity Monitor** Extension target | **NOT DONE — see below** |
>
> So the live app *does* compile the full Screen Time implementation, requests
> Family Controls authorization, and ships two extensions that declare
> `com.apple.developer.family-controls`.
>
> **Two consequences to be aware of:**
>
> 1. **Distribution.** The warning in "Why" below still applies: an archive that
>    requests Family Controls in the app *or any embedded extension* cannot be
>    distributed without the **Family Controls (Distribution)** entitlement on
>    the account. If that has since been granted, this is fine and this document
>    is simply historical. If it has not, archiving will fail — and it will now
>    fail for three reasons rather than none.
> 2. **The kill-safe backstop is inert.** `FocusShieldService.startMonitoring(…)`
>    schedules a `DeviceActivity` interval on every journey, but with no Device
>    Activity Monitor target nothing handles `intervalDidEnd`. Shields therefore
>    survive an app kill until the next launch calls `reconcile(…)`. The real
>    implementation and a correct `Info.plist` / `.entitlements` are ready in
>    `FocusGlobeDeviceActivityMonitorExtension/`; that file's header comment
>    lists the four remaining steps. It must be added through
>    **Xcode ▸ File ▸ New ▸ Target**, not by hand-editing `project.pbxproj`,
>    because that is what registers the capability against the App ID.
>
> The duplicate, never-referenced `FocusGlobeShieldExtensions/` folder (a stale
> second copy of all three extensions) has been deleted so there is exactly one
> source of truth per extension.

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
