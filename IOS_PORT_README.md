# Blendfall — iOS port

Port of `~/AndroidStudioProjects/Blendfall` (Kotlin/Compose) to SwiftUI, following the
FitStation/linequest port pattern. Android is the source of truth.

## Structure map

| Android (`com.rongo.blendfall`) | iOS (`Blendfall/`) |
|---|---|
| `engine/Model.kt`, `Engine.kt`, `Solver.kt` | `Game/Engine.swift` (all `nonisolated` so the solver runs off-main) |
| `levels/Levels.kt` (catalog + tutorials) | `Levels/Levels.swift` |
| `levels/GeneratedClassic.kt`, `LegacyClassic.kt`, `BigPackLevels.kt` | `Levels/GeneratedLevels.swift` — GENERATED, see `tools/gen_levels.py` |
| `res/values*/strings.xml` (14 languages) | `Localization/Strings.swift` — GENERATED, see `tools/gen_strings.py`; keys identical to Android |
| `ui/theme/Theme.kt` (11 palettes) | `UI/Theme.swift` |
| `ui/theme/BlockShape.kt` (9 shapes) | `Game/BlockShapes.swift` |
| `ui/theme/Tier.kt` | `UI/Theme.swift` (`Tier`) |
| `data/ProgressRepository.kt`, `PickupTally.kt` (DataStore) | `Data/ProgressStore.swift` (UserDefaults, same key names) |
| `data/BillingManager.kt` (Play Billing) | `Data/Store.swift` (StoreKit 2) + `Products.storekit` |
| `ui/PuzzleState.kt`, `GameViewModel.kt`, `BlitzViewModel.kt` | `Game/PuzzleState.swift` (`PuzzleState`, `GameViewModel`, `BlitzModel`) |
| `MainActivity.kt` (back-stack nav) | `App/RootView.swift` (`Screen` enum + back stack; Premium/Settings are sheets) |
| `ui/HomeScreen.kt` | `HomeScreen.swift` |
| `ui/ChaptersScreen.kt` (chapter list + level grid) | `ChaptersScreen.swift` (`ChaptersScreen`, `LevelGridScreen`) |
| `ui/GameScreen.kt` (board, swatches, win dialog) | `GameScreen.swift` (`BoardView`/`SwatchRow` shared with Blitz) |
| `ui/BlitzScreen.kt` | `BlitzScreen.swift` |
| `ui/PremiumScreen.kt` | `PremiumScreen.swift` |
| `ui/SettingsScreen.kt` | `SettingsScreen.swift` |
| `ui/OnboardingOverlay.kt` | `OnboardingOverlay.swift` |
| `ui/Ui.kt`, `Star.kt`, `PackBadge.kt` | `UI/Components.swift` (+ haptics, pickup star, pack badge) |

## Content shape

Classic is **300 levels in six chapters of 50** (`c1`…`c6`); chapters IV–VI are premium.
Each chapter's last 10 are **Master levels**, gated behind 90 stars from that chapter's
first 40. From global level 15 a Classic level is **move-limited** at par + 3.

Two free 80-level mechanic packs sit outside Classic, listed under their own header on
the Levels screen: **Star Hunt** (optional `*` pickups, 155 stars in total) and
**Portals** (paired rings that teleport a block, which keeps sliding). Classic itself is
deliberately mechanic-free — every special tile lives in a pack.

The engine also carries one-way gates, painter tiles and cracked floors, unused by any
shipping pack, so reviving one is a data change rather than an engine change.

## Tech mapping used

- Compose `@Composable` → SwiftUI `View`; `ViewModel`+`StateFlow` → `@Observable` classes
- DataStore → `UserDefaults` (`ProgressStore`), same keys (`premium`, `hints_left`, `stars_*`…)
- Play Billing → StoreKit 2; products:
  `com.rongo.blendfall.premium` ($4.99 NC), `.pack.candy/.nature/.retro` ($1.99 NC),
  `.hints50` ($0.99 consumable). DEBUG builds grant directly when the store is
  unavailable (mirrors the Android debug fallback); `SIMCTL_CHILD_BF_PRO=1` unlocks all.
- In-app language switching (14 languages) via `Strings.swift` env value; he/ar flip
  layout RTL, the board itself stays LTR (spatial).
- Haptics: `UIImpactFeedbackGenerator`/`UINotificationFeedbackGenerator` mapped from
  the Android `HapticFeedbackConstants` usage.
- iOS-game styling: SF Rounded everywhere, spring block animations, pressable-scale
  buttons, custom win overlay card, portrait-only.
- The portal trip animation needs a per-frame easing curve across two legs, which a
  plain SwiftUI animation cannot express, so `WarpTrip` reads the clock from a
  `TimelineView(.animation)` — the counterpart of Compose's `Animatable` loop.
- Level grids feed rows straight into the `LazyVStack` rather than through a wrapper
  view; a single tall child stops the stack materializing what follows it.

## Regenerating generated files

```bash
python3 tools/gen_strings.py   # from Android res/values*/strings.xml
python3 tools/gen_levels.py    # from Android GeneratedClassic/LegacyClassic/BigPackLevels.kt
```

`gen_strings.py` carries the iOS-only keys (`home_no_ads`, `home_stars`) over from the
previous output, since Android has no equivalent for them.

## Verifying a level port

`tools/gen_levels.py` only moves data; the check that the *engine* agrees with Android is
to solve every board and confirm BFS optimal == par (the Android `LevelDoctorTest`
invariant). The engine has no UI dependencies, so it compiles standalone:

```bash
xcrun swiftc -O -o /tmp/verify \
  Blendfall/Game/Engine.swift Blendfall/Levels/Levels.swift \
  Blendfall/Levels/GeneratedLevels.swift Blendfall/Localization/Strings.swift main.swift
```

Last run: 460 levels, all solvable at par, 155 pickup stars.

## Accessibility

Mirrors the Android a11y pass, in iOS terms:

- Every block is a labelled button — colour, column, row, and whether it is already on
  its target — with the selected colour carrying `.isSelected`.
- The board's static layer speaks its size and how many targets are filled.
- Swatches sit in a full 48pt hit target, are labelled with colour + count, and report
  the selected one; the same for theme, shape and Blitz-duration chips.
- Level chips merge into one label (`Level 12, 2 of 3 stars` / `not solved` / `locked`)
  rather than reading out a bare number.
- Star rows speak "n of 3 stars"; unearned stars are an outline, not a faint fill, so
  the difference is shape as well as colour.
- Blitz's clock is labelled and marked `.updatesFrequently`.
- The colourblind letter is its own string per language (`cb_*`), never the first letter
  of the colour name — Hebrew כחול/כתום and German Gelb/Grün collide. Targets carry the
  letter too, and ink on blocks/buttons is picked by luminance (`onBlockColor`).

**Known gap:** the UI uses fixed point sizes, so it does not respond to Dynamic Type.
Android's `sp` scales for free, which is why its buttons moved to `heightIn`; the iOS
buttons carry the matching `minHeight`, but nothing scales into it yet. Supporting
Dynamic Type properly means moving ~200 `.font(.system(size:))` call sites onto scaled
metrics and re-checking every screen — a deliberate piece of work, not a parity fix.

## Status

- [x] Engine (incl. portals, pickups, gates, painters, cracks), solver, 11 themes,
      9 shapes, 14 languages
- [x] 460 levels: 300 Classic in six chapters + Star Hunt 80 + Portals 80 — all
      solver-verified at par
- [x] Home / Chapters / Level grid / Game / Blitz / Premium / Settings / Onboarding
- [x] StoreKit 2 + Products.storekit test config
- [x] Builds and runs on iPhone simulator (Debug and Release) and on iPad
- [x] VoiceOver labels across board, swatches, level chips, stars, store and settings
- [ ] Dynamic Type (see Accessibility above)
- [x] App Store files: `AppStore_Listing.md` (incl. the 5 IAPs + pricing), `PRIVACY.md`,
      `SUPPORT.md`, `AppStore_Screenshots/` (iPhone 6.9" + iPad 13" + IAP review shot)
- [x] v1.0 (build 1) archive in Xcode Organizer (`Archives/2026-07-17`)
- [ ] Manual, in App Store Connect: create app record, create the 5 IAP products
      (table in `AppStore_Listing.md` §6), host PRIVACY/SUPPORT pages, upload archive
