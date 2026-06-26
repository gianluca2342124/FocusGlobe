# FocusGlobe — Focus Shield Setup

**Focus Shield** lets a user block distracting apps, categories and web domains
for the duration of a focus journey, using Apple's official Screen Time APIs
(**FamilyControls**, **ManagedSettings**, **DeviceActivity**, **ManagedSettingsUI**).
No private APIs are used.

All the Swift source is written and wired into the app. Because Screen Time
needs a special Apple capability plus **app-extension targets** (each its own
bundle + entitlements), a one-time Xcode setup is required — extension targets
can't be created safely from source alone. Everything below is that wiring.

> Like the widgets, the app builds and runs **without** this setup: Focus Shield
> simply reports itself unavailable / unauthorized and is a no-op. Nothing
> crashes, and existing journeys, Apple Maps, RevenueCat, AdMob, widgets,
> notifications and App-Group sharing are untouched.

---

## What was added in code

| File | Target(s) | Purpose |
|------|-----------|---------|
| `FocusGlobe/FocusShield/FocusShieldSelectionStore.swift` | **App + all 3 extensions** | **Shared core**: constants, App-Group persistence of the `FamilyActivitySelection` + journey flags, on-device logging, and the ManagedSettings apply/clear engine |
| `FocusGlobe/FocusShield/FocusShieldService.swift` | App | `@MainActor` service: authorization, apply/clear shields, DeviceActivity scheduling, launch reconciliation, observable state |
| `FocusGlobe/FocusShield/FocusShieldPickerView.swift` | App | Premium configurator sheet — wraps `FamilyActivityPicker`, handles auth states, shows the selected count |
| `FocusGlobe/FocusShield/FocusShieldSettingsSection.swift` | App | Reusable Settings section (default blocked apps) |
| `FocusGlobe/FocusShield/FocusShieldBoardingRow.swift` | App | The Focus Shield row on the boarding pass |
| `FocusGlobe/FocusShield/FocusShieldControl.swift` | App | The shield button among the active-journey controls |
| `FocusGlobeShieldExtensions/FocusGlobeDeviceActivityMonitor.swift` | **DeviceActivityMonitor ext** | Clears shields when the journey interval ends (kill-safe backstop) |
| `FocusGlobeShieldExtensions/FocusGlobeShieldConfiguration.swift` | **ShieldConfiguration ext** | The custom branded blocked screen |
| `FocusGlobeShieldExtensions/FocusGlobeShieldAction.swift` | **ShieldAction ext** (optional) | Handles "Back to Focus" (closes the blocked app; no bypass) |

Integration points (already wired): `AppModel.focusShield` (the service);
`FocusSessionViewModel` applies shields on start and clears on land / cancel /
teardown; `FocusGlobeApp` reconciles stale shields on launch and foreground;
Settings, Boarding and the Active-Journey controls present the configurator.

---

## Required capability — Family Controls (read this first)

Screen Time blocking is gated by the **Family Controls** capability /
`com.apple.developer.family-controls` entitlement.

- **Development:** the *development* Family Controls entitlement works on a
  **real device** in Debug with a normal Apple Developer account.
- **Distribution / TestFlight / App Store:** you must **request the distribution
  Family Controls entitlement from Apple** (developer.apple.com ▸ Account ▸
  request). Approval is required before you can ship. Plan for this lead time.
- **Simulator:** Family Controls is **not** meaningfully supported in the
  Simulator — see "Testing" below.

---

## App Group

- **App Group id:** `group.com.focusglobe.app` (the same one the widgets use).
- The app writes the blocked selection + journey flags here; the extensions read
  them. Enable this App Group on the app **and every extension** target.
- The shared façade (`FocusShieldShared` / `FocusShieldSelectionStore` /
  `FocusShieldEngine`) falls back to `UserDefaults.standard` if the group isn't
  linked yet, so nothing crashes — the feature just behaves as "off".

---

## One-time Xcode steps

### 1. App target capabilities

1. **Signing & Capabilities ▸ + Capability ▸ Family Controls.**
2. **+ Capability ▸ App Groups** ▸ add `group.com.focusglobe.app` (already added
   for widgets — reuse it).

### 2. Create the three extension targets

Use **File ▸ New ▸ Target…** and pick each template:

| Template | Suggested name | Suggested bundle id | Info.plist `NSExtensionPointIdentifier` | Principal class |
|----------|----------------|---------------------|------------------------------------------|-----------------|
| **Device Activity Monitor Extension** | `FocusGlobeDeviceActivityMonitor` | `com.focusglobe.app.DeviceActivityMonitor` | `com.apple.deviceactivity.monitor-extension` | `FocusGlobeDeviceActivityMonitor` |
| **Shield Configuration Extension** | `FocusGlobeShieldConfiguration` | `com.focusglobe.app.ShieldConfiguration` | `com.apple.ManagedSettingsUI.shield-configuration-service` | `FocusGlobeShieldConfigurationProvider` |
| **Shield Action Extension** (optional) | `FocusGlobeShieldAction` | `com.focusglobe.app.ShieldAction` | `com.apple.ManagedSettings.shield-action-service` | `FocusGlobeShieldActionProvider` |

For each new target:
- Delete the template's generated sample class file and add the matching file
  from `FocusGlobeShieldExtensions/` instead (or replace its contents).
- Set the Info.plist **`NSExtensionPrincipalClass`** to
  `$(PRODUCT_MODULE_NAME).<Principal class>` from the table.
- Set the **iOS Deployment Target to 16.0+** (the app itself is iOS 17).
- **+ Capability ▸ App Groups** ▸ `group.com.focusglobe.app`.
- **+ Capability ▸ Family Controls** on the **DeviceActivityMonitor** target (and,
  to be safe, on the Shield targets too — harmless if unused).

### 3. Share the core file across targets

Select **`FocusGlobe/FocusShield/FocusShieldSelectionStore.swift`** and, in the
File Inspector ▸ **Target Membership**, tick the app **and all three extension
targets**. (It's the single source of truth for the App-Group keys, the
ManagedSettings store name, and the apply/clear engine — do not duplicate it.)

### 4. Link the frameworks

Xcode links these automatically with the templates, but verify:
- **App:** FamilyControls, ManagedSettings, DeviceActivity.
- **DeviceActivityMonitor ext:** DeviceActivity, ManagedSettings, FamilyControls.
- **ShieldConfiguration ext:** ManagedSettings, ManagedSettingsUI, UIKit.
- **ShieldAction ext:** ManagedSettings.

### 5. (Optional) Branded shield glyph

Add an image named **`FocusShieldGlyph`** (a balloon mark) to the
ShieldConfiguration extension's asset catalog for full branding. Without it the
shield falls back to an on-brand SF Symbol, so the screen is never blank.

---

## How blocking behaves

- **Start journey:** if Focus Shield is enabled, authorized and the selection is
  non-empty, shields are applied and a DeviceActivity interval is armed for the
  remaining journey time.
- **Land / cancel / leave:** shields are cleared and monitoring stops.
- **Pause:** apps stay blocked (a pause is still "in flight") unless the user
  explicitly taps **Disable for this journey**.
- **Background:** shields remain active.
- **App killed / suspended:** the DeviceActivity monitor extension clears the
  shields when the interval ends — apps are **never** left blocked permanently.
- **Launch / foreground:** the app reconciles and clears any stale shields if no
  journey is in flight or the planned end time has passed.
- **DeviceActivity minimum interval:** Apple requires monitoring intervals of
  **≥ 15 minutes**. For shorter journeys the in-app clear on landing is precise;
  the kill-safe backstop simply can't fire sooner than 15 minutes. Stale shields
  are also cleared at the next launch/foreground, so nothing is ever stuck.

---

## Testing

### On a real device (required for the real feature)
1. Run the app in **Debug** on a device signed into a developer account with the
   Family Controls capability.
2. Settings ▸ **Focus Shield** ▸ *Default blocked apps* ▸ **Enable Focus Shield**
   → approve the Screen Time prompt → **Choose apps** and pick a few.
3. Start a journey. Try to open a blocked app → the FocusGlobe shield appears.
4. Land (or cancel) the journey → the app unblocks.
5. Force-quit mid-journey, then wait past the interval (≥ 15 min) → the monitor
   extension clears the shields. Or relaunch → stale shields clear immediately.
6. Watch the on-device log (Console.app, subsystem `com.focusglobe.app`,
   category `FocusShield`) for the `focus_shield_*` debug events.

### In the Simulator
- `FamilyActivityPicker` and real blocking are **not** reliably available.
- The app still **compiles and runs**: you'll see the permission / unavailable
  states, and `applyForJourney` is a safe no-op. Use the Simulator only for UI
  layout; verify actual blocking on a device.

### Mac (Designed for iPad)
- Focus Shield reports **unsupported** (`ProcessInfo.isiOSAppOnMac`): the boarding
  row and active-journey button hide themselves, and the Settings section shows
  *"Available on iPhone and iPad."* The build is clean and never crashes.

---

## Privacy

- A `FamilyActivitySelection`'s tokens are **opaque, private system data**. The
  app never decodes or displays real app names — only counts and generic labels.
- The selection is stored **only** in the App Group on-device. None of it is ever
  sent to analytics, ads, RevenueCat, or any network.
- The `focus_shield_*` debug events go to the on-device unified log (counts only),
  never to the analytics pipeline.

### App Privacy notes
Adding Family Controls does not, by itself, collect data off-device. Keep the
Privacy Policy / App Store privacy answers accurate: Focus Shield data stays on
device. (See PERSISTENCE_MODEL.md and APP_STORE_FINAL_CHECKLIST.md.)
