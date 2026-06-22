# Journey Audio — Setup

FocusGlobe plays a **looping ambience during an active journey**. The code is
already wired; you only need to add the audio files in Xcode and (once) enable
the background-audio capability. **Missing audio files never crash** — if a
file isn't found the app plays a built-in **procedural soft-wind loop** instead,
so the feature works before you add anything.

## Default vs premium

- **Wind** (`JourneyAudioWind`) is the **free default**, available to everyone.
  It should be a **soft, relaxing hot-air-balloon ambience** — calm air / quiet
  high-altitude drifting, *not* harsh wind noise. Until you add the file, it is
  generated procedurally; that fallback is tuned soft (heavily low-passed, slow
  gentle swell, calm volume) so it already feels relaxing.
- The rest require an **active** Pro subscription. If Pro lapses, a selected
  premium sound re-locks and falls back to **Wind**. Premium audio is never
  permanently unlocked.

## Exact audio asset names

| Sound | File name (no extension) | Type |
|-------|--------------------------|------|
| Wind | `JourneyAudioWind` | Free / default |
| Focus Music | `JourneyAudioFocusMusic` | Premium |
| Alpha Waves | `JourneyAudioAlphaWaves` | Premium |
| Rain | `JourneyAudioRain` | Premium |
| Ocean | `JourneyAudioOcean` | Premium |
| Relaxing | `JourneyAudioRelaxing` | Premium |
| Jazz | `JourneyAudioJazz` | Premium |

## Supported file extensions

The player searches `Bundle.main` for each name in this order:

1. `.mp3`
2. `.m4a`
3. `.wav`
4. `.caf`

Name the file exactly `JourneyAudioWind.mp3` (etc.). Use seamless loops — the
player loops them continuously (`numberOfLoops = -1`).

## Where to add the audio files in Xcode

Add them as **bundle resources** (not inside `Assets.xcassets`):

1. Drag the audio files into the Xcode Project Navigator (e.g. into the
   `FocusGlobe` group; you may create an `Audio` group/folder).
2. In the add dialog: tick **Copy items if needed** and, under
   *Add to targets*, tick **FocusGlobe**.
3. Verify they're included: select the **FocusGlobe** target →
   **Build Phases → Copy Bundle Resources** and confirm each audio file is
   listed.

That's all the code needs — files are loaded by name from the main bundle.

## Enable background audio (do this once)

So audio keeps playing while the app is in the background **during a journey**:

1. Select the **FocusGlobe** target → **Signing & Capabilities**.
2. Click **+ Capability** → add **Background Modes**.
3. Enable **“Audio, AirPlay, and Picture in Picture.”**

This adds `UIBackgroundModes = [audio]` to the build settings / Info.plist.
The code already configures `AVAudioSession` with the `.playback` category, so
once the capability is on, background playback works. Without the capability the
app still runs fine — audio simply pauses when backgrounded.

> The project uses an auto-generated Info.plist (no checked-in `Info.plist`
> file), so add the capability via the Xcode UI above rather than editing a
> plist by hand.

## Behaviour summary (already implemented)

- Journey **start** → audio begins looping (only if the **Sound** setting is on).
- Journey **pause** → audio pauses; **resume** → audio resumes.
- Journey **cancel / land / end** → audio stops.
- App **backgrounded** during a journey → audio continues (with the capability).
- **Sound** toggle in Settings is the master on/off switch.
- Interruptions (calls / Siri) pause audio and resume when the system allows;
  unplugging headphones pauses audio (it won't blast from the speaker).
- **No microphone permission is requested** — this is playback only. Do **not**
  add `NSMicrophoneUsageDescription`.

## Choosing the audio (UI)

**Passport → Journey sound** (at the bottom) lists Wind (free) and the premium
options as colourful sound cards. The selected option shows a check; locked
premium options show a gold crown and open the custom paywall when tapped. The
selection is **persisted** locally. During an active journey, a speaker button
mutes/unmutes the audio without stopping it (the global Sound toggle in Settings
remains the master switch).
