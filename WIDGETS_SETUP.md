# FocusGlobe Widgets — Setup

This pass adds a complete, premium **WidgetKit** widget set plus the shared
read-only data layer and deep links. All the Swift source is already written.
Because a Widget Extension is a separate Xcode *target* (its own bundle +
entitlements), the target itself must be created once in Xcode — it cannot be
created safely from source alone. Everything below is the one-time wiring.

## What was added in code

| File | Target | Purpose |
|------|--------|---------|
| `FocusGlobe/Shared/WidgetSharedData.swift` | **App** | App Group id, `WidgetSnapshot`, `WidgetGoal`, `WidgetStore` (the app writes the snapshot) |
| `FocusGlobeWidgets/WidgetData.swift` | **Widget** | Mirror of those models, compiled into the widget target (same types, same App-Group JSON) |
| `FocusGlobeWidgets/FocusGlobeWidgetBundle.swift` | Widget | The **single** `@main` widget bundle (registers all widgets) |
| `FocusGlobeWidgets/WidgetSupport.swift` | Widget | Theme, timeline provider, reusable views |
| `FocusGlobeWidgets/StreakWidget.swift` | Widget | Focus streak (S/M + Lock Screen accessories) |
| `FocusGlobeWidgets/StartJourneyWidget.swift` | Widget | Start Journey (S/M) |
| `FocusGlobeWidgets/CurrentJourneyWidget.swift` | Widget | Current / Resume journey (M/L) |
| `FocusGlobeWidgets/AroundEarthWidget.swift` | Widget | Around-Earth progress (S/M) |
| `FocusGlobeWidgets/LongestRouteWidget.swift` | Widget | Longest route (M) |
| `FocusGlobeWidgets/DailyGoalsWidget.swift` | Widget | Daily goals (M/L) |
| `FocusGlobeWidgets/PassportWidget.swift` | Widget | Passport stats (S/M) |

The app writes a `WidgetSnapshot` into the App Group whenever data changes
(`AppModel.syncWidgets()`), and calls `WidgetCenter.reloadAllTimelines()`.
The widgets read that snapshot — they never touch heavy app state.

## Widget-extension build errors — already fixed in-repo

The two earlier errors are resolved in the repository; just pull and build:

1. **`'main' attribute can only apply to one type`** — the Xcode Widget Extension
   template added its own `@main` bundle (`FocusGlobeWidgetsBundle.swift`) plus
   sample widgets (`FocusGlobeWidgets.swift`, `…Control.swift`,
   `…LiveActivity.swift`, `AppIntent.swift`). Those boilerplate files have been
   **removed**, leaving exactly one `@main`: `FocusGlobeWidgetBundle.swift`
   (it registers all seven FocusGlobe widgets). `Info.plist` and `Assets.xcassets`
   were kept.

2. **`Cannot find type 'WidgetSnapshot' / 'WidgetGoal'`** — the widget target now
   has its own copy of the models in **`FocusGlobeWidgets/WidgetData.swift`**
   (a faithful mirror of the app's `FocusGlobe/Shared/WidgetSharedData.swift`).
   Because `FocusGlobeWidgets/` is the widget target's file-system-synchronised
   group, it compiles automatically. **Do NOT** also add the app's
   `WidgetSharedData.swift` to the widget target — that would redefine the types.

3. **App Group** (the one remaining manual step) — enable
   `group.com.focusglobe.app` on **both** targets (next section). Until then the
   widgets show placeholder data; they never crash.

## App Group

- **App Group identifier:** `group.com.focusglobe.app`
- Used by `WidgetStore` (in `WidgetSharedData.swift`). Safe before setup: it
  falls back to `UserDefaults.standard`, so the app never crashes — the widgets
  just show placeholder data until the group links the two processes.

## One-time Xcode steps

1. **Create the Widget Extension target**
   - File ▸ New ▸ Target… ▸ **Widget Extension**.
   - Product name: `FocusGlobeWidgets`. Uncheck "Include Live Activity" and
     "Include Configuration App Intent" (these widgets are `StaticConfiguration`).
   - When Xcode offers to create a starter widget file, you can delete the
     generated `FocusGlobeWidgets.swift` — this repo already provides the bundle.
   - Set the widget target's **iOS Deployment Target to 17.0** (matches the app;
     required for `.containerBackground(for: .widget)`).

2. **Add the source files to the widget target**
   - Add the whole `FocusGlobeWidgets/` folder to the widget target (drag into
     the project navigator under the widget group, "Create groups", target =
     widget only).
   - Add `FocusGlobe/Shared/WidgetSharedData.swift` to the **widget target's
     membership too** (select the file ▸ File Inspector ▸ Target Membership ▸
     tick both *FocusGlobe* and *FocusGlobeWidgets*). It already compiles into
     the app via the file-system-synchronized group; this just shares it.

3. **Enable the App Group on BOTH targets**
   - Select the **app** target ▸ Signing & Capabilities ▸ **+ Capability ▸ App
     Groups** ▸ add `group.com.focusglobe.app`.
   - Repeat for the **widget** target with the **same** group id.
   - (This creates/edits each target's `.entitlements` file automatically.)

4. **Register the deep-link URL scheme (app target)**
   - App target ▸ Info ▸ **URL Types** ▸ **+** ▸ URL Schemes = `focusglobe`.
   - This lets a widget tap deliver `focusglobe://…` to `.onOpenURL`
     (already handled in `FocusGlobeApp` → `AppRouter.handleDeepLink`).
   - If you skip this, widgets still launch the app — they just open Home
     instead of deep-linking. Nothing breaks.

5. **Build & run** the widget scheme once, then add the widgets from the Home
   Screen gallery.

> The widget extension's `Info.plist` (`NSExtensionPointIdentifier =
> com.apple.widgetkit-extension`) is generated by the Widget Extension template
> in step 1 — no manual plist editing needed.

## Deep links

`focusglobe://` + one of:

| Host | Opens |
|------|-------|
| `choose` / `journey` / `start` | Choose Journey |
| `passport` / `stats` | Passport |
| `goals` / `missions` | Passport (daily goals) |
| `resume` / `current` | Home (auto-offers Resume if a journey is saved) |
| `home` (or unknown) | Home |

## Premium gating (safe, no entitlement changes)

The paywall promises "All widgets unlocked", so:

- **Start Journey** is available to everyone (it's a launcher, no private data).
- The data widgets (**Current Journey, Around Earth, Longest Route, Daily Goals,
  Passport**) read `snapshot.isPro`. Non-Pro users see a tasteful **locked
  teaser** ("Unlock with FocusGlobe Pro"); Pro users see the real content.

No subscription/pricing/entitlement logic was changed — widgets only *read* the
Pro flag the app already mirrors into the shared snapshot.
