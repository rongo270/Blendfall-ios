//
//  Engine.swift
//  Blendfall
//
//  The pure game core, ported 1:1 from the Android app's engine package:
//  colors and their blends, the board and its special-pack tiles, the level
//  parser, the slide/fuse move engine and the BFS solver that powers hints.
//  Everything here is nonisolated so the solver can run off the main actor.
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

/// Static level geometry. Beyond walls and targets, a board may carry the tiles used by
/// the special packs. Classic levels leave every one of these empty — Classic difficulty
/// comes from layout alone, never from extra pieces.
nonisolated struct Board: Sendable {
    let width: Int
    let height: Int
    private let walls: [Bool]
    let targets: [Int: GameColor]
    /// Star Hunt: optional collectibles, picked up by entering the cell.
    let pickups: Set<Int>
    /// One Way: a cell that may only be traversed in this direction.
    let gates: [Int: Direction]
    /// Portals: cell -> its paired cell. Always symmetric.
    let portals: [Int: Int]
    /// Painter: a block coming to rest here is recolored.
    let painters: [Int: GameColor]
    /// Fault Line: a cell that collapses into a wall once a block leaves it.
    let cracks: Set<Int>

    init(
        width: Int,
        height: Int,
        walls: [Bool],
        targets: [Int: GameColor],
        pickups: Set<Int> = [],
        gates: [Int: Direction] = [:],
        portals: [Int: Int] = [:],
        painters: [Int: GameColor] = [:],
        cracks: Set<Int> = []
    ) {
        self.width = width
        self.height = height
        self.walls = walls
        self.targets = targets
        self.pickups = pickups
        self.gates = gates
        self.portals = portals
        self.painters = painters
        self.cracks = cracks
    }

    func idx(_ x: Int, _ y: Int) -> Int { y * width + x }

    func isWall(_ x: Int, _ y: Int) -> Bool {
        x < 0 || y < 0 || x >= width || y >= height || walls[idx(x, y)]
    }

    func targetAt(_ x: Int, _ y: Int) -> GameColor? { targets[idx(x, y)] }

    /// True once `collapsed` has swallowed the cell, or it was solid to begin with.
    func isBlocked(_ x: Int, _ y: Int, _ collapsed: Set<Int>) -> Bool {
        isWall(x, y) || collapsed.contains(idx(x, y))
    }

    func isWon(_ blocks: [Block]) -> Bool {
        targets.allSatisfy { cell, color in
            blocks.contains { idx($0.x, $0.y) == cell && $0.color == color }
        }
    }

    var hasMechanics: Bool {
        !pickups.isEmpty || !gates.isEmpty || !portals.isEmpty
            || !painters.isEmpty || !cracks.isEmpty
    }
}

/// Everything about a position that a move can change. Blocks move; `collected` tracks
/// which Star Hunt pickups are gone; `collapsed` tracks which Fault Line tiles have
/// fallen away. Pickups are optional bonuses, so they never affect winning — which is
/// why the solver ignores `collected` when it compares states.
nonisolated struct BoardState: Sendable, Equatable {
    var blocks: [Block]
    var collected: Set<Int> = []
    var collapsed: Set<Int> = []
}

nonisolated struct Level: Identifiable, Hashable, Sendable {
    let id: String
    /// Owning group: "c1".."c6" for Classic chapters, or a pack id like "starhunt".
    let groupId: String
    let index: Int
    let par: Int
    let rows: [String]
    let tip: Strings.K?
    /// Hard cap on moves; nil means unlimited. Classic sets par + 3 from level 15.
    let moveLimit: Int?

    init(
        id: String,
        groupId: String,
        index: Int,
        par: Int,
        rows: [String],
        tip: Strings.K? = nil,
        moveLimit: Int? = nil
    ) {
        self.id = id
        self.groupId = groupId
        self.index = index
        self.par = par
        self.rows = rows
        self.tip = tip
        self.moveLimit = moveLimit
    }
}

nonisolated struct ParsedLevel: Sendable {
    let board: Board
    let blocks: [Block]

    var state: BoardState { BoardState(blocks: blocks) }
}

/// Level notation, one char per cell:
///   `#` wall   ` ` void   `.` floor
///   `R Y B O G P` blocks        `r y b o g p` targets
///   `1 2 3` primary block already sitting on the target of the color it blends into
///   `*` star pickup             `^ v < >` one-way gate
///   `( )` portal pair A         `[ ]` portal pair B
///   `4 5 6 7 8 9` painter tile (red yellow blue orange green purple)
///   `~` cracked floor
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

    private static let painterChars: [Character: GameColor] = [
        "4": .red, "5": .yellow, "6": .blue, "7": .orange, "8": .green, "9": .purple,
    ]

    private static let gateChars: [Character: Direction] = [
        "^": .up, "v": .down, "<": .left, ">": .right,
    ]

    private static let portalPairs: [(Character, Character)] = [("(", ")"), ("[", "]")]

    static func parse(_ level: Level) -> ParsedLevel {
        let height = level.rows.count
        let width = level.rows.map(\.count).max() ?? 0
        var walls = [Bool](repeating: false, count: width * height)
        var targets: [Int: GameColor] = [:]
        var pickups: Set<Int> = []
        var gates: [Int: Direction] = [:]
        var painters: [Int: GameColor] = [:]
        var cracks: Set<Int> = []
        var portalEnds: [Character: [Int]] = [:]
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
                } else if c == "*" {
                    pickups.insert(cell)
                } else if c == "~" {
                    cracks.insert(cell)
                } else if let color = blockChars[c] {
                    blocks.append(Block(id: nextId, color: color, x: x, y: y))
                    nextId += 1
                } else if let color = targetChars[c] {
                    targets[cell] = color
                } else if let color = painterChars[c] {
                    painters[cell] = color
                } else if let dir = gateChars[c] {
                    gates[cell] = dir
                } else if portalPairs.contains(where: { c == $0.0 || c == $0.1 }) {
                    portalEnds[c, default: []].append(cell)
                } else if let (blockColor, targetColor) = anvilChars[c] {
                    blocks.append(Block(id: nextId, color: blockColor, x: x, y: y))
                    nextId += 1
                    targets[cell] = targetColor
                } else {
                    fatalError("Level \(level.id): unknown char '\(c)' at \(x),\(y)")
                }
            }
        }

        var portals: [Int: Int] = [:]
        for (open, close) in portalPairs {
            let a = portalEnds[open] ?? []
            let b = portalEnds[close] ?? []
            if a.isEmpty && b.isEmpty { continue }
            precondition(
                a.count == 1 && b.count == 1,
                "Level \(level.id): portal pair '\(open)\(close)' needs exactly one of each"
            )
            portals[a[0]] = b[0]
            portals[b[0]] = a[0]
        }

        let board = Board(
            width: width,
            height: height,
            walls: walls,
            targets: targets,
            pickups: pickups,
            gates: gates,
            portals: portals,
            painters: painters,
            cracks: cracks
        )
        return ParsedLevel(board: board, blocks: blocks)
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

/// The two portal mouths a move passed through, entry first.
nonisolated struct Warp: Sendable {
    let inX: Int, inY: Int
    let outX: Int, outY: Int
}

nonisolated struct BlockMove: Sendable {
    let id: Int
    let fromX: Int, fromY: Int
    let toX: Int, toY: Int
    let fusedInto: Int?
    /// The portal hop this move took, or nil if it never warped. The UI needs the two
    /// mouths — not just a flag — to show the block going into one and out of the other
    /// instead of sliding across the board between them.
    var warp: Warp?
}

nonisolated struct MoveResult: Sendable {
    let state: BoardState
    let moves: [BlockMove]
    let fusions: [Fusion]

    var blocks: [Block] { state.blocks }
    var changed: Bool { !moves.isEmpty }
}

nonisolated enum Engine {

    /// Guards against a portal ring sending a block round forever.
    private static let stepCap = 256

    static func applyMove(board: Board, blocks: [Block], color: GameColor, dir: Direction) -> MoveResult {
        applyMove(board: board, state: BoardState(blocks: blocks), color: color, dir: dir)
    }

    /// Slide every block of `color` one board-length in `dir` until each hits a wall,
    /// a collapsed tile, the void, or another block. Sliding into a mixable primary fuses
    /// the mover into it: the mover disappears and the stationary block takes the blended
    /// color.
    ///
    /// Special tiles (all unused by Classic): star pickups are swept up by entering a cell,
    /// one-way gates may only be traversed along the arrow, portals teleport a block to
    /// their pair and let it keep going, painters recolor a block that comes to rest on
    /// them, and cracked tiles collapse once a block leaves them. Collapses are applied
    /// only after every mover has settled, so the board never shifts mid-move.
    static func applyMove(
        board: Board,
        state: BoardState,
        color: GameColor,
        dir: Direction
    ) -> MoveResult {
        let blocks = state.blocks
        var byId = Dictionary(uniqueKeysWithValues: blocks.map { ($0.id, $0) })
        var occupied = Dictionary(uniqueKeysWithValues: blocks.map { (board.idx($0.x, $0.y), $0) })

        // Leading blocks settle first so followers can stack behind them. Ties break on
        // id, which is the order the blocks arrive in — matching Kotlin's stable sort.
        let movers = blocks.filter { $0.color == color }.sorted { a, b in
            let (l, r): (Int, Int)
            switch dir {
            case .right: (l, r) = (b.x, a.x)
            case .left: (l, r) = (a.x, b.x)
            case .down: (l, r) = (b.y, a.y)
            case .up: (l, r) = (a.y, b.y)
            }
            return l == r ? a.id < b.id : l < r
        }

        var moveList: [BlockMove] = []
        var fusions: [Fusion] = []
        var collected = state.collected
        var vacated: Set<Int> = []

        for m in movers {
            guard let cur = byId[m.id] else { continue }
            let startCell = board.idx(cur.x, cur.y)
            occupied.removeValue(forKey: startCell)
            var x = cur.x
            var y = cur.y
            var fusion: Fusion?
            // Only the first hop is recorded: it is the one the player is tracking, and
            // a second hop in the same move would just overwrite the story on screen.
            var warp: Warp?
            var path: [Int] = [startCell]
            var steps = 0

            while steps < stepCap {
                steps += 1
                // A gate under our feet only lets us leave along the arrow.
                let here = board.idx(x, y)
                if let leaveGate = board.gates[here], leaveGate != dir { break }

                let nx = x + dir.dx
                let ny = y + dir.dy
                if board.isBlocked(nx, ny, state.collapsed) { break }
                let nextCell = board.idx(nx, ny)

                // A gate ahead only admits travel along the arrow.
                if let enterGate = board.gates[nextCell], enterGate != dir { break }

                if let occ = occupied[nextCell] {
                    if let mixed = GameColor.mix(cur.color, occ.color) {
                        var recolored = occ
                        recolored.color = mixed
                        byId[occ.id] = recolored
                        occupied[nextCell] = recolored
                        byId.removeValue(forKey: cur.id)
                        fusion = Fusion(movedId: cur.id, anvilId: occ.id, result: mixed, x: nx, y: ny)
                    }
                    break
                }

                x = nx
                y = ny
                path.append(nextCell)
                if board.pickups.contains(nextCell) { collected.insert(nextCell) }

                // Portals carry the block through and it keeps travelling.
                if let exit = board.portals[nextCell] {
                    let ex = exit % board.width
                    let ey = exit / board.width
                    if !board.isBlocked(ex, ey, state.collapsed) && occupied[exit] == nil {
                        if warp == nil { warp = Warp(inX: nx, inY: ny, outX: ex, outY: ey) }
                        x = ex
                        y = ey
                        path.append(exit)
                        if board.pickups.contains(exit) { collected.insert(exit) }
                    }
                }
            }

            if let fusion {
                // The mover vanished, so every tile it touched counts as vacated.
                vacated.formUnion(path)
                moveList.append(BlockMove(
                    id: cur.id, fromX: cur.x, fromY: cur.y,
                    toX: fusion.x, toY: fusion.y, fusedInto: fusion.anvilId, warp: warp
                ))
                fusions.append(fusion)
            } else {
                // Everything except the resting tile was left behind.
                vacated.formUnion(path.dropLast())
                let restCell = board.idx(x, y)
                let travelled = x != cur.x || y != cur.y
                // Paint only on arrival, so a block that could not move is never
                // silently recolored by the tile it was already standing on.
                let painted = travelled ? board.painters[restCell] : nil
                var moved = cur
                moved.x = x
                moved.y = y
                moved.color = painted ?? cur.color
                byId[cur.id] = moved
                occupied[restCell] = moved
                if travelled {
                    moveList.append(BlockMove(
                        id: cur.id, fromX: cur.x, fromY: cur.y,
                        toX: x, toY: y, fusedInto: nil, warp: warp
                    ))
                }
            }
        }

        let collapsed = board.cracks.isEmpty
            ? state.collapsed
            : state.collapsed.union(vacated.filter { board.cracks.contains($0) })

        return MoveResult(
            state: BoardState(
                blocks: byId.values.sorted { $0.id < $1.id },
                collected: collected,
                collapsed: collapsed
            ),
            moves: moveList,
            fusions: fusions
        )
    }

    static func starsFor(par: Int, moves: Int) -> Int {
        if moves <= par { return 3 }
        if moves <= par + 2 { return 2 }
        return 1
    }
}

// MARK: - Solver

/// Breadth-first solver over board states. Small boards + few blocks keep the
/// state space tiny, so this powers both level verification and in-game hints
/// that work from any position.
nonisolated enum Solver {

    struct Step: Hashable, Sendable {
        let color: GameColor
        let dir: Direction
    }

    /// Collapsed tiles change what is reachable, so they belong in the key. Collected
    /// pickups never do — they are optional bonuses — so folding them in would only
    /// split identical positions and blow the state space up.
    private static func key(_ state: BoardState) -> String {
        let blocks = state.blocks
            .sorted { ($0.y, $0.x) < ($1.y, $1.x) }
            .map { "\($0.x),\($0.y),\($0.color.rawValue)" }
            .joined(separator: ";")
        if state.collapsed.isEmpty { return blocks }
        return blocks + "|" + state.collapsed.sorted().map(String.init).joined(separator: ",")
    }

    static func solve(board: Board, start: [Block], maxNodes: Int = 400_000) -> [Step]? {
        solve(board: board, start: BoardState(blocks: start), maxNodes: maxNodes)
    }

    /// Returns the shortest winning move sequence from `start`, or nil.
    static func solve(board: Board, start: BoardState, maxNodes: Int = 400_000) -> [Step]? {
        if board.isWon(start.blocks) { return [] }
        let startKey = key(start)
        var cameFrom: [String: (String, Step)] = [:]
        var states: [String: BoardState] = [startKey: start]
        var queue: [String] = [startKey]
        var head = 0
        var expanded = 0

        while head < queue.count {
            let curKey = queue[head]
            head += 1
            let cur = states[curKey]!
            expanded += 1
            if expanded > maxNodes { return nil }
            let colors = Set(cur.blocks.map(\.color))
            for color in colors {
                for dir in Direction.allCases {
                    let res = Engine.applyMove(board: board, state: cur, color: color, dir: dir)
                    if !res.changed { continue }
                    let k = key(res.state)
                    if states[k] != nil { continue }
                    states[k] = res.state
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

    /// Optimal move count from `start`, or nil when the position is dead.
    static func distance(board: Board, start: BoardState, maxNodes: Int = 400_000) -> Int? {
        solve(board: board, start: start, maxNodes: maxNodes)?.count
    }
}
