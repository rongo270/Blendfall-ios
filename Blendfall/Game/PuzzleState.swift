//
//  PuzzleState.swift
//  Blendfall
//
//  Live state of one puzzle attempt — blocks, selection, undo history, win
//  detection. Shared by the campaign (GameViewModel adds hints/stars) and
//  Blitz (BlitzModel adds the clock and the level queue). Undo is always
//  unlimited, and undoing is the intended way out of a failed run, so it stays
//  available after the move limit trips.
//

import Foundation
import Observation

/// A fused-away block kept briefly on screen so it can melt into its anvil.
struct Ghost: Identifiable, Equatable {
    let id: Int
    let color: GameColor
    let x: Int
    let y: Int
}

/// One block's trip through a portal, with every waypoint the animation needs: where it
/// set off, the mouth it entered, the mouth it left, and where it finally stopped.
///
/// Without this the block simply appears on the far side of the board, which reads as
/// "it slid there" — the one thing portals do not do. The board hides the real block for
/// `warpDuration` and plays this instead.
struct WarpFx: Identifiable, Equatable {
    let id: Int
    let color: GameColor
    let fromX: Int, fromY: Int
    let inX: Int, inY: Int
    let outX: Int, outY: Int
    let toX: Int, toY: Int
}

/// Total length of the portal animation; the two legs split it evenly.
let warpDuration = 0.56

enum GameEffect {
    case slide, fuse, blocked, pickup, warp, win, fail
}

@Observable
final class PuzzleState {

    let level: Level
    let parsed: ParsedLevel

    private(set) var state: BoardState
    private(set) var ghosts: [Ghost] = []
    /// Portal trips currently playing. The board hides these blocks while they run.
    private(set) var warps: [WarpFx] = []
    private(set) var selected: GameColor?
    private(set) var moveCount = 0
    private(set) var won = false
    private(set) var failed = false
    private(set) var starsEarned = 0

    var board: Board { parsed.board }
    var blocks: [Block] { state.blocks }

    /// Star Hunt pickups swept up so far.
    var collectedCount: Int { state.collected.count }
    let pickupTotal: Int

    let moveLimit: Int?
    var movesLeft: Int? { moveLimit.map { max(0, $0 - moveCount) } }

    /// Fires on every move/undo/restart — the campaign clears its shown hint here.
    var onPositionChanged: () -> Void = {}
    /// Fires for haptics/sound on every slide, fuse, blocked move, pickup, warp and win.
    var onEffect: (GameEffect) -> Void = { _ in }

    private var undoStack: [(state: BoardState, moveCount: Int)] = []
    private var ghostTask: Task<Void, Never>?
    private var warpTask: Task<Void, Never>?
    private var winTask: Task<Void, Never>?

    var canUndo: Bool { !undoStack.isEmpty }

    /// - Parameter enforceMoveLimit: Blitz ignores the campaign move limit — there it is
    ///   the clock that presses.
    init(level: Level, enforceMoveLimit: Bool = true) {
        self.level = level
        parsed = LevelParser.parse(level)
        state = parsed.state
        pickupTotal = parsed.board.pickups.count
        moveLimit = enforceMoveLimit ? level.moveLimit : nil
        selected = Self.firstColor(parsed.blocks)
    }

    private static func firstColor(_ list: [Block]) -> GameColor? {
        GameColor.allCases.first { c in list.contains { $0.color == c } }
    }

    func select(_ color: GameColor) {
        if blocks.contains(where: { $0.color == color }) { selected = color }
    }

    func move(_ dir: Direction) {
        if won || failed { return }
        guard let color = selected else { return }
        let result = Engine.applyMove(board: parsed.board, state: state, color: color, dir: dir)
        if !result.changed {
            onEffect(.blocked)
            return
        }
        let before = state
        undoStack.append((before, moveCount))
        onPositionChanged()

        state = result.state
        moveCount += 1

        if !result.fusions.isEmpty {
            let beforeById = Dictionary(uniqueKeysWithValues: before.blocks.map { ($0.id, $0) })
            ghosts = result.fusions.compactMap { fusion in
                beforeById[fusion.movedId].map { Ghost(id: $0.id, color: $0.color, x: fusion.x, y: fusion.y) }
            }
            ghostTask?.cancel()
            ghostTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(320))
                guard !Task.isCancelled else { return }
                self?.ghosts = []
            }
            onEffect(.fuse)
        } else {
            onEffect(.slide)
        }

        if result.state.collected.count > before.collected.count {
            onEffect(.pickup)
        }

        // A block that warped is hidden and replayed as a WarpFx, so the player sees it
        // enter one mouth and leave the other rather than crossing the board.
        let hops: [WarpFx] = result.moves.compactMap { m in
            guard let w = m.warp,
                  let blockColor = before.blocks.first(where: { $0.id == m.id })?.color
            else { return nil }
            return WarpFx(
                id: m.id,
                color: blockColor,
                fromX: m.fromX, fromY: m.fromY,
                inX: w.inX, inY: w.inY,
                outX: w.outX, outY: w.outY,
                toX: m.toX, toY: m.toY
            )
        }
        if !hops.isEmpty {
            warps = hops
            onEffect(.warp)
            warpTask?.cancel()
            warpTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(warpDuration))
                guard !Task.isCancelled else { return }
                self?.warps = []
            }
        }

        // Selected color may have fused away or been repainted.
        if !blocks.contains(where: { $0.color == color }) {
            selected = Self.firstColor(blocks)
        }

        if parsed.board.isWon(blocks) {
            starsEarned = Engine.starsFor(par: level.par, moves: moveCount)
            winTask?.cancel()
            // A winning move that warped has to finish its trip before the dialog covers
            // the board, or the player never sees what solved the level.
            let settle = hops.isEmpty ? 0.45 : warpDuration + 0.12
            winTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(settle))
                guard !Task.isCancelled, let self else { return }
                self.onEffect(.win)
                self.won = true
            }
        } else if let limit = moveLimit, moveCount >= limit {
            failed = true
            onEffect(.fail)
        }
    }

    func undo() {
        guard !won, let last = undoStack.popLast() else { return }
        state = last.state
        moveCount = last.moveCount
        ghosts = []
        warps = []
        failed = false
        onPositionChanged()
        if selected == nil || !blocks.contains(where: { $0.color == selected }) {
            selected = Self.firstColor(blocks)
        }
    }

    func restart() {
        winTask?.cancel()
        state = parsed.state
        ghosts = []
        warps = []
        moveCount = 0
        won = false
        failed = false
        starsEarned = 0
        undoStack.removeAll()
        selected = Self.firstColor(parsed.blocks)
        onPositionChanged()
    }
}

// MARK: - Campaign hints

enum HintState {
    case idle, thinking, noSolution, offPath
}

@Observable
final class GameViewModel {

    let level: Level
    let play: PuzzleState

    private(set) var hint: Solver.Step?
    private(set) var hintState: HintState = .idle

    private var hintTask: Task<Void, Never>?

    init(level: Level) {
        self.level = level
        play = PuzzleState(level: level)
        play.onPositionChanged = { [weak self] in self?.clearHint() }
    }

    func restart() {
        play.restart()
    }

    /// `onFound` runs only when a directional hint is actually produced — that's when a
    /// credit is spent. Off the 3-star path the hint says to undo instead (free), and
    /// re-tapping while the current hint is still on screen is free too.
    func requestHint(onFound: @escaping () -> Void = {}) {
        if play.won || play.failed || hintState == .thinking || hint != nil { return }
        hintTask?.cancel()
        hintState = .thinking
        let board = play.parsed.board
        let state = play.state
        hintTask = Task { [weak self] in
            let path = await Task.detached(priority: .userInitiated) {
                Solver.solve(board: board, start: state)
            }.value
            guard !Task.isCancelled, let self else { return }
            if path == nil || path!.isEmpty {
                self.hintState = .noSolution
            } else if self.play.moveCount + path!.count > self.level.par {
                self.hintState = .offPath
            } else {
                self.hint = path!.first
                self.hintState = .idle
                self.play.select(path!.first!.color)
                onFound()
            }
        }
    }

    func dismissHintMessage() {
        if hintState == .noSolution || hintState == .offPath {
            hintState = .idle
        }
    }

    private func clearHint() {
        hintTask?.cancel()
        hint = nil
        hintState = .idle
    }
}

// MARK: - Blitz

/// Blitz: solve as many levels as possible before the clock runs out.
/// Levels are drawn at random from Classic, climbing one rung up the par ladder
/// every two solves. Score = levels solved; best per duration is persisted by
/// the caller.
@Observable
final class BlitzModel {

    enum Phase {
        case setup, playing, finished
    }

    private(set) var phase: Phase = .setup
    private(set) var durationSec = blitzDurations.first!
    private(set) var remainingSec = 0
    private(set) var score = 0
    private(set) var isNewBest = false
    private(set) var play: PuzzleState?

    /// Forwarded from every level's PuzzleState so the screen wires haptics once.
    var onEffect: (GameEffect) -> Void = { _ in }

    private var timerTask: Task<Void, Never>?
    private var bestAtStart = 0
    private var recentIds: [String] = []

    /// Difficulty ladder: Classic levels grouped by par, easiest rung first. Blitz stays
    /// out of the mechanic packs — there is no time in a speed run to read a new tile.
    private let ladder: [[Level]] = Dictionary(grouping: Levels.classic, by: \.par)
        .sorted { $0.key < $1.key }
        .map(\.value)

    func selectDuration(_ sec: Int) {
        if phase == .setup { durationSec = sec }
    }

    func start(currentBest: Int) {
        bestAtStart = currentBest
        score = 0
        isNewBest = false
        remainingSec = durationSec
        phase = .playing
        nextLevel()
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while let self, self.remainingSec > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                self.remainingSec -= 1
            }
            guard !Task.isCancelled, let self else { return }
            self.isNewBest = self.score > self.bestAtStart
            self.phase = .finished
        }
    }

    /// Called by the screen once the win animation of the current level played.
    func onSolved() {
        guard phase == .playing else { return }
        score += 1
        nextLevel()
    }

    func skip() {
        guard phase == .playing else { return }
        nextLevel()
    }

    func exitToSetup() {
        timerTask?.cancel()
        play = nil
        phase = .setup
    }

    private func nextLevel() {
        let rung = min(score / 2, ladder.count - 1)
        var candidates = ladder[rung].filter { !recentIds.contains($0.id) }
        if candidates.isEmpty { candidates = ladder[rung] }
        let level = candidates.randomElement()!
        recentIds.append(level.id)
        if recentIds.count > 20 { recentIds.removeFirst() }
        let next = PuzzleState(level: level, enforceMoveLimit: false)
        next.onEffect = { [weak self] in self?.onEffect($0) }
        play = next
    }
}
