# FocusGlobe — Widget Design System

The FocusGlobe widgets are designed to feel like a premium, App-Store-featured
set — iconic, glanceable and emotionally motivating (in the spirit of Duolingo,
Flighty, Gentler Streak and Widgetsmith), while staying lightweight and safe.

**North star:** a deep-space travel aesthetic — navy→black gradients, a faint
starfield, soft gold/blue glows, large iconic vector art (flame, globe, balloon,
a stylized route map), very little text, and strong visual hierarchy.

Everything here is **pure SwiftUI vector art** — there are **no bundled images
and no MapKit inside the widgets**. That keeps the extension tiny, reliable and
App Store-safe, and means nothing "jumps" between timeline renders (all art is
deterministic). This is the deliberate "Option B" choice: reliability and visual
quality over technical complexity.

---

## 1. Identity & palette

Colours live in `WTheme` (`WidgetSupport.swift`) — the widget target can't import
the app's design system, so it carries a small, self-contained palette:

| Token | Use |
|-------|-----|
| space gradient `0.06,0.09,0.17 → 0.02,0.03,0.07` | the backdrop |
| `WTheme.gold` | balloon, primary accent, miles, CTAs |
| `WTheme.coral` | streak / flame, "at-risk" warmth |
| `WTheme.teal` | Earth ring, progress |
| `WTheme.sky` | journeys / in-flight |
| `WTheme.indigo` | passport / default glow |
| `WTheme.ink` / `inkSoft` / `hair` | text + hairlines on dark |

Each widget tints its corner glow to its theme via
`fgWidgetBackground(glow:)` (streak→coral, journey→sky, earth→teal, start→gold,
goals/passport→indigo).

---

## 2. Component library — `WidgetVisuals.swift`

A reusable kit of deterministic vector components. Build new widgets from these
rather than re-drawing art.

| Component | What it is |
|-----------|------------|
| `WStarfield` | A `Canvas` starfield with a fixed xorshift seed (never twinkles between renders). |
| `WSpace` | The shared deep-space backdrop: navy→black gradient + starfield + a tinted glow + a gold glow. Rendered by `fgWidgetBackground(glow:)`. |
| `WGlassCard` | A glassmorphism rounded card (`.ultraThinMaterial` + white wash + hairline border) for grouping content. |
| `WFlame` | The streak hero — a glowing flame with the count over it. `streak == 0` → a calm dim **ember** (an invitation, never guilt); `atRisk` adds a warmer halo. |
| `WEarth` | A layered illustrated globe (atmosphere glow, ocean gradient, abstract land, terminator highlight, rim), optionally wrapped by a progress ring + an orbiting balloon. |
| `WBalloon` | A vector hot-air balloon with a soft halo — the brand mascot. |
| `WStylizedMap` | The "route on the map" hero: deep sea gradient, soft coastlines, a faint graticule, and a glowing dashed route arc with origin/destination dots and the balloon placed at `progress` along the arc (quadratic bezier). |
| `WDayDots` | A row of 7 day dots — lit for active streak days, today highlighted. |
| `WPill` | A compact CTA pill ("Take off", "Start journey"). |

Plus the primitives in `WidgetSupport.swift`: `WHeader`, `WBar`, `WRing`,
`WStat`, `LockedTeaser`, and formatting helpers (`Int.fgGrouped`,
`String.fgCityCode`, `fgDuration`).

---

## 3. The widgets

All home-screen widgets share the space backdrop; the journey widgets use the
stylized map as their full-bleed background instead. Lock-screen accessories use
`AccessoryWidgetBackground()` and a `.clear` container.

| Widget | Kind | Families | Hero visual | Deep link |
|--------|------|----------|-------------|-----------|
| **Streak** | `FGStreak` | S, M, accessories | `WFlame` (+ `WDayDots` on M) | `streak` |
| **Current Journey** | `FGCurrentJourney` | S, M, L | `WStylizedMap` + balloon at progress | `resume` / `choose` / `pro` |
| **Start a Journey** | `FGStartJourney` | S, M, L | `WBalloon` + `WPill` | `choose` |
| **Around Earth** | `FGAroundEarth` | S, M, L | `WEarth` + ring + orbit balloon | `passport` / `pro` |
| **Daily Goals** | `FGDailyGoals` | S, M, L | `WGlassCard` mission cards | `goals` / `pro` |
| **Passport** | `FGPassport` | S, M, L | `WBalloon` (current skin) + stats | `passport` / `pro` |
| **Longest Route** | `FGLongestRoute` | M, L | `WStylizedMap` landed at destination | `passport` / `pro` |

### Behaviour highlights

- **Streak** — the number lives *inside* the flame; almost no text. At `0` it's a
  dim ember ("Light your flame"); when the streak is alive but nothing's done
  today it warms with an *urgency-not-guilt* nudge ("Keep it alive"). Medium adds
  the 7-day dots, one motivational line, and a "Best · N days" record.
- **Current Journey** — the most important visual. The map shows the route with
  the balloon sitting at the real progress; overlays show the route codes
  (`SFO ⋯ LAX`), percent, time left and km-to-go. With no active journey it's a
  calm "Ready for takeoff" with a balloon + CTA.
- **Start a Journey** — a one-tap launcher (everyone): big glowing balloon, the
  departure code, "Take off".
- **Around Earth** — the illustrated globe with a teal progress ring and an
  orbiting balloon; the laps figure (`0.30× around`) and total km.
- **Daily Goals** — one hero mission (S), three glass mission cards with mini
  rings (M), the full list + bonus-reward line (L).
- **Passport** — a collectible: the current balloon skin as the hero, plus miles
  / landings / postcards / streak.
- **Longest Route** — the proudest completed flight, landed on the map.

### Premium gating

Non-Pro users see a tasteful `LockedTeaser` (never a broken/empty state) that
deep-links straight to the paywall (`focusglobe://pro`). **Start Journey** and
**Streak** are open to everyone.

---

## 4. Data — the shared snapshot

Widgets render a read-only `WidgetSnapshot` the app writes into the App Group
`group.com.focusglobe.app` (`AppModel.syncWidgets()` → `WidgetStore`). The model
is defined **twice, byte-for-byte identically**:

- `FocusGlobe/Shared/WidgetSharedData.swift` (app target — writes)
- `FocusGlobeWidgets/WidgetData.swift` (widget target — reads)

Fields added for this redesign (all with Codable defaults):
`longestStreak`, `selectedSkinName`, `resumeOriginCode`, `resumeDestinationCode`,
`resumeRouteKm`.

### Backwards-compatible decoding

`WidgetSnapshot` has a **resilient custom `init(from:)`**: every field falls back
to its default when missing or malformed, so a snapshot written by an older (or
newer) app version always decodes — it never throws, never crashes, and never
wipes the widget as the schema evolves. Encoding stays synthesized (always writes
the full schema). When you add a field, add it in **both** copies and to
`.placeholder`, then populate it in `AppModel.makeWidgetSnapshot()`.

### Preview data

Every widget ships `#Preview`s using `WidgetSnapshot.placeholder` (realistic
data: San Francisco · SFO→LAX · 42 min · 559 km · streak 4 / best 9 · 12,022 km ·
18 landings · skin "King") plus state variants (`previewIdle`, `previewEmpty`).

---

## 5. Constraints honoured

- ✅ One `@main` `WidgetBundle` (`FocusGlobeWidgetBundle`) — no duplicates.
- ✅ Widget target imports **only** SwiftUI / WidgetKit / Foundation — no app
  frameworks, no `AppModel`/`DesignSystem`, no Google Maps / MapKit / RevenueCat.
- ✅ No bundled images and no live MapKit views — pure vector, timeline-driven.
- ✅ No backend / Supabase / Firebase / login — read-only App Group snapshot.
- ✅ App Group `group.com.focusglobe.app` and the `WidgetStore`/`WidgetSnapshot`
  contract are unchanged in shape (only additive fields).
- ✅ Safe before setup — `WidgetStore` falls back to `.standard` and the resilient
  decoder returns a default snapshot, so widgets show placeholders, never crash.

---

## 6. Extending the system

1. Build the new widget's art from `WidgetVisuals` components on `WSpace`
   (`fgWidgetBackground(glow:)`), or the stylized map for journey widgets.
2. Use `FGProvider` (the shared 30-minute timeline) and read `entry.snapshot`.
3. Gate Pro content with `snapshot.gatedLink(_:)` / `LockedTeaser`.
4. Add any new data as additive Codable fields in **both** model copies, update
   `.placeholder`, and populate it in `AppModel.makeWidgetSnapshot()`.
5. Register the widget in `FocusGlobeWidgetBundle` and add `#Preview`s.
6. Keep text minimal and the art large — the visual is the message.
