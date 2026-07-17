//
//  PuzzleState.swift
//  Blendfall
//
//  Live state of one puzzle attempt — blocks, selection, undo history, win
//  detection. Shared by the campaign (GameViewModel adds hints/stars) and
//  Blitz (BlitzModel adds the clock and the level queue). Undo is always
//  unlimited.
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

enum GameEffect {
    case slide, fuse, blocked, win
}

@Observable
final class PuzzleState {

    let level: Level
    let parsed: ParsedLevel

    private(set) var blocks: [Block]
    private(set) var ghosts: [Ghost] = []
    private(set) var selected: GameColor?
    private(set) var moveCount = 0
    private(set) var won = false
    private(set) var starsEarned = 0

    /// Fires on every move/undo/restart — the campaign clears its shown hint here.
    var onPositionChanged: () -> Void = {}
    /// Fires for haptics/sound on every slide, fuse, blocked move and win.
    var onEffect: (GameEffect) -> Void = { _ in }

    private var undoStack: [(blocks: [Block], moveCount: Int)] = []
    private var ghostTask: Task<Void, Never>?
    private var winTask: Task<Void, Never>?

    var canUndo: Bool { !undoStack.isEmpty }

    init(level: Level) {
        self.level = level
        parsed = LevelParser.parse(level)
        blocks = parsed.blocks
        selected = Self.firstColor(parsed.blocks)
    }

    private static func firstColor(_ list: [Block]) -> GameColor? {
        GameColor.allCases.first { c in list.contains { $0.color == c } }
    }

    func select(_ color: GameColor) {
        if blocks.contains(where: { $0.color == color }) { selected = color }
    }

    func move(_ dir: Direction) {
        if won { return }
        guard let color = selected else { return }
        let result = Engine.applyMove(board: parsed.board, blocks: blocks, color: color, dir: dir)
        if !result.changed {
            onEffect(.blocked)
            return
        }
        let before = blocks
        undoStack.append((before, moveCount))
        onPositionChanged()

        blocks = result.blocks
        moveCount += 1

        if !result.fusions.isEmpty {
            let beforeById = Dictionary(uniqueKeysWithValues: before.map { ($0.id, $0) })
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

        // Selected color may have fused away.
        if !blocks.contains(where: { $0.color == color }) {
            selected = Self.firstColor(blocks)
        }

        if parsed.board.isWon(blocks) {
            starsEarned = Engine.starsFor(par: level.par, moves: moveCount)
            winTask?.cancel()
            winTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled, let self else { return }
                self.onEffect(.win)
                self.won = true
            }
        }
    }

    func undo() {
        guard let last = undoStack.popLast(), !won else { return }
        blocks = last.blocks
        moveCount = last.moveCount
        ghosts = []
        onPositionChanged()
        if selected == nil || !blocks.contains(where: { $0.color == selected }) {
            selected = Self.firstColor(blocks)
        }
    }

    func restart() {
        winTask?.cancel()
        blocks = parsed.blocks
        ghosts = []
        moveCount = 0
        won = false
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
        if play.won || hintState == .thinking || hint != nil { return }
        hintTask?.cancel()
        hintState = .thinking
        let board = play.parsed.board
        let blocks = play.blocks
        hintTask = Task { [weak self] in
            let path = await Task.detached(priority: .userInitiated) {
                Solver.solve(board: board, start: blocks)
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
/// Levels are drawn at random from the whole catalog, climbing one rung up
/// the par ladder every two solves. Score = levels solved; best per duration
/// is persisted by the caller.
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

    /// Difficulty ladder: all levels grouped by par, easiest rung first.
    private let ladder: [[Level]] = Dictionary(grouping: Levels.all, by: \.par)
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
        let next = PuzzleState(level: level)
        next.onEffect = { [weak self] in self?.onEffect($0) }
        play = next
    }
}
