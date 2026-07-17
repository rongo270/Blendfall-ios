# Blendfall — iOS port

Port of `~/AndroidStudioProjects/Blendfall` (Kotlin/Compose) to SwiftUI, following the
FitStation/linequest port pattern. Android is the source of truth.

## Structure map

| Android (`com.rongo.blendfall`) | iOS (`Blendfall/`) |
|---|---|
| `engine/Model.kt`, `Engine.kt`, `Solver.kt` | `Engine.swift` (all `nonisolated` so the solver runs off-main) |
| `levels/Levels.kt` (packs 1–4) | `Levels.swift` |
| `levels/GeneratedLevels.kt` (packs 5–30) | `GeneratedLevels.swift` — GENERATED, see `tools/gen_levels.py` |
| `res/values*/strings.xml` (14 languages) | `Strings.swift` — GENERATED, see `tools/gen_strings.py`; keys identical to Android |
| `ui/theme/Theme.kt` (11 palettes) | `Theme.swift` |
| `ui/theme/BlockShape.kt` (9 shapes) | `BlockShapes.swift` |
| `ui/theme/Tier.kt` | `Theme.swift` (`Tier`) |
| `data/ProgressRepository.kt` (DataStore) | `ProgressStore.swift` (UserDefaults, same key names) |
| `data/BillingManager.kt` (Play Billing) | `Store.swift` (StoreKit 2) + `Products.storekit` |
| `ui/PuzzleState.kt`, `GameViewModel.kt`, `BlitzViewModel.kt` | `PuzzleState.swift` (`PuzzleState`, `GameViewModel`, `BlitzModel`) |
| `MainActivity.kt` (back-stack nav) | `RootView.swift` (`Screen` enum; Premium/Settings are sheets) |
| `ui/HomeScreen.kt` | `HomeScreen.swift` |
| `ui/PacksScreen.kt` | `PacksScreen.swift` |
| `ui/GameScreen.kt` (board, swatches, win dialog) | `GameScreen.swift` (`BoardView`/`SwatchRow` shared with Blitz) |
| `ui/BlitzScreen.kt` | `BlitzScreen.swift` |
| `ui/PremiumScreen.kt` | `PremiumScreen.swift` |
| `ui/SettingsScreen.kt` | `SettingsScreen.swift` |
| `ui/OnboardingOverlay.kt` | `OnboardingOverlay.swift` |
| `ui/Ui.kt` | `Components.swift` (+ haptics) |

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

## Regenerating generated files

```bash
python3 tools/gen_strings.py   # from Android res/values*/strings.xml
python3 tools/gen_levels.py    # from Android GeneratedLevels.kt
```

## Status

- [x] Engine, solver, 300 levels, 11 themes, 9 shapes, 14 languages
- [x] Home / Packs / Game / Blitz / Premium / Settings / Onboarding
- [x] StoreKit 2 + Products.storekit test config
- [x] Builds and runs on iPhone simulator (Debug and Release)
- [x] App Store files: `AppStore_Listing.md` (incl. the 5 IAPs + pricing), `PRIVACY.md`,
      `SUPPORT.md`, `AppStore_Screenshots/` (iPhone 6.9" + iPad 13" + IAP review shot)
- [x] v1.0 (build 1) archive in Xcode Organizer (`Archives/2026-07-17`)
- [ ] Manual, in App Store Connect: create app record, create the 5 IAP products
      (table in `AppStore_Listing.md` §6), host PRIVACY/SUPPORT pages, upload archive
