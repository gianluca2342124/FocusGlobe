# FocusGlobe localization

## Status: English only, deliberately

FocusGlobe ships in **English**. Spanish and Italian are fully authored for the
first-run onboarding and the paywall, but neither is offered to a pilot, and
neither appears in the App Store listing.

That is not an oversight. The rule the whole architecture enforces is:

> Never show a language as selectable if the pilot will immediately encounter
> untranslated major screens.

A pilot who picks *Español* on the welcome screen, answers eight questions in
Spanish, reads a Spanish plan, and then taps "Empezar mi primer vuelo" and lands
on an entirely English Home screen has been misled by the app. That is worse
than never having offered Spanish.

## How the gate works

Nothing about the gate is hand-maintained. It is computed from two mechanical
inputs, both in code:

1. **`LocalizationSurface.routesThroughStringTable`** — whether a surface's
   user-facing text goes through `FocusStringTable` at all. A screen built from
   Swift string literals cannot be translated by adding table entries, so no
   number of translated keys can make it count.
2. **`FocusStringTable.missingKeys(for:surface:)`** — whether that language
   actually supplies every key.

`LocalizationCoverage.isReleaseReady(_:)` requires **every** surface to be
`complete`. `AppLanguage.selectable` filters on that, and
`AppLanguage.offersLanguageChoice` is false while fewer than two languages
qualify — at which point `LanguagePicker` renders *nothing*, in both Settings
and onboarding. There is no separate "hide the picker" flag that could drift out
of step with reality.

`LocalizationCoverage._selfCheck()` runs at every Debug launch and fails the
assertion if a language is ever selectable without being release-ready.

## Current coverage

| Surface | English | Español | Italiano |
| --- | --- | --- | --- |
| Onboarding | complete | complete | complete |
| Paywalls | complete | complete | complete |
| Home | complete | not routed | not routed |
| Flight setup | complete | not routed | not routed |
| Active journey | complete | not routed | not routed |
| Store | complete | not routed | not routed |
| Passport | complete | not routed | not routed |
| Friends | complete | not routed | not routed |
| Settings | complete | not routed | not routed |
| Account & sign-in | complete | not routed | not routed |
| Widgets | complete | not routed | not routed |
| Screen Time shield | complete | not routed | not routed |
| Notifications | complete | not routed | not routed |

*"not routed"* means the surface still builds its text from Swift string
literals. The Debug launch prints this same table from
`LocalizationCoverage.manifest()`, so the document and the binary cannot
disagree for long.

**Español: NOT release-ready. Italiano: NOT release-ready.**

## What already works

* `AppLanguage` — `.system` (default), `.english`, `.spanish`, `.italian`.
  `.system` is a real, distinct value: it resolves against
  `Locale.preferredLanguages` at read time and will pick up a newly-completed
  language with no migration.
* **Persistence** — `AppSettings.languageID`, inside the existing canonical,
  account-scoped snapshot. The anonymous profile keeps its own choice; signing
  in carries it across exactly like every other preference.
* **Root injection** — `RootView().focusLanguage(appModel.language)` sets both
  `\.focusStrings` and `\.locale` at the window root. A change takes effect on
  the next frame: no relaunch, no cache to invalidate.
* **Regional formatting** — `.system` injects `Locale.autoupdatingCurrent`, so a
  pilot in Italy reading English still gets Italian dates, 24-hour time and
  comma decimals. Only an explicit choice overrides regional formatting.
* **Widgets** — `WidgetSnapshot.languageCode` carries the resolved code across
  the App Group, so the extension can follow once its own copy is translated.
* **`LanguagePicker`** — one component, two styles, used by Settings and the
  welcome screen, hidden by the same gate in both.

## Remaining release task: activating Español and Italiano

This is a discrete, sizeable piece of work. It is **not** blocked by anything in
the architecture.

1. **Route the remaining eleven surfaces through `FocusStringTable`.** For each,
   add its keys to `FocusStringKey` under a new prefix, extend
   `FocusStringKey.surface`, replace the literals in its views, then flip
   `routesThroughStringTable` to `true` for that surface. English entries are
   asserted complete at launch, so a missed key fails immediately in Debug
   rather than shipping.
2. **Translate those keys into `spanish` and `italian`.** Missing keys fall back
   to English rather than rendering a raw key, and `missingKeys(for:)` reports
   exactly what is outstanding.
3. **Translate the extension targets separately.** The widgets and the Screen
   Time shield run in their own processes with their own bundles. They cannot
   read `\.focusStrings`; the widgets read `WidgetSnapshot.languageCode`, and
   the shield extension will need its own copy of the relevant strings.
4. **Translate the notification bodies** in `NotificationService`. These are
   composed at schedule time, so a language change must reschedule them.
5. **Only then**: add `es` and `it` to the project's `knownRegions`, and add the
   localizations to the App Store listing. Doing this earlier publishes an
   availability claim the binary cannot keep, and unlike a runtime flag, a store
   listing cannot be taken back on the next frame.

Once step 1 and 2 are done for every surface, `isReleaseReady` becomes true on
its own and the picker appears — no flag to remember to flip.

## Why a compiled-in table rather than `.lproj` / String Catalogs

Two reasons, both about the failure mode rather than convenience:

* Adding `es`/`it` to `knownRegions` is what publishes the store-listing claim.
  Keeping the strings in Swift lets the translations be written, reviewed and
  regression-tested *before* the app claims to support the language.
* A missing key in a `.strings` file renders the **key** on a customer's screen.
  Here it falls back to English, and the gap is reported by
  `missingKeys(for:)` instead of being discovered by a customer.

The migration to a String Catalog, when the time comes, is mechanical: the keys,
the placeholder contracts and the coverage gate all survive the export.

## Rules for adding a string

* Add a case to `FocusStringKey` with a `surface.subject.detail` raw value.
* Add the English entry. `FocusStringTable._selfCheck()` fails the build's
  Debug launch if you forget.
* If it takes arguments, set `placeholderCount`. The self-check verifies every
  translation keeps exactly that many `%`-tokens — a dropped `%d` is a crash,
  and an added one is a crash the caller cannot see.
* Never put user-facing words in a domain model. `FocusGoal`, `FocusObstacle`,
  `ProBenefit` and friends expose `titleKey`, not `displayName`, so there is
  exactly one place a line of copy lives.
* Never store rendered prose in something `Codable`. `OnboardingFocusPlan` keeps
  `rationaleKey`, not a sentence, so a saved plan can be re-rendered in whatever
  language the pilot reads today.
