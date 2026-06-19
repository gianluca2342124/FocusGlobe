# Location setup (one manual step)

FocusGlobe now starts every journey from the user's **real current location**
(`LocationService` → reverse-geocoded city → `JourneyOrigin`). For iOS to show
the permission prompt, the app needs a *When In Use* usage string.

This project generates its `Info.plist` from build settings
(`GENERATE_INFOPLIST_FILE = YES`) and the Xcode project file is managed
manually, so this key must be added **once** in Xcode. The app builds and runs
without it — it simply keeps the calm default city (`JourneyOrigin.default`,
Barcelona) until the key is present and permission is granted.

## Add the usage string

In Xcode, select the **FocusGlobe** target → **Build Settings** → search for
“Info.plist”, and add a custom key (or use the **Info** tab):

```
Key:   Privacy - Location When In Use Usage Description
       (INFOPLIST_KEY_NSLocationWhenInUseUsageDescription)
Value: FocusGlobe begins each journey from where you are, so it can
       show your city and drift you toward your chosen destination.
```

Equivalent build-setting line (Debug **and** Release):

```
INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "FocusGlobe begins each journey from where you are, so it can show your city and drift you toward your chosen destination.";
```

## How it behaves

The app never silently presents a fake city as if it were the user's real
location.

| State | Result |
| --- | --- |
| Key present, permission **granted** | Real location → reverse-geocoded city + country (e.g. “Barcelona”). *(normal path)* |
| Key present, permission **denied / restricted** | Home shows a clean “Choose your city” state with a **Choose starting city** CTA (no fake origin). |
| Key **missing** | Same clean “choose a city” state; the app still runs fully. |
| User picks a city manually | That city becomes the origin (persisted) until they tap **Use my current location**. |

`requestWhenInUseAuthorization()` is triggered calmly from the Home screen on
first appearance (`HomeView.onAppear → appModel.requestLocation()`).

### Testing in the Simulator

The iOS Simulator reports Apple HQ (San Francisco) as its location by default.
To test other origins without changing the simulator, open **Settings →
Starting location** (or tap the location pill on Home) and pick a preset city
(Barcelona, Paris, London, New York, Tokyo, …). Choosing **Use my current
location** clears the override.
