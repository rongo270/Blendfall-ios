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
        let group = Levels.groupOf(level)

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
                        Text(s.f(.level_label, Levels.displayNumber(level)))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.textPrimary)
                        Text(s[group.nameKey])
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
                    // With a limit the counter runs against the limit — the star pips
                    // already say where par sits, and "7 / 4" would just look like a bug.
                    let urgent = (vm.play.movesLeft ?? 3) <= 2
                    Text(
                        s.f(.game_moves, vm.play.moveCount, vm.play.moveLimit ?? level.par)
                            + "  " + s[.game_moves_label]
                    )
                    .font(.system(size: 14, weight: urgent ? .bold : .regular, design: .rounded))
                    .foregroundStyle(urgent ? palette.accent : palette.textSecondary)

                    // Star Hunt's optional stars.
                    if vm.play.pickupTotal > 0 {
                        HStack(spacing: 3) {
                            PickupStarIcon(size: 15, color: palette.star)
                            Text(s.f(.stars_collected, vm.play.collectedCount, vm.play.pickupTotal))
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(palette.textSecondary)
                        }
                    }
                }
                .padding(.top, 4)

                // ---------- Tutorial tip, or a pack's one-line rule on its first level ----------
                let intro = level.tip ?? (level.index == 0 ? group.blurbKey : nil)
                if let intro, vm.play.moveCount == 0, !vm.play.won {
                    Text(s[intro])
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

            // ---------- Out of moves ----------
            if vm.play.failed {
                OutOfMovesOverlay(
                    palette: palette,
                    s: s,
                    onUndo: { vm.play.undo() },
                    onRestart: { vm.restart() }
                )
            }

            // ---------- Win overlay ----------
            if vm.play.won {
                // Fold this win into the star map before asking what comes next — the
                // answer can hinge on the star it just earned.
                let banked = progress.stars.merging(
                    [level.id: max(progress.starsFor(level.id), vm.play.starsEarned)]
                ) { _, new in new }
                let next = Levels.nextPlayable(level, stars: banked)
                let nextAllowed = next.map {
                    !Levels.isPaywalled(Levels.groupOf($0), premium: progress.premium)
                } ?? false
                WinOverlay(
                    stars: vm.play.starsEarned,
                    moves: vm.play.moveCount,
                    starsCollected: vm.play.collectedCount,
                    starsTotal: vm.play.pickupTotal,
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
        .animation(.easeInOut(duration: 0.25), value: vm.play.failed)
        .animation(.easeInOut(duration: 0.2), value: vm.hintState == .noSolution || vm.hintState == .offPath)
        .onAppear {
            vm.play.onEffect = { [weak progress] effect in
                if progress?.haptics == true { Haptics.play(effect) }
            }
        }
        .onChange(of: vm.play.won) { _, won in
            if won {
                progress.recordWin(
                    level.id,
                    stars: vm.play.starsEarned,
                    collected: vm.play.collectedCount
                )
            }
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
            // A block mid-warp is hidden: WarpTrip below is showing its trip, and leaving
            // the real one on screen would slide it across the board — exactly the
            // impression portals must not give.
            let warping = Set(play.warps.map(\.id))

            ZStack(alignment: .topLeading) {
                // Static layer: floors, walls, targets and any special-pack tiles
                Canvas { ctx, _ in
                    let collapsed = play.state.collapsed
                    let collected = play.state.collected
                    for y in 0..<board.height {
                        for x in 0..<board.width {
                            let origin = CGPoint(x: Double(x) * cell, y: Double(y) * cell)
                            let cellIdx = board.idx(x, y)
                            let hasFallen = collapsed.contains(cellIdx)
                            if board.isWall(x, y) || hasFallen {
                                let rect = CGRect(
                                    x: origin.x + cell * 0.03, y: origin.y + cell * 0.03,
                                    width: cell * 0.94, height: cell * 0.94
                                )
                                ctx.fill(
                                    Path(roundedRect: rect, cornerRadius: cell * 0.16),
                                    with: .color(hasFallen ? palette.wall.opacity(0.5) : palette.wall)
                                )
                                continue
                            }

                            let rect = CGRect(
                                x: origin.x + cell * 0.05, y: origin.y + cell * 0.05,
                                width: cell * 0.9, height: cell * 0.9
                            )
                            ctx.fill(
                                Path(roundedRect: rect, cornerRadius: cell * 0.14),
                                with: .color(palette.cell)
                            )
                            if let target = board.targetAt(x, y) {
                                let tint = palette.block(target)
                                let ring = CGRect(
                                    x: origin.x + cell * 0.1, y: origin.y + cell * 0.1,
                                    width: cell * 0.8, height: cell * 0.8
                                )
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

                            drawSpecialTile(
                                &ctx,
                                board: board,
                                cellIdx: cellIdx,
                                origin: origin,
                                cell: cell,
                                collected: collected,
                                palette: palette
                            )
                        }
                    }
                }
                .frame(width: boardW, height: boardH)

                // Blocks
                ForEach(play.blocks.filter { !warping.contains($0.id) }) { block in
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

                // Portal trips: into one mouth, out of the other.
                ForEach(play.warps) { warp in
                    WarpTrip(warp: warp, cell: cell, palette: palette, blockShape: blockShape)
                        .id(warp.id)
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

/// Draws whatever tile a special pack has put on this cell — a collectible star or a
/// portal mouth. Classic boards carry none of these, so on Classic this does nothing.
///
/// The gate, painter and crack branches back the engine's tile support, which outlives
/// the One Way / Paint Shop / Fault Line packs it was written for; keeping them here
/// means bringing one of those packs back is a data change, not an engine change.
private func drawSpecialTile(
    _ ctx: inout GraphicsContext,
    board: Board,
    cellIdx: Int,
    origin: CGPoint,
    cell: Double,
    collected: Set<Int>,
    palette: BlendPalette
) {
    let center = CGPoint(x: origin.x + cell / 2, y: origin.y + cell / 2)

    func circle(_ radius: Double) -> Path {
        Path(ellipseIn: CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        ))
    }

    if let paint = board.painters[cellIdx] {
        let tint = palette.block(paint)
        ctx.fill(circle(cell * 0.32), with: .color(tint.opacity(0.28)))
        ctx.stroke(circle(cell * 0.32), with: .color(tint), lineWidth: cell * 0.07)
    }

    if let dir = board.gates[cellIdx] {
        ctx.fill(
            arrowPath(center: center, r: cell * 0.26, dir: dir),
            with: .color(palette.accent.opacity(0.8))
        )
    }

    if board.portals[cellIdx] != nil {
        ctx.stroke(circle(cell * 0.3), with: .color(palette.portal), lineWidth: cell * 0.06)
        ctx.stroke(circle(cell * 0.15), with: .color(palette.portal.opacity(0.5)), lineWidth: cell * 0.05)
    }

    if board.cracks.contains(cellIdx) {
        let r = cell * 0.3
        var zig = Path()
        zig.move(to: CGPoint(x: center.x - r, y: center.y - r * 0.45))
        zig.addLine(to: CGPoint(x: center.x - r * 0.2, y: center.y))
        zig.addLine(to: CGPoint(x: center.x + r * 0.25, y: center.y - r * 0.4))
        zig.addLine(to: CGPoint(x: center.x + r, y: center.y + r * 0.45))
        ctx.stroke(zig, with: .color(palette.accent.opacity(0.45)), lineWidth: cell * 0.05)
    }

    if board.pickups.contains(cellIdx) && !collected.contains(cellIdx) {
        drawPickupStar(&ctx, center: center, radius: cell * 0.24, color: palette.star)
    }
}

private func arrowPath(center: CGPoint, r: Double, dir: Direction) -> Path {
    let dx = Double(dir.dx)
    let dy = Double(dir.dy)
    // Perpendicular, for the two base corners.
    let px = -dy
    let py = dx
    var path = Path()
    path.move(to: CGPoint(x: center.x + dx * r, y: center.y + dy * r))
    path.addLine(to: CGPoint(
        x: center.x - dx * r * 0.55 + px * r * 0.8,
        y: center.y - dy * r * 0.55 + py * r * 0.8
    ))
    path.addLine(to: CGPoint(
        x: center.x - dx * r * 0.55 - px * r * 0.8,
        y: center.y - dy * r * 0.55 - py * r * 0.8
    ))
    path.closeSubpath()
    return path
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

/// The block's trip through a portal, in two legs of equal length: it slides into the
/// entry mouth and shrinks away, then swells back out of the exit mouth and carries on to
/// where it stopped. Each mouth flares as the block passes through it.
///
/// This exists because the alternative reads as a lie. Left alone, the block's coordinates
/// jump from one side of the board to the other and the tile animates smoothly between
/// them — which looks exactly like sliding straight through the wall in between. Playing
/// the two legs separately is what makes "in here, out there" legible.
///
/// The two legs need their own easing curve applied per frame, which a plain SwiftUI
/// animation cannot express, so the clock is read directly from a TimelineView.
private struct WarpTrip: View {
    let warp: WarpFx
    let cell: Double
    let palette: BlendPalette
    let blockShape: BlockShape

    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = min(1, max(0, ctx.date.timeIntervalSince(start) / warpDuration))
            let entering = t < 0.5
            let leg = entering ? t / 0.5 : (t - 0.5) / 0.5
            // Smoothstep, standing in for Compose's FastOutSlowIn.
            let eased = leg * leg * (3 - 2 * leg)

            let startX = Double(entering ? warp.fromX : warp.outX)
            let startY = Double(entering ? warp.fromY : warp.outY)
            let endX = Double(entering ? warp.inX : warp.toX)
            let endY = Double(entering ? warp.inY : warp.toY)

            // Shrink into the mouth on the way in, swell back out of it on the way out.
            let scale = entering ? 1 - 0.85 * leg : 0.15 + 0.85 * leg

            ZStack(alignment: .topLeading) {
                TileShape(kind: blockShape)
                    .fill(palette.block(warp.color))
                    .padding(cell * 0.07)
                    .frame(width: cell, height: cell)
                    .scaleEffect(scale)
                    .opacity(entering ? 1 - 0.25 * leg : 0.75 + 0.25 * leg)
                    .offset(
                        x: cell * (startX + (endX - startX) * eased),
                        y: cell * (startY + (endY - startY) * eased)
                    )

                WarpFlare(x: warp.inX, y: warp.inY, cell: cell, color: palette.portal,
                          active: entering, leg: leg)
                WarpFlare(x: warp.outX, y: warp.outY, cell: cell, color: palette.portal,
                          active: !entering, leg: leg)
            }
        }
        .allowsHitTesting(false)
    }
}

/// A mouth flaring as the block goes through it.
private struct WarpFlare: View {
    let x: Int
    let y: Int
    let cell: Double
    let color: Color
    let active: Bool
    let leg: Double

    var body: some View {
        if active {
            Circle()
                .stroke(color, lineWidth: cell * 0.055)
                .padding(cell * 0.14)
                .frame(width: cell, height: cell)
                .scaleEffect(0.7 + 0.55 * leg)
                .opacity((1 - leg) * 0.9)
                .offset(x: Double(x) * cell, y: Double(y) * cell)
        }
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

// MARK: - Out of moves

/// Shown when a move-limited level runs out of moves. Undo is offered first and stays
/// enabled, so a mistake costs a tap rather than the whole attempt.
private struct OutOfMovesOverlay: View {
    let palette: BlendPalette
    let s: Strings
    let onUndo: () -> Void
    let onRestart: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 0) {
                Text(s[.out_of_moves_title])
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                Text(s[.out_of_moves_body])
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)

                Spacer().frame(height: 20)

                Button(action: onUndo) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 16, weight: .bold))
                        Text(s[.btn_undo])
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(palette.accent, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(PressableButtonStyle())

                Button(s[.btn_restart], action: onRestart)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                    .buttonStyle(.plain)
                    .padding(.top, 12)
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
        }
    }
}

// MARK: - Win overlay

struct WinOverlay: View {
    let stars: Int
    let moves: Int
    var starsCollected = 0
    var starsTotal = 0
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

                // Star Hunt: show what you swept and what you walked past. A dim star
                // here is the whole reason to come back to a level you have solved.
                if starsTotal > 0 {
                    HStack(spacing: 6) {
                        ForEach(0..<starsTotal, id: \.self) { i in
                            PickupStarIcon(
                                size: 22,
                                color: i < starsCollected ? palette.star : palette.textSecondary.opacity(0.28)
                            )
                        }
                    }
                    .padding(.top, 12)

                    Text(
                        starsCollected == starsTotal
                            ? s[.win_stars_all]
                            : s.f(.win_stars_missed, starsTotal - starsCollected)
                    )
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(starsCollected == starsTotal ? palette.star : palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
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
