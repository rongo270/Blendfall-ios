# Blendfall — App Store screenshots

Shot on simulators with a clean 9:41 status bar and seeded progress
(30 levels solved, 85 stars, 27 hints, Blitz bests).

| Folder | Device | Size | App Store slot |
|---|---|---|---|
| `iPhone_6.9/` | iPhone 17 Pro Max sim | 1320×2868 | 6.9" iPhone (required) |
| `iPad_13/` | iPad Pro 13-inch (M5) sim | 2064×2752 | 13" iPad (required — app supports iPad) |
| `IAP_review/` | — | — | Review screenshot for each of the 5 in-app purchases |

Order to upload (same in both folders):

1. `1_home.png` — Home, Midnight theme
2. `2_game_blend.png` — Level 11 blend tutorial, Classic theme
3. `3_game_neon.png` — Level 100, Neon theme (premium theme)
4. `4_blitz.png` — Blitz setup with best scores, Ocean theme
5. `5_premium.png` — in-app store with all products
6. `6_themes.png` — Settings theme & shape grids, everything unlocked

To reshoot after UI changes: install the debug build, then use the
`SIMCTL_CHILD_BF_*` launch env vars (`BF_START_LEVEL`, `BF_START_BLITZ`,
`BF_SHEET=premium|settings`, `BF_PRO=1`) and
`xcrun simctl status_bar <sim> override --time "9:41" --batteryLevel 100 --batteryState charged --cellularBars 4 --wifiBars 3`.
