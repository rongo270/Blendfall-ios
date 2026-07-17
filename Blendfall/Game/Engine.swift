//
//  Engine.swift
//  Blendfall
//
//  The pure game core, ported 1:1 from the Android app's engine package:
//  colors and their blends, the board, the level parser, the slide/fuse move
//  engine and the BFS solver that powers hints. Everything here is nonisolated
//  so the solver can run off the main actor.
//

import Foundation

nonisolated enum GameColor: Int, CaseIterable, Hashable, Sendable {
    case red, yellow, blue, orange, green, purple

    var isPrimary: Bool {
        switch self {
        case .red, .yellow, .blue: return true
        case .orange, .green, .purple: return false
        }
    }

    /// Color-theory fusion: two distinct primaries blend into a secondary.
    static func mix(_ a: GameColor, _ b: GameColor) -> GameColor? {
        switch (a, b) {
        case (.red, .yellow), (.yellow, .red): return .orange
        case (.red, .blue), (.blue, .red): return .purple
        case (.yellow, .blue), (.blue, .yellow): return .green
        default: return nil
        }
    }
}

nonisolated enum Direction: CaseIterable, Hashable, Sendable {
    case up, down, left, right

    var dx: Int {
        switch self {
        case .left: return -1
        case .right: return 1
        default: return 0
        }
    }

    var dy: Int {
        switch self {
        case .up: return -1
        case .down: return 1
        default: return 0
        }
    }
}

nonisolated struct Block: Identifiable, Hashable, Sendable {
    let id: Int
    var color: GameColor
    var x: Int
    var y: Int
}

/// Static level geometry: walls (incl. out-of-grid/void) and colored target cells.
nonisolated struct Board: Sendable {
    let width: Int
    let height: Int
    private let walls: [Bool]
    let targets: [Int: GameColor]

    init(width: Int, height: Int, walls: [Bool], targets: [Int: GameColor]) {
        self.width = width
        self.height = height
        self.walls = walls
        self.targets = targets
    }

    func idx(_ x: Int, _ y: Int) -> Int { y * width + x }

    func isWall(_ x: Int, _ y: Int) -> Bool {
        x < 0 || y < 0 || x >= width || y >= height || walls[idx(x, y)]
    }

    func targetAt(_ x: Int, _ y: Int) -> GameColor? { targets[idx(x, y)] }

    func isWon(_ blocks: [Block]) -> Bool {
        targets.allSatisfy { cell, color in
            blocks.contains { idx($0.x, $0.y) == cell && $0.color == color }
        }
    }
}

nonisolated struct Level: Identifiable, Hashable, Sendable {
    let id: String
    let pack: Int
    let index: Int
    let par: Int
    let rows: [String]
    let tip: Strings.K?

    init(id: String, pack: Int, index: Int, par: Int, rows: [String], tip: Strings.K? = nil) {
        self.id = id
        self.pack = pack
        self.index = index
        self.par = par
        self.rows = rows
        self.tip = tip
    }
}

nonisolated struct ParsedLevel: Sendable {
    let board: Board
    let blocks: [Block]
}

nonisolated enum LevelParser {
    private static let blockChars: [Character: GameColor] = [
        "R": .red, "Y": .yellow, "B": .blue, "O": .orange, "G": .green, "P": .purple,
    ]
    private static let targetChars: [Character: GameColor] = [
        "r": .red, "y": .yellow, "b": .blue, "o": .orange, "g": .green, "p": .purple,
    ]

    /// Anvil-on-target: a primary block sitting on the target of the color it blends into.
    private static let anvilChars: [Character: (GameColor, GameColor)] = [
        "1": (.yellow, .orange),
        "2": (.blue, .green),
        "3": (.red, .purple),
    ]

    static func parse(_ level: Level) -> ParsedLevel {
        let height = level.rows.count
        let width = level.rows.map(\.count).max() ?? 0
        var walls = [Bool](repeating: false, count: width * height)
        var targets: [Int: GameColor] = [:]
        var blocks: [Block] = []
        var nextId = 0
        for y in 0..<height {
            let row = Array(level.rows[y])
            for x in 0..<width {
                let c: Character = x < row.count ? row[x] : " "
                let cell = y * width + x
                if c == "#" || c == " " {
                    walls[cell] = true
                } else if c == "." {
                    // floor
                } else if let color = blockChars[c] {
                    blocks.append(Block(id: nextId, color: color, x: x, y: y))
                    nextId += 1
                } else if let color = targetChars[c] {
                    targets[cell] = color
                } else if let (blockColor, targetColor) = anvilChars[c] {
                    blocks.append(Block(id: nextId, color: blockColor, x: x, y: y))
                    nextId += 1
                    targets[cell] = targetColor
                } else {
                    fatalError("Level \(level.id): unknown char '\(c)' at \(x),\(y)")
                }
            }
        }
        return ParsedLevel(board: Board(width: width, height: height, walls: walls, targets: targets), blocks: blocks)
    }
}

// MARK: - Move engine

/// A fusion: the moving block was consumed by the anvil block, which changed color.
nonisolated struct Fusion: Sendable {
    let movedId: Int
    let anvilId: Int
    let result: GameColor
    let x: Int
    let y: Int
}

nonisolated struct BlockMove: Sendable {
    let id: Int
    let fromX: Int, fromY: Int
    let toX: Int, toY: Int
    let fusedInto: Int?
}

nonisolated struct MoveResult: Sendable {
    let blocks: [Block]
    let moves: [BlockMove]
    let fusions: [Fusion]

    var changed: Bool { !moves.isEmpty }
}

nonisolated enum Engine {

    /// Slide every block of `color` one board-length in `dir` until each hits a wall,
    /// the void, or another block. Sliding into a mixable primary fuses the mover into
    /// it: the mover disappears and the stationary block takes the blended color.
    static func applyMove(board: Board, blocks: [Block], color: GameColor, dir: Direction) -> MoveResult {
        var byId = Dictionary(uniqueKeysWithValues: blocks.map { ($0.id, $0) })
        var occupied = Dictionary(uniqueKeysWithValues: blocks.map { (board.idx($0.x, $0.y), $0) })

        // Leading blocks settle first so followers can stack behind them.
        let movers = blocks.filter { $0.color == color }.sorted { a, b in
            switch dir {
            case .right: return a.x > b.x
            case .left: return a.x < b.x
            case .down: return a.y > b.y
            case .up: return a.y < b.y
            }
        }

        var moveList: [BlockMove] = []
        var fusions: [Fusion] = []

        for m in movers {
            guard let cur = byId[m.id] else { continue }
            occupied.removeValue(forKey: board.idx(cur.x, cur.y))
            var x = cur.x
            var y = cur.y
            var fusion: Fusion?
            while true {
                let nx = x + dir.dx
                let ny = y + dir.dy
                if board.isWall(nx, ny) { break }
                if let occ = occupied[board.idx(nx, ny)] {
                    if let mixed = GameColor.mix(cur.color, occ.color) {
                        var recolored = occ
                        recolored.color = mixed
                        byId[occ.id] = recolored
                        occupied[board.idx(nx, ny)] = recolored
                        byId.removeValue(forKey: cur.id)
                        fusion = Fusion(movedId: cur.id, anvilId: occ.id, result: mixed, x: nx, y: ny)
                    }
                    break
                }
                x = nx
                y = ny
            }
            if let fusion {
                moveList.append(BlockMove(id: cur.id, fromX: cur.x, fromY: cur.y, toX: fusion.x, toY: fusion.y, fusedInto: fusion.anvilId))
                fusions.append(fusion)
            } else {
                var moved = cur
                moved.x = x
                moved.y = y
                byId[cur.id] = moved
                occupied[board.idx(x, y)] = moved
                if x != cur.x || y != cur.y {
                    moveList.append(BlockMove(id: cur.id, fromX: cur.x, fromY: cur.y, toX: x, toY: y, fusedInto: nil))
                }
            }
        }
        return MoveResult(blocks: byId.values.sorted { $0.id < $1.id }, moves: moveList, fusions: fusions)
    }

    static func starsFor(par: Int, moves: Int) -> Int {
        if moves <= par { return 3 }
        if moves <= par + 2 { return 2 }
        return 1
    }
}

// MARK: - Solver

/// Breadth-first solver over block configurations. Small boards + few blocks keep the
/// state space tiny, so this powers both level verification and in-game hints
/// that work from any position.
nonisolated enum Solver {

    struct Step: Hashable, Sendable {
        let color: GameColor
        let dir: Direction
    }

    private static func key(_ blocks: [Block]) -> String {
        blocks.sorted { ($0.y, $0.x) < ($1.y, $1.x) }
            .map { "\($0.x),\($0.y),\($0.color.rawValue)" }
            .joined(separator: ";")
    }

    /// Returns the shortest winning move sequence from `start`, or nil.
    static func solve(board: Board, start: [Block], maxNodes: Int = 400_000) -> [Step]? {
        if board.isWon(start) { return [] }
        let startKey = key(start)
        var cameFrom: [String: (String, Step)] = [:]
        var states: [String: [Block]] = [startKey: start]
        var queue: [String] = [startKey]
        var head = 0
        var expanded = 0

        while head < queue.count {
            let curKey = queue[head]
            head += 1
            let cur = states[curKey]!
            expanded += 1
            if expanded > maxNodes { return nil }
            let colors = Set(cur.map(\.color))
            for color in colors {
                for dir in Direction.allCases {
                    let res = Engine.applyMove(board: board, blocks: cur, color: color, dir: dir)
                    if !res.changed { continue }
                    let k = key(res.blocks)
                    if states[k] != nil { continue }
                    states[k] = res.blocks
                    cameFrom[k] = (curKey, Step(color: color, dir: dir))
                    if board.isWon(res.blocks) {
                        // Reconstruct path
                        var path: [Step] = []
                        var at = k
                        while at != startKey {
                            let (prev, step) = cameFrom[at]!
                            path.append(step)
                            at = prev
                        }
                        path.reverse()
                        return path
                    }
                    queue.append(k)
                }
            }
        }
        return nil
    }
}
