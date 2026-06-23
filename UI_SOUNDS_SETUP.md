# FocusGlobe — Premium UI Sounds (Earcons)

This pass adds a subtle, premium **UI interaction sound** layer, kept cleanly
separate from the ambient journey audio.

## Two distinct audio layers

| Layer | Service | What it is |
|-------|---------|------------|
| Ambient journey audio | `SoundService` | The looping wind/music during a flight (AVAudioSession `.playback`). Unchanged. |
| **UI earcons** | `UISoundService` | Short one-shot interaction sounds, played via AudioToolbox so they **mix over** the ambient loop (never duck/stop it). |

Both respect the master **Sound** setting (`AppSettings.soundEnabled`):
`AppModel` keeps `uiSound.isEnabled` in sync, so muting Sound silences earcons
and ambient alike.

## Where earcons play

| Moment | Earcon | Call site |
|--------|--------|-----------|
| Start Journey CTA (Home) | `transition` | `HomeView` |
| Open paywall (crown) | `modal` | `HomeView` |
| Focus token dropped into the basket | `focusDrop` | `PreBoardingFocusView.assign` |
| Confirm focus | `confirm` | `PreBoardingFocusView.confirm` |
| Tear the boarding ticket | `ticketTear` | `BoardingView.commitTear` |
| Take-off / journey begins | `journeyStart` | `FocusSessionViewModel.start` |
| Arrive / land | `landing` | `FocusSessionViewModel.land` |
| (reserved) generic tap | `tap` | available via `appModel.uiSound.play(.tap)` |

Deliberately restrained — only meaningful premium moments, not every tap.

## Sound assets (optional — works without them)

The layer is **premium-ready immediately** using tasteful built-in iOS system
sounds (the soft "tock/tink" family — never loud alert tones). To upgrade to
bespoke sounds later, just drop audio files into the **app** bundle with these
exact names (no code change needed):

| File name (any one extension) | Plays on |
|-------------------------------|----------|
| `ui_tap` | generic tap |
| `ui_transition` | entering a key screen |
| `ui_focusDrop` | token snaps into the basket |
| `ui_confirm` | confirm focus / commit |
| `ui_journeyStart` | take-off |
| `ui_ticketTear` | tearing the ticket |
| `ui_landing` | landing |
| `ui_modal` | opening an important modal |

- **Accepted formats** (searched in order): `.caf`, `.aif`, `.aiff`, `.wav`, `.m4a`.
  `.caf` is recommended for short system sounds.
- **Where to put them:** add the files to the **app target** (drag into Xcode,
  ensure Target Membership = *FocusGlobe*). `Bundle.main` resolves them.
- **Design guidance:** keep them very short (< 0.4 s), soft, glassy, clean
  transient — premium, never game-like. Each is independently replaceable.
- If a named file is absent, that earcon automatically uses its built-in system
  fallback, so partial sets are fine.
