# FocusGlobe Redesign — "The Expedition"

Strategic visual + conceptual redesign to clear App Store **Guideline 4.3(a)
(Design – Spam)**. FocusGlobe stops being an "airline flight simulator" and
becomes a **vintage expedition in a hot-air balloon** — calm, warm, analog,
cozy. *Around the World in 80 Days* meets a traveler's field journal.

## Prime directives (in force for every phase)

1. **No core business-logic changes.** Timer engine, session tracking, state
   machines, persistence, StoreKit, notifications, widget data pipeline stay
   functionally identical. This is a re-skin + defined new features, not a rewrite.
2. **No internal renames.** Only user-facing strings, assets and metadata change.
   Code keeps calling things `journey`, `passport`, etc. Renaming internals is the
   #1 source of re-skin regressions.
3. **One phase at a time.** After each phase: static-validate, summarize, and hand
   over a device-verification checklist. Do not start the next phase until the
   maintainer confirms on device.
4. **Git discipline.** Work on `claude/beautiful-planck-7y5yjm` (there is no
   `main`; this branch carries the App-Review-critical IAP/build-11 work). One
   commit per completed phase. Never force-push.
5. **Do not modify** bundle identifiers, entitlements, or signing config except
   where Phase 7 explicitly requires additions.
6. **Conflicts → ask, don't improvise.**

## Environment note

The build runner is Linux (no Xcode), so the iOS project cannot be compiled here.
Each phase is written + rigorously static-validated (structure, types, API usage,
token consistency); the authoritative Xcode build + on-device verification is the
maintainer's — which fits the per-phase confirmation gate.

## Phases

- [x] **Phase 1 — Design-system foundation.** Expedition palette (paper/ink/teal/
  gold-foil/wax-seal; light "field-journal daylight" + dark "night expedition",
  no pure black/white), serif display typography, motion tokens, paper-texture
  primitives (grain, torn divider, wax seal, ink stamp). Tokens only — no layout
  changes. *(implemented + static-validated; awaiting on-device confirmation)*
- [ ] **Phase 2 — Metaphor rename (user-facing strings only).** Build an EN/ES
  localization layer (none exists today) and sweep the airline vocabulary →
  expedition vocabulary. No code-symbol renames.
- [ ] **Phase 3 — Ritual 1: the sealed expedition page.** Vintage journal page,
  ink-writing destination, dotted hand-drawn route, ink stamps; wax-seal stamp on
  confirm (impact + shake + thud + heavy haptic, ≤1.5 s, skippable); exportable
  share image.
- [ ] **Phase 4 — Ritual 2: load the basket + cut the rope.** Drag focus objects
  into the basket (spring dip); swipe to cut the tether rope (snap haptic) → the
  existing takeoff sequence. New front-end layer; same session-start code path.
- [ ] **Phase 5 — Persistent world: fog + collectible postcards.** Persistent fog
  that clears around flown routes (lightest additive schema); postcard reveal on
  completion (envelope-open, ASMR), rarity tiers, Field-Journal grid, starter art.
- [ ] **Phase 6 — Living sky (real weather & time).** In-flight sky reflects real
  local time + weather via WeatherKit, graceful time-of-day-only fallback offline;
  cached; never delays takeoff or affects the timer.
- [ ] **Phase 7 — App blocking: "leave them on the ground."** FamilyControls +
  ManagedSettings + DeviceActivity; picker in onboarding/settings; shield on start,
  removed on land/cancel/terminate; custom shield if feasible; graceful denial.
- [ ] **Phase 8 — Paywall: new pricing + expedition styling.** New product IDs
  (Annual $19.99 / 7-day trial featured, Monthly $4.99, Lifetime $39.99);
  journal-page layout, stamped benefits, gold wax seal on featured; StoreKit logic
  unchanged.
- [ ] **Phase 9 — Full QA sweep + final deliverable.** Light/dark, iPhone/iPad/Mac,
  Reduce Motion, VoiceOver, 60 fps, EN/ES, widgets, cold-start, session regression,
  FamilyControls paths. Final: change summary, screenshot list, "Notes for App
  Review."

## Status log

- **Phase 1 (design system):** done — expedition palette/type/motion/paper
  primitives. `AppColors`, `AppTypography`, `AppMotion`, `PaperTexture`,
  `ExpeditionButton`, `AppGradients`.
- **Phase 2 (metaphor rename):** done — all user-facing airline vocabulary swept
  to expedition vocabulary across Home, Route Selection, Focus, Check-in,
  In-flight, Landing, Field Journal, History, Onboarding, Settings, notifications,
  widgets. Definition-of-done grep is clean for user-facing banned terms.
  (EN only; ES localization layer not yet built — deferred.)
- **Phase 3 (Expedition Page):** done — journal page + wax-seal "Set Off"
  replaces the boarding pass; barcode deleted; "Save page" share added.
- **Banned elements:** removed — barcode, airport codes (cards, ticket, map,
  city picker, visited places), in-flight banner (+ dead file deleted), old prices.
- **Monetization:** banner removed; interstitial gated to post-landing exit and
  skipped when the rewarded "double miles" ad was watched.
- **Prices:** paywall benefits + placeholders updated (Annual 19,99 / Monthly
  4,99 / Lifetime 39,99); real prices come from StoreKit.
- **Build:** 12 (11 was burned by the rejection); marketing 1.0.

### Deferred / staged (need a device-build pass or are blocked)
- **Phase 4 (basket-load + rope-cut):** not done — the focus screen keeps its
  existing button; the drag/rope gesture is a net-new interaction to build with a
  compiler in the loop (it terminates in the same session-start path).
- **Phase 5 (fog of exploration):** not done — postcards already exist and are
  wired; the persistent fog layer is unbuilt.
- **Phase 6 (living sky / WeatherKit):** not in this respec's screen list; not done.
- **Phase 7 (app blocking / FamilyControls):** BLOCKED — the extension targets +
  entitlement were removed earlier (`FOCUS_SHIELD_PARKED.md`); re-enabling needs
  Xcode target/capability surgery in project.pbxproj that can't be compile-verified
  on this Linux runner.
- **Phase 8 (full journal-page paywall):** partial — new prices + benefits + trial
  copy done; the full journal-page relayout + wax seal on the featured plan is not
  done (kept the working dark/gold layout to protect the purchase flow).
- **Map parchment tint** (old-chart look) and the **field-note input** on landing:
  not done.
