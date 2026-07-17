//
//  GameScreen.swift
//  Blendfall
//
//  One campaign level: the board with swipe/tap gestures, the color swatches,
//  Undo / Refresh / Hint actions, the tutorial tip, the solver-driven hint row
//  and the win overlay. The board pieces (BoardView, SwatchRow) are shared
//  with Blitz.
//

import SwiftUI

struct GameScreen: View {
    let level: Level
    let progress: ProgressStore
    let store: StoreManager
    let onBack: () -> Void
    let onNext: (String) -> Void
    let onLevels: () -> Void
    let onPremium: () -> Void

    @State private var vm: GameViewModel
    @State private var showHintsOut = false

    init(
        level: Level,
        progress: ProgressStore,
        store: StoreManager,
        onBack: @escaping () -> Void,
        onNext: @escaping (String) -> Void,
        onLevels: @escaping () -> Void,
        onPremium: @escaping () -> Void
    ) {
        self.level = level
        self.progress = progress
        self.store = store
        self.onBack = onBack
        self.onNext = onNext
        self.onLevels = onLevels
        self.onPremium = onPremium
        _vm = State(initialValue: GameViewModel(level: level))
    }

    var body: some View {
        let palette = progress.palette
        let s = progress.strings

        ZStack {
            palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // ---------- Top bar ----------
                ZStack {
                    HStack {
                        BackButton(palette: palette, action: onBack)
                        Spacer()
                    }
                    VStack(spacing: 1) {
                        Text(s.f(.level_label, Levels.globalNumber(level.id)))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.textPrimary)
                        Text(s[Levels.packOf(level).nameKey])
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 2)

                // ---------- Moves + potential stars ----------
                HStack(spacing: 10) {
                    StarsRow(
                        earned: Engine.starsFor(par: level.par, moves: vm.play.moveCount),
                        size: 14,
                        palette: palette,
                        spacing: 2
                    )
                    Text(s.f(.game_moves, vm.play.moveCount, level.par) + "  " + s[.game_moves_label])
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                }
                .padding(.top, 4)

                // ---------- Tutorial tip ----------
                if let tip = level.tip, vm.play.moveCount == 0, !vm.play.won {
                    Text(s[tip])
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                        .transition(.opacity)
                }

                // ---------- Board ----------
                BoardView(
                    play: vm.play,
                    palette: palette,
                    colorblind: progress.colorblind,
                    blockShape: progress.shape,
                    strings: s
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(16)

                // ---------- Hint feedback (below the board so it never covers it) ----------
                if vm.hintState == .noSolution || vm.hintState == .offPath {
                    Text(vm.hintState == .noSolution ? s[.hint_no_solution] : s[.hint_off_path])
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.accent)
                        .multilineTextAlignment(.center)
                        .padding(4)
                        .frame(maxWidth: .infinity)
                        .onTapGesture { vm.dismissHintMessage() }
                        .transition(.opacity)
                }
                if let step = vm.hint {
                    HintRow(step: step, palette: palette, s: s)
                }

                // ---------- Color swatches ----------
                SwatchRow(play: vm.play, palette: palette, hintColor: vm.hint?.color)
                    .padding(.top, 6)

                // ---------- Action buttons ----------
                // When the solver flags no solution or an off-path position,
                // Refresh lights up — that's the way out.
                let stuck = vm.hintState == .noSolution || vm.hintState == .offPath
                HStack(spacing: 10) {
                    ActionButton(
                        icon: "arrow.uturn.backward",
                        iconColor: palette.textPrimary,
                        label: s[.btn_undo],
                        enabled: vm.play.canUndo && !vm.play.won,
                        palette: palette
                    ) {
                        vm.play.undo()
                    }
                    ActionButton(
                        icon: "arrow.clockwise",
                        iconColor: palette.textPrimary,
                        label: s[.btn_refresh],
                        enabled: !vm.play.won,
                        palette: palette,
                        big: true,
                        emphasized: stuck
                    ) {
                        vm.restart()
                    }
                    ActionButton(
                        icon: "lightbulb.fill",
                        iconColor: palette.star,
                        label: vm.hintState == .thinking ? s[.hint_thinking] : s.f(.hint_count, progress.hints),
                        enabled: !vm.play.won,
                        palette: palette
                    ) {
                        if progress.hints > 0 {
                            vm.requestHint(onFound: { progress.consumeHint() })
                        } else {
                            showHintsOut = true
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .phoneContentWidth()

            // ---------- Win overlay ----------
            if vm.play.won {
                let next = Levels.next(level)
                let nextAllowed = next != nil && (!Levels.packOf(next!).premium || progress.premium)
                WinOverlay(
                    stars: vm.play.starsEarned,
                    moves: vm.play.moveCount,
                    hasNext: nextAllowed,
                    nextLocked: next != nil && !nextAllowed,
                    palette: palette,
                    s: s,
                    onNext: { if let next { onNext(next.id) } },
                    onReplay: { vm.restart() },
                    onLevels: onLevels,
                    onPremium: onPremium
                )
            }
        }
        .animation(.easeInOut(duration: 0.25), value: vm.play.won)
        .animation(.easeInOut(duration: 0.2), value: vm.hintState == .noSolution || vm.hintState == .offPath)
        .onAppear {
            vm.play.onEffect = { [weak progress] effect in
                if progress?.haptics == true { Haptics.play(effect) }
            }
        }
        .onChange(of: vm.play.won) { _, won in
            if won { progress.recordWin(level.id, stars: vm.play.starsEarned) }
        }
        .alert(s[.hints_out_title], isPresented: $showHintsOut) {
            Button(s.f(.hints_buy, store.prices[StoreManager.hintsID] ?? s[.hints_price_fallback])) {
                Task { await store.buy(StoreManager.hintsID) }
            }
            .disabled(!store.canBuy)
            Button(s[.not_now], role: .cancel) {}
        } message: {
            Text(s[.hints_out_body])
        }
    }
}

/// The hint, as a pulsing arrow + text in the color of the block to swipe —
/// language-free direction for RTL users, and it never hides the board.
private struct HintRow: View {
    let step: Solver.Step
    let palette: BlendPalette
    let s: Strings

    @State private var pulse = false

    private var rotation: Double {
        switch step.dir {
        case .up: return 0
        case .right: return 90
        case .down: return 180
        case .left: return 270
        }
    }

    var body: some View {
        let tint = palette.block(step.color)
        HStack(spacing: 6) {
            Image(systemName: "arrow.up")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(tint.opacity(pulse ? 1 : 0.55))
                .rotationEffect(.degrees(rotation))
            Text(s.f(.hint_move, colorName(step.color, s), dirName(step.dir, s)))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Board

struct BoardView: View {
    let play: PuzzleState
    let palette: BlendPalette
    let colorblind: Bool
    let blockShape: BlockShape
    let strings: Strings

    var body: some View {
        let board = play.parsed.board

        GeometryReader { geo in
            let cell = min(geo.size.width / Double(board.width), geo.size.height / Double(board.height), 64)
            let boardW = cell * Double(board.width)
            let boardH = cell * Double(board.height)

            ZStack(alignment: .topLeading) {
                // Static layer: floors, walls, targets
                Canvas { ctx, _ in
                    for y in 0..<board.height {
                        for x in 0..<board.width {
                            let origin = CGPoint(x: Double(x) * cell, y: Double(y) * cell)
                            if board.isWall(x, y) {
                                let rect = CGRect(x: origin.x + cell * 0.03, y: origin.y + cell * 0.03, width: cell * 0.94, height: cell * 0.94)
                                ctx.fill(Path(roundedRect: rect, cornerRadius: cell * 0.16), with: .color(palette.wall))
                            } else {
                                let rect = CGRect(x: origin.x + cell * 0.05, y: origin.y + cell * 0.05, width: cell * 0.9, height: cell * 0.9)
                                ctx.fill(Path(roundedRect: rect, cornerRadius: cell * 0.14), with: .color(palette.cell))
                                if let target = board.targetAt(x, y) {
                                    let tint = palette.block(target)
                                    let ring = CGRect(x: origin.x + cell * 0.1, y: origin.y + cell * 0.1, width: cell * 0.8, height: cell * 0.8)
                                    ctx.stroke(
                                        Path(roundedRect: ring, cornerRadius: cell * 0.14),
                                        with: .color(tint),
                                        lineWidth: cell * 0.06
                                    )
                                    let cx = origin.x + cell / 2
                                    let cy = origin.y + cell / 2
                                    let r = cell * 0.13
                                    var diamond = Path()
                                    diamond.move(to: CGPoint(x: cx, y: cy - r))
                                    diamond.addLine(to: CGPoint(x: cx + r, y: cy))
                                    diamond.addLine(to: CGPoint(x: cx, y: cy + r))
                                    diamond.addLine(to: CGPoint(x: cx - r, y: cy))
                                    diamond.closeSubpath()
                                    ctx.fill(diamond, with: .color(tint.opacity(0.55)))
                                }
                            }
                        }
                    }
                }
                .frame(width: boardW, height: boardH)

                // Blocks
                ForEach(play.blocks) { block in
                    BlockTile(
                        block: block,
                        cell: cell,
                        palette: palette,
                        blockShape: blockShape,
                        selected: block.color == play.selected,
                        satisfied: board.targetAt(block.x, block.y) == block.color,
                        colorblind: colorblind,
                        strings: strings
                    )
                }

                // Fusion ghosts fading into their anvil
                ForEach(play.ghosts) { ghost in
                    GhostTile(ghost: ghost, cell: cell, palette: palette, blockShape: blockShape)
                }
            }
            .frame(width: boardW, height: boardH)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: play.blocks)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        // Starting a swipe on a block selects its color, so
                        // touch-and-slide moves that color in one gesture.
                        let x = Int(value.startLocation.x / cell)
                        let y = Int(value.startLocation.y / cell)
                        if let hit = play.blocks.first(where: { $0.x == x && $0.y == y }) {
                            play.select(hit.color)
                        }
                        let dx = value.translation.width
                        let dy = value.translation.height
                        let threshold = 28.0
                        let dir: Direction? = if abs(dx) < threshold && abs(dy) < threshold {
                            nil
                        } else if abs(dx) >= abs(dy) {
                            dx > 0 ? .right : .left
                        } else {
                            dy > 0 ? .down : .up
                        }
                        if let dir { play.move(dir) }
                    }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // The board is spatial: swipes and block coordinates are physical,
        // so it must not mirror in RTL locales.
        .environment(\.layoutDirection, .leftToRight)
    }
}

private struct BlockTile: View {
    let block: Block
    let cell: Double
    let palette: BlendPalette
    let blockShape: BlockShape
    let selected: Bool
    let satisfied: Bool
    let colorblind: Bool
    let strings: Strings

    var body: some View {
        BlockView(color: block.color, palette: palette, shape: blockShape)
            .overlay(
                TileShape(kind: blockShape)
                    .stroke(
                        selected ? .white.opacity(0.9) : (satisfied ? .white.opacity(0.55) : .clear),
                        lineWidth: selected ? 2.5 : (satisfied ? 2 : 0)
                    )
            )
            .overlay {
                if colorblind {
                    Text(String(colorName(block.color, strings).prefix(1)))
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .padding(cell * 0.07)
            .frame(width: cell, height: cell)
            .offset(x: Double(block.x) * cell, y: Double(block.y) * cell)
            .animation(.easeInOut(duration: 0.24), value: block.color)
    }
}

private struct GhostTile: View {
    let ghost: Ghost
    let cell: Double
    let palette: BlendPalette
    let blockShape: BlockShape

    @State private var faded = false

    var body: some View {
        TileShape(kind: blockShape)
            .fill(palette.block(ghost.color))
            .padding(cell * 0.07)
            .frame(width: cell, height: cell)
            .opacity(faded ? 0 : 0.85)
            .scaleEffect(faded ? 1.34 : 1)
            .offset(x: Double(ghost.x) * cell, y: Double(ghost.y) * cell)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) { faded = true }
            }
            .allowsHitTesting(false)
    }
}

// MARK: - Swatches

struct SwatchRow: View {
    let play: PuzzleState
    let palette: BlendPalette
    var hintColor: GameColor?

    var body: some View {
        let counts = Dictionary(grouping: play.blocks, by: \.color).mapValues(\.count)
        HStack(spacing: 14) {
            ForEach(GameColor.allCases, id: \.self) { color in
                if let count = counts[color], count > 0 {
                    let isSelected = play.selected == color
                    let isHinted = hintColor == color
                    Button {
                        play.select(color)
                    } label: {
                        Circle()
                            .fill(palette.block(color))
                            .frame(width: isSelected ? 46 : 38, height: isSelected ? 46 : 38)
                            .overlay(
                                Circle().stroke(
                                    isSelected ? .white : (isHinted ? palette.accent : .black.opacity(0.15)),
                                    lineWidth: isSelected || isHinted ? 3 : 1
                                )
                            )
                            .overlay {
                                if count > 1 {
                                    Text("\(count)")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: play.selected)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Win overlay

struct WinOverlay: View {
    let stars: Int
    let moves: Int
    let hasNext: Bool
    let nextLocked: Bool
    let palette: BlendPalette
    let s: Strings
    let onNext: () -> Void
    let onReplay: () -> Void
    let onLevels: () -> Void
    let onPremium: () -> Void

    @State private var shown = 0
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 0) {
                Text(s[.win_title])
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        let earned = i < shown
                        Image(systemName: "star.fill")
                            .font(.system(size: earned ? 40 : 32))
                            .foregroundStyle(earned ? palette.star : palette.textSecondary.opacity(0.25))
                            .scaleEffect(earned ? 1 : 0.9)
                            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: earned)
                    }
                }
                .padding(.top, 14)

                Text(s.plural(.win_moves, moves))
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(palette.textSecondary)
                    .padding(.top, 10)

                if stars == 3 {
                    Text(s[.win_perfect])
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.star)
                        .padding(.top, 2)
                }

                Spacer().frame(height: 20)

                if hasNext {
                    Button(action: onNext) {
                        Text(s[.win_next])
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(palette.accent, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.bottom, 6)
                } else if nextLocked {
                    Button(action: onPremium) {
                        Text(s[.get_premium])
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(palette.star, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.bottom, 6)
                }

                HStack(spacing: 8) {
                    Button(s[.win_replay], action: onReplay)
                    Button(s[.win_levels], action: onLevels)
                }
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(palette.textSecondary)
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: 340)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.25), radius: 30, y: 10)
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { appeared = true }
            Task {
                for _ in 0..<stars {
                    try? await Task.sleep(for: .milliseconds(240))
                    shown += 1
                }
            }
        }
    }
}
