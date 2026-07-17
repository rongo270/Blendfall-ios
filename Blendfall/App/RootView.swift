//
//  RootView.swift
//  Blendfall
//
//  Top-level navigation between Home, Levels, a play session and Blitz, plus
//  the Premium and Settings sheets, the first-launch onboarding overlay, and
//  the language / layout-direction environment the whole app reads from.
//

import SwiftUI

struct RootView: View {
    @State private var progress = ProgressStore()
    @State private var store: StoreManager
    @State private var screen: Screen
    @State private var sheet: Sheet?

    init() {
        let progress = ProgressStore()
        _progress = State(initialValue: progress)
        _store = State(initialValue: StoreManager(progress: progress))
        _screen = State(initialValue: RootView.initialScreen())
        _sheet = State(initialValue: RootView.initialSheet())
    }

    /// DEBUG-only: jump straight into a level (`BF_START_LEVEL=<n>`, global number),
    /// the level grid (`BF_START_LEVELS=1`) or blitz (`BF_START_BLITZ=1`), passed via
    /// `SIMCTL_CHILD_*`. Never affects normal launches.
    private static func initialScreen() -> Screen {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if let raw = env["BF_START_LEVEL"], let n = Int(raw), n >= 1, n <= Levels.all.count {
            return .game(levelId: Levels.all[n - 1].id)
        }
        if env["BF_START_LEVELS"] != nil { return .packs }
        if env["BF_START_BLITZ"] != nil { return .blitz }
        #endif
        return .home
    }

    /// DEBUG-only: open a sheet on launch with `BF_SHEET=premium|settings`.
    private static func initialSheet() -> Sheet? {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["BF_SHEET"] {
            return Sheet(rawValue: raw)
        }
        #endif
        return nil
    }

    enum Screen: Equatable {
        case home
        case packs
        /// `run` makes replays of the same level distinct so state starts fresh.
        case game(levelId: String, run: Int = 0)
        case blitz
    }

    enum Sheet: String, Identifiable {
        case premium, settings
        var id: String { rawValue }
    }

    /// Central gate for starting a level: premium-locked levels open the paywall instead.
    private func openLevel(_ id: String) {
        let level = Levels.byId(id)
        if Levels.packOf(level).premium && !progress.premium {
            sheet = .premium
        } else {
            var run = 0
            if case .game(let current, let r) = screen, current == id { run = r + 1 }
            screen = .game(levelId: id, run: run)
        }
    }

    var body: some View {
        let palette = progress.palette

        ZStack {
            palette.background.ignoresSafeArea()

            switch screen {
            case .home:
                HomeScreen(
                    progress: progress,
                    onPlay: { openLevel($0) },
                    onLevels: { screen = .packs },
                    onBlitz: { screen = .blitz },
                    onPremium: { sheet = .premium },
                    onSettings: { sheet = .settings }
                )
                .transition(.opacity)

            case .packs:
                PacksScreen(
                    progress: progress,
                    onBack: { screen = .home },
                    onLevel: { openLevel($0) },
                    onPremium: { sheet = .premium }
                )
                .transition(.opacity)

            case .game(let levelId, let run):
                GameScreen(
                    level: Levels.byId(levelId),
                    progress: progress,
                    store: store,
                    onBack: { screen = .packs },
                    onNext: { openLevel($0) },
                    onLevels: { screen = .packs },
                    onPremium: { sheet = .premium }
                )
                .id("game-\(levelId)-\(run)")
                .transition(.opacity)

            case .blitz:
                BlitzScreen(
                    progress: progress,
                    onBack: { screen = .home }
                )
                .transition(.opacity)
            }

            if !progress.onboardingDone {
                OnboardingOverlay(progress: progress) {
                    progress.setOnboardingDone()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: screen)
        .animation(.easeInOut(duration: 0.35), value: progress.onboardingDone)
        .sheet(item: $sheet) { kind in
            switch kind {
            case .premium:
                PremiumScreen(progress: progress, store: store)
            case .settings:
                SettingsScreen(progress: progress) { sheet = .premium }
            }
        }
        .fontDesign(.rounded)
        .environment(\.strings, progress.strings)
        .environment(\.layoutDirection, progress.language.isRTL ? .rightToLeft : .leftToRight)
        .preferredColorScheme(palette.isDark ? .dark : .light)
    }
}
