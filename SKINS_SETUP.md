# Balloon Skins & Paywall Hero — Setup

FocusGlobe ships **10 balloon skins** plus a separate **paywall hero** image.
The code is already wired; you only need to add the image sets in Xcode.
**Missing assets never crash** — any skin without its own image falls back to
`BalloonSkin_Default`, and if even that is missing, to the crafted vector
balloon. (The legacy `BalloonFront` asset is **no longer required**.)

## Where to add the images

1. Open `FocusGlobe/Assets.xcassets` in Xcode.
2. For each name below, create a **new Image Set** (right-click → *New Image
   Set*) and name it **exactly** as listed (case-sensitive, including the
   underscore).
3. Drop your PNG into the image set (the **Universal / 1x** well is fine; add
   2x/3x if you have them).

## Recommended image format

- **PNG with a transparent background.**
- Front-view balloon, centred. Large transparent margins are fine — the app
  trims transparent pixels automatically (cached once) so the balloon fills its
  frame and the map marker.
- A roughly square canvas (e.g. 1024×1024) works well.

## Exact balloon-skin asset names

| # | Skin | Image Set name | Type | Unlock |
|---|------|----------------|------|--------|
| 1 | Default | `BalloonSkin_Default` | Free | Available from the start |
| 2 | Balloon | `BalloonSkin_Balloon` | Milestone | 10 journeys |
| 3 | Marshmallow | `BalloonSkin_Marshmallow` | Milestone | 25 journeys |
| 4 | Emoji | `BalloonSkin_Emoji` | Milestone | 50 journeys |
| 5 | Ho Ho Ho | `BalloonSkin_HoHoHo` | Milestone | 75 journeys |
| 6 | Sky Pilot | `BalloonSkin_SkyPilot` | Milestone | 100 journeys |
| 7 | Moon | `BalloonSkin_Moon` | **Premium** | Active Pro subscription |
| 8 | Galaxy | `BalloonSkin_Galaxy` | **Premium** | Active Pro subscription |
| 9 | Cloudy | `BalloonSkin_Cloudy` | **Premium** | Active Pro subscription |
| 10 | King | `BalloonSkin_King` | **Premium** | Active Pro subscription |

> `BalloonSkin_Default` is the most important one to add: it's also the
> universal fallback for any other missing skin and for the paywall hero.

## Paywall hero image

The premium paywall shows a larger hero balloon you can replace independently:

| Purpose | Image Set name |
|---------|----------------|
| Paywall hero balloon | `PaywallBalloonHero` |

- Create `PaywallBalloonHero.imageset` in `Assets.xcassets` the same way.
- If `PaywallBalloonHero` is missing, the paywall falls back to
  `BalloonSkin_Default`, then to the vector balloon. It never crashes.

## Behaviour notes

- **Milestone skins** unlock from completed journeys (landings). Locked tiles in
  the Passport show progress toward the requirement.
- **Premium skins** (Moon, Galaxy, Cloudy, King) require an **active**
  subscription *right now*. If Pro lapses they re-lock automatically, and a
  selected premium skin falls back to **Default**. Premium skins are never
  permanently unlocked.
- The selected skin is **persisted** locally and used for the Home balloon, the
  take-off ritual, the active-journey map marker and the Passport gallery.
- Tapping a locked **premium** skin opens the custom premium paywall; tapping a
  locked **milestone** skin just shows its requirement/progress.

## Fallback summary (no BalloonFront dependency)

1. The requested skin / hero asset (e.g. `BalloonSkin_Moon`, `PaywallBalloonHero`).
2. `BalloonSkin_Default`.
3. The in-code vector balloon.

The trimming/crop is applied to whichever image is used, so the balloon is
always correctly sized. No asset is required for the app to run.
