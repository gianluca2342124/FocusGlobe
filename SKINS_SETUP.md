# Balloon Skins — Setup

FocusGlobe ships **10 balloon skins**. The code is already wired; you only need
to add the image assets in Xcode. **Missing assets never crash** — any skin
without its own image gracefully falls back to the default `BalloonFront`
artwork, and if even that is missing, to the crafted vector balloon.

## Where to add the images

1. Open `FocusGlobe/Assets.xcassets` in Xcode.
2. For each skin, create a **new Image Set** (right-click → *New Image Set*) and
   name it **exactly** as listed below (case-sensitive).
3. Drop your PNG into the image set (the **Universal / 1x** well is fine; add
   2x/3x if you have them).

> The existing `BalloonFront.imageset` is the reference for how an image set
> looks in this catalog.

## Recommended image format

- **PNG with a transparent background.**
- Front-view balloon, centred. Large transparent margins are fine — the app
  trims transparent pixels automatically (cached once) so the balloon fills its
  frame and the map marker, exactly like `BalloonFront`.
- A roughly square canvas (e.g. 1024×1024) works well.

## Exact asset names

| # | Skin | Asset name (Image Set) | Type | Unlock |
|---|------|------------------------|------|--------|
| 1 | Default | `BalloonSkinDefault` | Free | Available from the start |
| 2 | Balloon | `BalloonSkinBalloon` | Milestone | 10 completed journeys |
| 3 | Marshmallow | `BalloonSkinMarshmallow` | Milestone | 25 completed journeys |
| 4 | Emoji | `BalloonSkinEmoji` | Milestone | 50 completed journeys |
| 5 | Ho ho ho! | `BalloonSkinHoHoHo` | Milestone | 75 completed journeys |
| 6 | Sky Pilot | `BalloonSkinSkyPilot` | Milestone | 100 completed journeys |
| 7 | Moon | `BalloonSkinMoon` | **Premium** | Active Pro subscription |
| 8 | Galaxy | `BalloonSkinGalaxy` | **Premium** | Active Pro subscription |
| 9 | Cloudy | `BalloonSkinCloudy` | **Premium** | Active Pro subscription |
| 10 | King | `BalloonSkinKing` | **Premium** | Active Pro subscription |

## Behaviour notes

- **Milestone skins** unlock from completed journeys (landings). Locked tiles in
  the Passport show progress toward the requirement.
- **Premium skins** (Moon, Galaxy, Cloudy, King) require an **active**
  subscription *right now*. If Pro lapses they re-lock automatically, and if the
  currently selected skin becomes unavailable it falls back to **Default**.
  Premium skins are never permanently unlocked.
- The selected skin is **persisted** locally and used for the Home balloon, the
  take-off ritual, the active-journey map marker and the Passport gallery.
- Tapping a locked **premium** skin opens the custom premium paywall; tapping a
  locked **milestone** skin just shows its requirement/progress.

## Fallback summary

- `BalloonSkinX` missing → uses `BalloonFront`.
- `BalloonFront` also missing → uses the in-code vector balloon.
- The marker crop/alpha trimming is applied to whichever image is used, so the
  balloon is always correctly sized. No asset is required for the app to run.
