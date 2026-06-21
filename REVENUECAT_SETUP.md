# RevenueCat Setup — FocusGlobe

FocusGlobe's premium upgrade flow is powered by **RevenueCat**. All RevenueCat
code is guarded with `#if canImport(RevenueCat)` / `#if canImport(RevenueCatUI)`,
so the app **compiles and runs without the package** (it behaves as "not Pro" and
shows the built-in fallback paywall). Once you add the Swift Package below, the
native RevenueCat paywall + entitlement state light up automatically — no other
code changes needed.

## 1. Add the Swift Package (Xcode)

The package is **not** added to `project.pbxproj` automatically (doing that by
hand risks corrupting the project). Add it in Xcode:

1. Xcode → **File → Add Package Dependencies…**
2. Enter the package URL:
   ```
   https://github.com/RevenueCat/purchases-ios-spm.git
   ```
3. Choose **Up to Next Major Version** (e.g. 5.0.0 < 6.0.0).
4. Add **both** products to the **FocusGlobe** app target:
   - `RevenueCat`
   - `RevenueCatUI`
5. Build. The `#if canImport(...)` blocks now compile in and the native paywall
   is used everywhere.

(Installation reference:
https://www.revenuecat.com/docs/getting-started/installation/ios#install-via-swift-package-manager)

## 2. API key

Paste your **public** RevenueCat API key in:

```
FocusGlobe/Services/SubscriptionManager.swift  →  static let apiKey = "..."
```

It is configured once at launch from `AppModel.init()` via
`subscriptions.configure()`. Configuration is non-blocking and is skipped if the
key is empty or still a placeholder.

## 3. Entitlement

Create one entitlement in the RevenueCat dashboard, named **exactly**:

```
FocusGlobe Pro
```

This entitlement unlocks:
- **Ultra** journeys (Short / Deep / Long stay free).
- Premium balloon skins.

The id is referenced once: `SubscriptionManager.entitlementID`.

## 4. Products / offering

Create these products (App Store Connect) and attach them to your RevenueCat
**Offering** + **Paywall**:

| Role     | Product identifier |
|----------|--------------------|
| Lifetime | `lifetime`         |
| Yearly   | `yearly`           |
| Monthly  | `monthly`          |

Map all three to the **FocusGlobe Pro** entitlement. Build the paywall in the
RevenueCat **Paywalls** editor — the app renders it natively, so prices/copy come
from the dashboard (nothing is hardcoded in the app).

(Paywalls: https://www.revenuecat.com/docs/tools/paywalls ·
Displaying: https://www.revenuecat.com/docs/tools/paywalls/displaying-paywalls)

## 5. Where the paywall appears

Every premium trigger calls `router.presentPaywall()`, which presents
`PaywallContainerView` as a sheet → the RevenueCat paywall (or the built-in
fallback when the package isn't linked). Triggers:

- Crown button on **Home** and **Choose Journey**.
- **Ultra** journey lock ("Unlock with Pro").
- Premium **balloon skins** in Passport.
- "Remove ads & go Pro" in **Settings**.
- The one-time premium intro on first Home.

After purchase/restore, `SubscriptionManager` receives the updated `CustomerInfo`
(via `customerInfoStream`) and flips `isPro`, which `AppModel` mirrors so Ultra +
skins unlock immediately.

## 6. Customer Center

When RevenueCatUI is linked and the user is Pro, **Settings → FocusGlobe Pro**
shows a **Manage subscription** row that presents RevenueCat's native
`CustomerCenterView` (billing, restore, support). It's hidden otherwise so
Settings stays clean.

(Customer Center: https://www.revenuecat.com/docs/tools/customer-center ·
Customer Info: https://www.revenuecat.com/docs/customers/customer-info)

## 7. Testing in Sandbox

1. Add a **Sandbox tester** in App Store Connect and sign into it on the device
   (Settings → App Store → Sandbox Account, or sign in when prompted at purchase).
2. Ensure products are **Ready to Submit** and linked to the offering.
3. Run the app, tap any crown / Ultra journey → the paywall appears.
4. Purchase → the app should unlock Ultra + premium skins immediately.
5. Reset: delete the app or use **Settings → Developer → Reset local data**
   (note: this clears local mock state; the real entitlement comes from
   RevenueCat and re-asserts on next launch).

## 8. Graceful degradation

- If offerings fail to load, the RevenueCat paywall shows its own error/retry
  state and the rest of the app keeps working.
- If customer info fails to refresh, the app keeps running (Pro simply stays at
  its last known value); errors are only surfaced when the user initiates a
  purchase/restore.
- Without the package, the built-in `PaywallView` fallback is used and Pro is
  driven by the local mock (`PurchaseService`) for development.
