# FocusGlobe — Premium UI Sounds (Earcons)

A subtle, premium **UI interaction sound** layer, kept cleanly separate from the
ambient journey audio.

## Two distinct audio layers

| Layer | Service | What it is |
|-------|---------|------------|
| Ambient journey audio | `SoundService` | The looping wind/music during a flight (AVAudioSession `.playback`). |
| **UI earcons** | `UISoundService` | Short one-shot interaction sounds, played via AudioToolbox so they **mix over** the ambient loop (never duck/stop it). |

Both respect the master **Sound** setting (`AppSettings.soundEnabled`): `AppModel`
keeps `uiSound.isEnabled` in sync, so muting Sound silences earcons and ambient
alike. **Missing assets never crash** — each earcon falls back to a tasteful
built-in iOS system sound.

## Where earcons play

| Moment | Earcon | Call site |
|--------|--------|-----------|
| Start Journey / select a journey card | `transition` | `HomeView`, `RouteSelectionView` |
| Open paywall (crown) / open streak sheet | `modal` / `transition` | `HomeView` |
| Focus token dropped into the basket | `focusDrop` | `PreBoardingFocusView` |
| Confirm focus | `confirm` | `PreBoardingFocusView` |
| Tear the boarding ticket | `ticketTear` | `BoardingView` |
| Take-off / journey begins | `journeyStart` | `FocusSessionViewModel` |
| Arrive / land | `landing` | `FocusSessionViewModel` |
| Claim miles / reward | `claim` | `LandingView`, `AppModel` (daily reward) |
| (reserved) generic tap | `tap` | available via `appModel.uiSound.play(.tap)` |

Deliberately restrained — only meaningful premium moments, not every tap.

## Optional sound assets (works without them)

The layer is **premium-ready immediately** using built-in iOS system sounds (the
soft "tock/tink" family — never loud alert tones). To upgrade to bespoke sounds,
drop audio files into the **app** bundle with these exact names (no code change):

| File name (any one extension) | Plays on |
|-------------------------------|----------|
| `UISoundTap` | generic key tap |
| `UISoundTransition` | entering a key screen / opening a sheet (also used for `modal`) |
| `UISoundDrop` | focus token snaps into the basket |
| `UISoundSuccess` | confirm focus / commit |
| `UISoundTakeoff` | take-off / journey start |
| `UISoundTicketTear` | tearing the boarding ticket |
| `UISoundLanding` | landing |
| `UISoundClaim` | claiming miles / a reward |

- **Accepted extensions** (searched in order): `.caf`, `.aif`, `.aiff`, `.wav`, `.m4a`.
  `.caf` is recommended for short system sounds.
- **Where to put them:** add the files to the **app target** (drag into Xcode,
  Target Membership = *FocusGlobe*). `Bundle.main` resolves them by name.
- **Design guidance:** very short (< 0.4 s), soft, glassy, clean transient —
  premium, never game-like. Each is independently replaceable; if a named file is
  absent, that earcon uses its built-in system fallback (partial sets are fine).
