# FocusGlobe Universal Links — what is still missing

Invitations currently ship as the custom scheme `focusglobe://join/<token>`, which
is registered in `FocusGlobe/Info.plist` and works on any device with the app
installed. **Universal Links are NOT enabled**, and this file is the exact recipe
to enable them — nothing here is active until the web side is deployed.

## Why they are not enabled

| Requirement | Status |
|---|---|
| A domain FocusGlobe actually controls | **Unverified.** `focusglobe.app` appears in the repo (`ShareService.appStoreURLString`, the referral share string, docs) but there is no evidence in this repository that it is registered, hosted, or serving. |
| `apple-app-site-association` file served over HTTPS | **Missing.** No AASA file and no web/hosting directory exist in this repository. |
| `com.apple.developer.associated-domains` entitlement | Key exists in `FocusGlobe/FocusGlobe.entitlements` but the array is still **empty**. |

> ### ✅ `associated-domains.mdm-managed` — resolved
>
> `FocusGlobe.entitlements` previously also contained:
>
> ```xml
> <key>com.apple.developer.associated-domains.mdm-managed</key>
> <true/>
> ```
>
> That key does **not** enable Universal Links. It is a separate, *restricted*
> entitlement that lets an **MDM administrator** supply associated domains to a
> managed app at runtime, and it requires an explicit grant from Apple on the App
> ID. Present but not granted, it would have kept the provisioning profile from
> including it (signing/build errors) and had an App Store Connect upload rejected
> for invalid entitlements.
>
> It was removed in `87b270b`, so this is no longer a submission blocker. What
> Universal Links need is the plain `associated-domains` array populated per
> Step 3 below — which is still an empty `<array/>`.
| `SupabaseConfig.universalLinkBaseURLString` | Deliberately `""` → `inviteURL(token:)` returns the custom scheme. |

The client code is already Universal-Link-ready: `DeepLinkService.inviteToken(from:)`
parses `https://<host>/join/<token>` today, and `SupabaseConfig.inviteURL(token:)`
switches format automatically the moment the base URL is non-empty. **No Swift
change is needed to switch over** — only the four steps below.

## Step 1 — serve the AASA file

Deploy this JSON at **both**:

- `https://focusglobe.app/.well-known/apple-app-site-association`  ← preferred
- `https://focusglobe.app/apple-app-site-association`               ← legacy fallback

Serve it with `Content-Type: application/json`, over HTTPS, with **no redirect**
and **no `.json` extension**.

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["QN8S876767.com.focusglobe.app"],
        "components": [
          {
            "/": "/join/*",
            "comment": "Private-flight invitations"
          }
        ]
      }
    ]
  }
}
```

`QN8S876767` is the Team ID configured on every target in
`FocusGlobe.xcodeproj`; `com.focusglobe.app` is the main app's
`PRODUCT_BUNDLE_IDENTIFIER`. Do not add the widget or shield extension bundle IDs —
Universal Links belong to the app target only.

## Step 2 — a web fallback page at `/join/<token>`

For a device WITHOUT the app installed, `https://focusglobe.app/join/<token>` must
render a real page (Apple opens it in Safari). It should:

- explain that this is an invitation to a FocusGlobe focus flight;
- link to the App Store listing;
- **not** display or leak the token beyond the URL itself.

The token stays in the URL, so opening the link again after installing works.

## Step 3 — add the entitlement

In `FocusGlobe/FocusGlobe.entitlements`, change the empty array to:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:focusglobe.app</string>
</array>
```

Add it to the **FocusGlobe app target only** — not to the widgets or the shield
extensions. Enable the Associated Domains capability on the App ID in the
Developer portal and regenerate the provisioning profile, or the build will fail
to sign.

## Step 4 — flip the client over

Set in `FocusGlobe/Services/Online/SupabaseConfig.swift`:

```swift
static let universalLinkBaseURLString = "https://focusglobe.app"
```

New invitations then mint `https://focusglobe.app/join/<token>`. The custom scheme
stays registered and `DeepLinkService` still accepts it, so invitations already in
circulation keep working.

## Verification

1. `curl -sI https://focusglobe.app/.well-known/apple-app-site-association`
   → `200`, `content-type: application/json`, no redirect.
2. Apple's validator: <https://search.developer.apple.com/appsearch-validation-tool/>
3. On device, delete and reinstall the app (AASA is fetched at install), then tap
   the link from Messages or Notes — **not** from Safari's address bar, which does
   not trigger Universal Links.
4. `xcrun simctl openurl booted "https://focusglobe.app/join/<token>"`

Until step 1 and step 2 are actually deployed and verified, Universal Links must
not be described as working.
