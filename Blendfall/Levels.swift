//
//  Levels.swift
//  Blendfall
//
//  The hand-authored tutorial packs (1-4) and the level catalog API.
//  Level notation:
//    '#' wall   ' ' void   '.' floor
//    R Y B O G P  blocks   r y b o g p  targets
//    1 = yellow block on orange target, 2 = blue on green, 3 = red on purple
//

import Foundation

nonisolated struct Pack: Identifiable, Sendable {
    let id: Int
    let nameKey: Strings.K
    let premium: Bool
    let levels: [Level]
}

nonisolated enum Levels {

    private static func level(_ pack: Int, _ index: Int, _ par: Int, tip: Strings.K? = nil, _ rows: String...) -> Level {
        Level(id: "p\(pack + 1)l\(index + 1)", pack: pack, index: index, par: par, rows: rows, tip: tip)
    }

    static let packs: [Pack] = [
        // ------------------------------------------------- Pack 1 · First Steps (free)
        Pack(id: 0, nameKey: .pack_1_name, premium: false, levels: [
            // 1 · Slide
            level(0, 0, 1, tip: .tip_select,
                  "#####",
                  "#R.r#",
                  "#####"),
            // 2 · Two Turns
            level(0, 1, 2, tip: .tip_turns,
                  "#####",
                  "#R..#",
                  "#..r#",
                  "#####"),
            // 3 · Stack Up
            level(0, 2, 1, tip: .tip_group,
                  "#####",
                  "#R.r#",
                  "#R.r#",
                  "#####"),
            // 4 · Green Blocker (secondaries are inert — they block, never blend)
            level(0, 3, 2, tip: .tip_blocker,
                  "#####",
                  "#RGr#",
                  "#.g.#",
                  "#####"),
            // 5 · Use the Blocker
            level(0, 4, 1, tip: .tip_stopper,
                  "######",
                  "#R.rG#",
                  "######"),
            // 6 · Park It
            level(0, 5, 2,
                  "######",
                  "#R.r.#",
                  "#...G#",
                  "######"),
            // 7 · Round Trip
            level(0, 6, 3,
                  "######",
                  "#R...#",
                  "###..#",
                  "#r...#",
                  "######"),
            // 8 · Three Reds
            level(0, 7, 2,
                  "#######",
                  "#R.R.R#",
                  "#rrr..#",
                  "#######"),
            // 9 · Traffic
            level(0, 8, 3,
                  "######",
                  "#P..Y#",
                  "#.##.#",
                  "#py..#",
                  "######"),
            // 10 · Keystone
            level(0, 9, 3,
                  "#######",
                  "#R..O.#",
                  "#.##..#",
                  "#..ro.#",
                  "##..###",
                  "#######"),
        ]),

        // ------------------------------------------------- Pack 2 · Alchemy (free)
        Pack(id: 1, nameKey: .pack_2_name, premium: false, levels: [
            // 1 · First Blend
            level(1, 0, 2, tip: .tip_mix,
                  "#######",
                  "#R.Y.o#",
                  "#######"),
            // 2 · Purple Rain
            level(1, 1, 2, tip: .tip_purple,
                  "#####",
                  "#B..#",
                  "#...#",
                  "#R..#",
                  "#p..#",
                  "#####"),
            // 3 · Green Light
            level(1, 2, 2, tip: .tip_green,
                  "######",
                  "#Y.B.#",
                  "#....#",
                  "#g...#",
                  "######"),
            // 4 · Don't Mix
            level(1, 3, 2, tip: .tip_avoid,
                  "######",
                  "#R..Y#",
                  "#r..y#",
                  "######"),
            // 5 · Assembly Line
            level(1, 4, 2,
                  "#######",
                  "#R.Y.o#",
                  "#R.Y.o#",
                  "#######"),
            // 6 · Leftovers
            level(1, 5, 2, tip: .tip_leftover,
                  "#######",
                  "#RRrYo#",
                  "#######"),
            // 7 · Sandwich
            level(1, 6, 3,
                  "#######",
                  "#R.B.R#",
                  "#..p.r#",
                  "#######"),
            // 8 · Two Brews
            level(1, 7, 3,
                  "#####",
                  "#Y.R#",
                  "#...#",
                  "#B.B#",
                  "#g.p#",
                  "#####"),
            // 9 · Choose Wisely
            level(1, 8, 3,
                  "#######",
                  "#Y.R.Y#",
                  "#o....#",
                  "##...y#",
                  "#######"),
            // 10 · Spectrum
            level(1, 9, 3,
                  "#######",
                  "#R.Y.B#",
                  "#.....#",
                  "#1#2#3#",
                  "#######"),
        ]),

        // ------------------------------------------------- Pack 3 · Chain Lab (free)
        Pack(id: 2, nameKey: .pack_3_name, premium: false, levels: [
            // 1 · Double Duty
            level(2, 0, 2, tip: .tip_blend_one,
                  "#######",
                  "#R.Y..#",
                  "#..o..#",
                  "#Rr#..#",
                  "#######"),
            // 2 · Wrong Neighbor
            level(2, 1, 3,
                  "#######",
                  "#RY..r#",
                  "#....y#",
                  "#######"),
            // 3 · Roadblock
            level(2, 2, 3, tip: .tip_avoid,
                  "#########",
                  "#Y..B...#",
                  "#R.r....#",
                  "#########"),
            // 4 · Relay
            level(2, 3, 4,
                  "#########",
                  "#R.Y.Y.B#",
                  "#..o...g#",
                  "#########"),
            // 5 · Undertow
            level(2, 4, 2,
                  "######",
                  "#B..R#",
                  "#....#",
                  "#...p#",
                  "######"),
            // 6 · Gatekeeper
            level(2, 5, 3,
                  "########",
                  "#RR.B.p#",
                  "#..r...#",
                  "########"),
            // 7 · Boomerang
            level(2, 6, 2,
                  "#########",
                  "#o..R..Y#",
                  "#########"),
            // 8 · Trifecta
            level(2, 7, 3,
                  "#########",
                  "#R.....1#",
                  "#Y.....2#",
                  "#B.....3#",
                  "#########"),
            // 9 · Squeeze
            level(2, 8, 3,
                  "#######",
                  "#RYY.o#",
                  "#..y..#",
                  "#######"),
            // 10 · The Lab
            level(2, 9, 5,
                  "##########",
                  "#R.Y.Y.BB#",
                  "#..o...gb#",
                  "##########"),
        ]),

        // ------------------------------------------------- Pack 4 · Master Blender (free)
        Pack(id: 3, nameKey: .pack_4_name, premium: false, levels: [
            // 1 · Cold Open
            level(3, 0, 2,
                  "#######",
                  "#B...R#",
                  "#.###.#",
                  "#p....#",
                  "#######"),
            // 2 · Interference
            level(3, 1, 3,
                  "#########",
                  "#Y..B..R#",
                  "#R.r....#",
                  "#########"),
            // 3 · Double Blend
            level(3, 2, 2,
                  "#########",
                  "#R.Y.R.Y#",
                  "###o###o#",
                  "#########"),
            // 4 · Zigzag
            level(3, 3, 3,
                  "########",
                  "#R.....#",
                  "#.####.#",
                  "##.....#",
                  "#.####.#",
                  "#r.....#",
                  "########"),
            // 5 · Two Kitchens
            level(3, 4, 4,
                  "###########",
                  "#R.Y.#Y..B#",
                  "#..o.#...g#",
                  "###########"),
            // 6 · Recycler
            level(3, 5, 3,
                  "##########",
                  "#R.Y.R.Yo#",
                  "#......o##",
                  "##########"),
            // 7 · Pressure Cooker
            level(3, 6, 4,
                  "#######",
                  "#RY.YB#",
                  "#.....#",
                  "#o...g#",
                  "#######"),
            // 8 · Clean Sweep
            level(3, 7, 5,
                  "#########",
                  "#RR.Y..B#",
                  "#r..o..b#",
                  "#########"),
            // 9 · Countercurrent
            level(3, 8, 4,
                  "#########",
                  "#B.R.B.Y#",
                  "#p.....g#",
                  "#########"),
            // 10 · Masterpiece
            level(3, 9, 5,
                  "############",
                  "#B.R.B.YR.Y#",
                  "#..p...g..o#",
                  "############"),
        ]),
    ] + GeneratedLevels.packs

    static let all: [Level] = packs.flatMap(\.levels)

    static var total: Int { all.count }

    private static let indexById: [String: Int] = Dictionary(
        uniqueKeysWithValues: all.enumerated().map { ($1.id, $0) }
    )

    static func byId(_ id: String) -> Level { all[indexById[id]!] }

    static func globalNumber(_ id: String) -> Int { (indexById[id] ?? 0) + 1 }

    static func packOf(_ level: Level) -> Pack { packs[level.pack] }

    static func next(_ level: Level) -> Level? {
        guard let i = indexById[level.id] else { return nil }
        return i + 1 < all.count ? all[i + 1] : nil
    }

    /// Levels unlock strictly in order across all packs: level N+1 opens once
    /// level N is solved. Premium instantly opens every free level plus the first
    /// premium level; the premium levels after it still unlock one by one.
    static func isUnlocked(_ level: Level, stars: [String: Int], premium: Bool) -> Bool {
        if packOf(level).premium && !premium { return false }
        if (stars[level.id] ?? 0) > 0 { return true }
        guard let i = indexById[level.id] else { return false }
        if i == 0 { return true }
        let prev = all[i - 1]
        if premium && !packOf(prev).premium { return true }
        return (stars[prev.id] ?? 0) > 0
    }
}
