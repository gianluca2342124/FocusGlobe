# RevenueCat Setup — FocusGlobe

The premium upgrade flow is a **custom gold FocusGlobe paywall** (`PaywallView`)
that drives RevenueCat purchases underneath. The RevenueCatUI **template
paywall is not used** for the main screen — RevenueCatUI is only used for the
optional **Customer Center** in Settings.

All RevenueCat code is guarded with `#if canImport(RevenueCat)` /
`#if canImport(RevenueCatUI)`, so the app still compiles/runs if the SDK is
absent or offerings fail to load (plans fall back to disabled placeholders and
the app behaves as "not Pro").

## Dashboard configuration

- **Offering:** `default` (the code uses `offerings.current`, falling back to
  `offerings.all["default"]`).
- **Entitlement (identifier checked in code):** `FocusGlobe Pro`
  - REST API ID (reference only): `entldabe1bce7f`
  - The code checks `customerInfo.entitlements["FocusGlobe Pro"]`. As a safety
    net it also treats **any** active entitlement as Pro (FocusGlobe ships a
    single entitlement), so it stays correct even if the dashboard identifier
    differs from the display name. **Verify** the entitlement *identifier* in the
    dashboard matches `SubscriptionManager.entitlementID` — change that one
    constant if it differs.
- **Products** (mapped to the `FocusGlobe Pro` entitlement):

  | Plan     | Product identifier        | REST API ID (reference) |
  |----------|---------------------------|-------------------------|
  | Annual   | `subscription_annually`   | `prod546ae7419f`        |
  | Lifetime | `subscription_lifetime`   | `prodfd0bad48c5`        |
  | Monthly  | `subscription_monthly`*   | —                       |

  *Monthly is matched by product identifier `subscription_monthly` **or** by
  RevenueCat `packageType == .monthly`, so a differently-named monthly product in
  the `default` offering still maps correctly. If your monthly product uses a
  different identifier, set `SubscriptionManager.monthlyProductID`.

Purchases use the SDK `Package`/`StoreProduct` from the fetched offering — **no
REST API IDs are passed to purchase calls**. The IDs above are for debugging.

## API key

Paste your **public** RevenueCat API key in
`FocusGlobe/Services/SubscriptionManager.swift` → `static let apiKey`. It's
configured once at launch from `AppModel.init()` (non-blocking).

## The custom paywall

`PaywallView` (`FocusGlobe/Features/Paywall/PaywallView.swift`):

- Dark/gold luxury look with soft animated gold blobs and the FocusGlobe balloon
  (`BalloonView` — swap the image asset later; the reference is kept clean).
- Title **"Unlock All Features"**, benefit rows, and three plans:
  - **Annually** (selected by default, `-60%` badge, shows the localized annual
    price + a localized "/month" equivalent = annual price ÷ 12). Button:
    **"Start 7 days free trial"**.
  - **Lifetime** ("Pay once."). Button: **"Continue"**.
  - **Monthly**. Button: **"Continue"**.
- A gold purchase button (loading state, double-tap-proof) and a footer with
  **Privacy · Terms · Restore**. Privacy/Terms URLs are centralised placeholders
  in `LegalLinks` (`FocusGlobe/Services/LegalLinks.swift`) — replace
  `LegalLinks.privacy` / `LegalLinks.terms` before release. See
  APP_STORE_READINESS.md.
- All prices are the App Store **localized** prices from RevenueCat. The expected
  EU base prices (18,99 € / 35,99 € / 3,99 € → 1,58 €/month) only appear as
  disabled placeholders when products can't load.

Every premium trigger (Home/Choose Journey crown, Ultra lock, "Unlock with Pro",
premium skins, first-launch intro) calls `router.presentPaywall()`, which
presents this one screen.

## Centralized state — `SubscriptionManager`

`customerInfo`/entitlement, `offerings`, localized `plans`, `isPro`,
`isLoading`, `isPurchasing`, `errorMessage`, plus `configure()`,
`loadOfferings()`, `refreshCustomerInfo()`, `purchase(_:)`, `restorePurchases()`.
`AppModel` mirrors `isPro` so Ultra journeys + premium skins unlock immediately
after purchase/restore. Gating is unchanged: **only Ultra requires Pro**;
Short/Deep/Long are free.

## Customer Center

When RevenueCatUI is linked and the user is Pro, **Settings → FocusGlobe Pro**
shows a **Manage subscription** row that presents `CustomerCenterView`.

## Testing in Sandbox

1. Sign into a **Sandbox tester** (App Store Connect) on the device.
2. Ensure the three products are **Ready to Submit** and attached to the
   `default` offering + the `FocusGlobe Pro` entitlement.
3. Run, open any crown / Ultra journey → the custom paywall appears with live
   localized prices.
4. Purchase → Pro unlocks immediately (Ultra + premium skins).
5. **Restore** uses the Apple account and refreshes `CustomerInfo`.

## Verify in App Store Connect / RevenueCat

- The three products exist, are approved/Ready, and are in the `default`
  offering as packages.
- The annual product has the **7-day free trial** introductory offer (the button
  copy promises it).
- The `FocusGlobe Pro` entitlement is attached to all three products.
