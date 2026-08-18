//
//  RootView.swift
//  Blendfall
//
//  Top-level navigation between Home, the chapter list, one group's level grid,
//  a play session and Blitz, plus the Premium and Settings sheets, the
//  first-launch onboarding overlay, and the language / layout-direction
//  environment the whole app reads from.
//

import SwiftUI

struct RootView: View {
    @State private var progress = ProgressStore()
    @State private var store: StoreManager
    /// A back stack rather than a single screen, so leaving a level returns to the
    /// chapter it was opened from instead of always to the chapter list.
    @State private var stack: [Screen]
    @State private var sheet: Sheet?

    init() {
        let progress = ProgressStore()
        _progress = State(initialValue: progress)
        _store = State(initialValue: StoreManager(progress: progress))
        _stack = State(initialValue: RootView.initialStack())
        _sheet = State(initialValue: RootView.initialSheet())
    }

    /// DEBUG-only: jump straight into a Classic level (`BF_START_LEVEL=<n>`), any level
    /// by id (`BF_START_LEVEL_ID=starhunt1`), one group's grid (`BF_START_GROUP=portals`),
    /// the chapter list (`BF_START_LEVELS=1`) or blitz (`BF_START_BLITZ=1`), passed via
    /// `SIMCTL_CHILD_*`. Never affects normal launches.
    private static func initialStack() -> [Screen] {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if let raw = env["BF_START_LEVEL"], let n = Int(raw), n >= 1, n <= Levels.classic.count {
            return [.home, .game(levelId: Levels.classic[n - 1].id)]
        }
        if let id = env["BF_START_LEVEL_ID"], Levels.all.contains(where: { $0.id == id }) {
            return [.home, .game(levelId: id)]
        }
        if let id = env["BF_START_GROUP"], Levels.groups.contains(where: { $0.id == id }) {
            return [.home, .chapters, .groupLevels(groupId: id)]
        }
        if env["BF_START_LEVELS"] != nil { return [.home, .chapters] }
        if env["BF_START_BLITZ"] != nil { return [.home, .blitz] }
        #endif
        return [.home]
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
        /// Every level group: the six Classic chapters plus the mechanic packs.
        case chapters
        /// One chapter's 50 levels, or one pack's levels.
        case groupLevels(groupId: String)
        /// `run` makes replays of the same level distinct so state starts fresh.
        case game(levelId: String, run: Int = 0)
        case blitz
    }

    enum Sheet: String, Identifiable {
        case premium, settings
        var id: String { rawValue }
    }

    private var screen: Screen { stack.last ?? .home }

    private func push(_ next: Screen) { stack.append(next) }

    private func pop() { if stack.count > 1 { stack.removeLast() } }

    /// Central gate for starting a level: premium-locked levels open the paywall instead.
    /// Replaying or advancing swaps the top of the stack so Back still leads to the grid.
    private func openLevel(_ id: String) {
        let level = Levels.byId(id)
        if Levels.isPaywalled(Levels.groupOf(level), premium: progress.premium) {
            sheet = .premium
            return
        }
        if case .game(let current, let r) = screen {
            stack[stack.count - 1] = .game(levelId: id, run: current == id ? r + 1 : 0)
        } else {
            push(.game(levelId: id))
        }
    }

    /// The win screen's "Levels" button: back to the grid the level belongs to.
    private func showLevelGrid(for levelId: String) {
        let groupId = Levels.byId(levelId).groupId
        if case .groupLevels(let open) = stack.dropLast().last, open == groupId {
            pop()
        } else {
            stack[stack.count - 1] = .groupLevels(groupId: groupId)
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
                    onLevels: { push(.chapters) },
                    onBlitz: { push(.blitz) },
                    onPremium: { sheet = .premium },
                    onSettings: { sheet = .settings }
                )
                .transition(.opacity)

            case .chapters:
                ChaptersScreen(
                    progress: progress,
                    onBack: { pop() },
                    onGroup: { push(.groupLevels(groupId: $0)) },
                    onPremium: { sheet = .premium }
                )
                .transition(.opacity)

            case .groupLevels(let groupId):
                LevelGridScreen(
                    groupId: groupId,
                    progress: progress,
                    onBack: { pop() },
                    onLevel: { openLevel($0) }
                )
                .transition(.opacity)

            case .game(let levelId, let run):
                GameScreen(
                    level: Levels.byId(levelId),
                    progress: progress,
                    store: store,
                    onBack: { pop() },
                    onNext: { openLevel($0) },
                    onLevels: { showLevelGrid(for: levelId) },
                    onPremium: { sheet = .premium }
                )
                .id("game-\(levelId)-\(run)")
                .transition(.opacity)

            case .blitz:
                BlitzScreen(
                    progress: progress,
                    onBack: { pop() }
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
