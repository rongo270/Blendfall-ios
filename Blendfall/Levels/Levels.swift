//
//  Levels.swift
//  Blendfall
//
//  The hand-authored teaching levels and the level catalog API, ported from the
//  Android app's Levels.kt.
//
//  Classic is 300 levels in six chapters of 50 and uses no special tiles at all — its
//  difficulty comes from layout, from the generator's trap filter, and from the move
//  limit. Every new mechanic lives in its own pack instead.
//
//  Level notation is documented on LevelParser.
//

import Foundation

/// A board before it is given an identity — what the generators emit.
nonisolated struct RawLevel: Sendable {
    let par: Int
    let rows: [String]
}

nonisolated enum GroupKind: Sendable {
    case classic, special
}

/// A chapter of Classic (50 levels) or one of the mechanic packs (80 levels).
nonisolated struct LevelGroup: Identifiable, Sendable {
    let id: String
    let nameKey: Strings.K
    let kind: GroupKind
    let premium: Bool
    let levels: [Level]
    /// "I".."VI" for Classic chapters, nil for packs.
    let numeral: String?
    /// One line explaining a special pack's tile. Nil for Classic.
    let blurbKey: Strings.K?

    init(
        id: String,
        nameKey: Strings.K,
        kind: GroupKind,
        premium: Bool,
        levels: [Level],
        numeral: String? = nil,
        blurbKey: Strings.K? = nil
    ) {
        self.id = id
        self.nameKey = nameKey
        self.kind = kind
        self.premium = premium
        self.levels = levels
        self.numeral = numeral
        self.blurbKey = blurbKey
    }
}

nonisolated enum Levels {

    // -------------------------------------------------------------------------------
    // DEV SWITCH — set to true to open every level at once: play order, the Master star
    // gates and the premium chapters are all ignored.
    //
    // It is ANDed with a #if DEBUG check below, so leaving it switched on can never ship
    // an unlocked game to the App Store — a release build locks up again by itself.
    // -------------------------------------------------------------------------------
    static let unlockAll = true

    static var unlockEverything: Bool {
        #if DEBUG
        return unlockAll
        #else
        return false
        #endif
    }

    static let chapterSize = 50
    /// The last levels of a chapter, gated behind stars earned in the rest of it.
    static let masterCount = 10
    /// Stars needed from a chapter's first 40 levels (of 120) to open its Master 10.
    static let masterStarGate = 90
    /// Below this level number there is no move limit — you are still learning.
    static let moveLimitFrom = 15
    /// Slack over par once the limit applies.
    static let moveLimitSlack = 3

    private static let chapterNumerals = ["I", "II", "III", "IV", "V", "VI"]
    private static let chapterNames: [Strings.K] = [
        .chapter_1_name, .chapter_2_name, .chapter_3_name,
        .chapter_4_name, .chapter_5_name, .chapter_6_name,
    ]

    private static func r(_ par: Int, _ rows: String...) -> RawLevel {
        RawLevel(par: par, rows: rows)
    }

    /// Levels 1-14: the whole tutorial. Each one adds exactly one idea, and by 14 the
    /// player has seen selection, grouped movement, inert blockers, all three blends and
    /// the cost of blending by accident. From 15 the generated curve and the move limit
    /// take over.
    private static let tutorial: [RawLevel] = [
        // 1 · Slide — tap a color, swipe, everything of that color slides.
        r(1, "#####", "#R.r#", "#####"),
        // 2 · Two Turns — a target you cannot reach in a straight line.
        r(2, "#####", "#R..#", "#..r#", "#####"),
        // 3 · Together — one swipe moves every red at once.
        r(1, "#####", "#R.r#", "#R.r#", "#####"),
        // 4 · The Blocker — greens are inert; they stop things, they never blend.
        r(2, "#####", "#RGr#", "#.g.#", "#####"),
        // 5 · Use It — that same blocker is how you stop short of the wall.
        r(1, "######", "#R.rG#", "######"),
        // 6 · First Blend — red into yellow makes orange.
        r(2, "#######", "#R.Y.o#", "#######"),
        // 7 · Purple — red into blue.
        r(2, "#####", "#B..#", "#...#", "#R..#", "#p..#", "#####"),
        // 8 · Green — yellow into blue.
        r(2, "######", "#Y.B.#", "#....#", "#g...#", "######"),
        // 9 · Keep Apart — blending is not always what you want.
        r(2, "######", "#R..Y#", "#r..y#", "######"),
        // 10 · Three Reds — grouped movement onto three targets.
        r(2, "#######", "#R.R.R#", "#rrr..#", "#######"),
        // 11 · Leftovers — spend the right red, keep the other.
        r(2, "#######", "#RRrYo#", "#######"),
        // 12 · Round Trip — the long way is the only way.
        r(3, "######", "#R...#", "###..#", "#r...#", "######"),
        // 13 · Traffic — two colors, two lanes, one order that works.
        r(3, "######", "#P..Y#", "#.##.#", "#py..#", "######"),
        // 14 · Keystone — the last free level; everything at once.
        r(3, "#######", "#R..O.#", "#.##..#", "#..ro.#", "##..###", "#######"),
    ]

    private static let tutorialTips: [Int: Strings.K] = [
        0: .tip_select,
        1: .tip_turns,
        2: .tip_group,
        3: .tip_blocker,
        4: .tip_stopper,
        5: .tip_mix,
        6: .tip_purple,
        7: .tip_green,
        8: .tip_avoid,
        10: .tip_leftover,
    ]

    /// Global level number (1..300) decides whether a Classic level is move-limited.
    private static func limitFor(_ globalNumber: Int, _ par: Int) -> Int? {
        globalNumber >= moveLimitFrom ? par + moveLimitSlack : nil
    }

    private static func classicChapter(_ chapterIndex: Int, _ raws: [RawLevel]) -> LevelGroup {
        let id = "c\(chapterIndex + 1)"
        let levels = raws.enumerated().map { i, raw -> Level in
            let globalNumber = chapterIndex * chapterSize + i + 1
            return Level(
                id: "\(id)l\(i + 1)",
                groupId: id,
                index: i,
                par: raw.par,
                rows: raw.rows,
                tip: chapterIndex == 0 ? tutorialTips[i] : nil,
                moveLimit: limitFor(globalNumber, raw.par)
            )
        }
        return LevelGroup(
            id: id,
            nameKey: chapterNames[chapterIndex],
            kind: .classic,
            premium: chapterIndex >= 3,
            levels: levels,
            numeral: chapterNumerals[chapterIndex]
        )
    }

    private static func specialPack(
        _ id: String,
        _ nameKey: Strings.K,
        _ blurbKey: Strings.K,
        _ raws: [RawLevel],
        tips: [Int: Strings.K] = [:]
    ) -> LevelGroup {
        LevelGroup(
            id: id,
            nameKey: nameKey,
            kind: .special,
            premium: false,
            levels: raws.enumerated().map { i, raw in
                Level(
                    id: "\(id)l\(i + 1)",
                    groupId: id,
                    index: i,
                    par: raw.par,
                    rows: raw.rows,
                    tip: tips[i]
                )
            },
            blurbKey: blurbKey
        )
    }

    /// Portals levels 1-5, hand-authored as a tutorial. Each is solvable in a move or
    /// three and each is *unsolvable or slower* without the rings, so the portal is never
    /// decoration the player can ignore — the only way to finish is to use it.
    ///
    /// They live here rather than in the generated file so regenerating the pack cannot
    /// quietly replace the teaching levels with random boards.
    private static let portalTutorial: [RawLevel] = [
        // 1 · In one, out the other. Swipe right; the ring moves it down a row and it
        //     carries on to the target. Straight right would miss by a whole row.
        r(1, "######", "#R.(.#", "#.).r#", "######"),
        // 2 · Rings work vertically too.
        r(1, "#####", "#R..#", "#(..#", "#..)#", "#..r#", "#####"),
        // 3 · The only route — with the rings taken out this board cannot be solved.
        r(1, "######", "#..r.#", "#(...#", "#..).#", "#R...#", "######"),
        // 4 · It keeps sliding after it lands, so one trip is not the whole answer.
        r(2, "#######", "#R..(.#", "#.....#", "#)..#.#", "#..r..#", "#######"),
        // 5 · Both colors can travel, and they still blend when they meet.
        r(3, "######", "#R.B(#", "#....#", "#)..r#", "#...b#", "######"),
    ]

    private static let portalTips: [Int: Strings.K] = [
        0: .tip_portal_intro,
        1: .tip_portal_vertical,
        2: .tip_portal_only,
        3: .tip_portal_keeps,
        4: .tip_portal_blend,
    ]

    static let chapters: [LevelGroup] = {
        var out: [LevelGroup] = []
        // Chapter I is the 14 hand-authored tutorial levels plus 36 generated ones.
        out.append(classicChapter(0, tutorial + GeneratedClassic.chapters[0]))
        out.append(classicChapter(1, GeneratedClassic.chapters[1]))
        out.append(classicChapter(2, GeneratedClassic.chapters[2]))
        // Chapters IV-VI are the kept boards, re-sorted by par across all 150 and split
        // into three so the back half climbs 4 -> 9 without stalling inside a chapter.
        // Ties keep their original order, matching Kotlin's stable sortedBy.
        let flat = LegacyClassic.chapters.flatMap { $0 }
        let sorted = flat.enumerated()
            .sorted { $0.element.par == $1.element.par ? $0.offset < $1.offset : $0.element.par < $1.element.par }
            .map(\.element)
        for (i, start) in stride(from: 0, to: sorted.count, by: chapterSize).enumerated() {
            out.append(classicChapter(3 + i, Array(sorted[start..<min(start + chapterSize, sorted.count)])))
        }
        return out
    }()

    /// The mechanic packs — both free, both outside Classic, 80 levels each.
    static let specialPacks: [LevelGroup] = [
        specialPack(
            "starhunt", .pack_starhunt_name, .pack_starhunt_blurb,
            BigPackLevels.starHunt
        ),
        specialPack(
            "portals", .pack_portals_name, .pack_portals_blurb,
            // The five teaching levels replace the pack's first five generated boards,
            // so the pack is still 80 long and still opens at par 4 once they are done.
            portalTutorial + BigPackLevels.portals.dropFirst(portalTutorial.count),
            tips: portalTips
        ),
    ]

    static let groups: [LevelGroup] = chapters + specialPacks

    /// The 300 Classic levels in play order.
    static let classic: [Level] = chapters.flatMap(\.levels)

    /// Every level in the app, Classic first.
    static let all: [Level] = groups.flatMap(\.levels)

    static var total: Int { classic.count }

    private static let byIdMap: [String: Level] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    private static let groupByIdMap: [String: LevelGroup] =
        Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })

    static func byId(_ id: String) -> Level { byIdMap[id]! }

    static func groupOf(_ level: Level) -> LevelGroup { groupByIdMap[level.groupId]! }

    static func chapterIndexOf(_ level: Level) -> Int {
        chapters.firstIndex { $0.id == level.groupId } ?? -1
    }

    /// 1..300 inside Classic, or 1..n inside a pack.
    static func displayNumber(_ level: Level) -> Int {
        let chapter = chapterIndexOf(level)
        return chapter >= 0 ? chapter * chapterSize + level.index + 1 : level.index + 1
    }

    static func displayNumber(id: String) -> Int { displayNumber(byId(id)) }

    /// True for the gated Master levels at the end of a chapter.
    static func isMaster(_ level: Level) -> Bool {
        groupOf(level).kind == .classic && level.index >= chapterSize - masterCount
    }

    static func next(_ level: Level) -> Level? {
        let siblings = groupOf(level).levels
        if level.index + 1 < siblings.count { return siblings[level.index + 1] }
        let chapter = chapterIndexOf(level)
        if chapter < 0 { return nil }
        return chapter + 1 < chapters.count ? chapters[chapter + 1].levels.first : nil
    }

    /// What the win screen's Next button should open. The Master 10 are optional bonus
    /// content, so while their star gate is shut this steps over them to the next chapter
    /// rather than handing the player a locked level.
    static func nextPlayable(_ level: Level, stars: [String: Int]) -> Level? {
        var cur = next(level)
        var guardCount = 0
        while let c = cur, guardCount <= chapterSize {
            guardCount += 1
            if !isMaster(c) || masterUnlocked(groupOf(c), stars) { return c }
            cur = next(c)
        }
        return cur
    }

    /// Stars earned across a chapter's first 40 levels — what the Master gate measures.
    static func mainLineStars(_ group: LevelGroup, _ stars: [String: Int]) -> Int {
        group.levels.prefix(chapterSize - masterCount).reduce(0) { $0 + (stars[$1.id] ?? 0) }
    }

    static func masterUnlocked(_ group: LevelGroup, _ stars: [String: Int]) -> Bool {
        unlockEverything || mainLineStars(group, stars) >= masterStarGate
    }

    /// True when this group is still behind the premium purchase.
    static func isPaywalled(_ group: LevelGroup, premium: Bool) -> Bool {
        group.premium && !premium && !unlockEverything
    }

    static func groupStars(_ group: LevelGroup, _ stars: [String: Int]) -> Int {
        group.levels.reduce(0) { $0 + (stars[$1.id] ?? 0) }
    }

    /// Stars sitting on this level's board. Star Hunt only — every other group has none.
    static func pickupsIn(_ level: Level) -> Int {
        level.rows.reduce(0) { $0 + $1.count { $0 == "*" } }
    }

    /// Every star in the game, i.e. the denominator of the player's star total.
    static let totalPickups: Int = all.reduce(0) { $0 + pickupsIn($1) }

    static func groupPickups(_ group: LevelGroup) -> Int {
        group.levels.reduce(0) { $0 + pickupsIn($1) }
    }

    static func groupSolved(_ group: LevelGroup, _ stars: [String: Int]) -> Int {
        group.levels.count { (stars[$0.id] ?? 0) > 0 }
    }

    /// A chapter opens once the previous chapter's main line (its first 40) is finished.
    /// The Master 10 are optional bonus content, so they never block progress.
    static func chapterUnlocked(_ index: Int, stars: [String: Int], premium: Bool) -> Bool {
        guard index >= 0, index < chapters.count else { return false }
        let group = chapters[index]
        if unlockEverything { return true }
        if group.premium && !premium { return false }
        if index == 0 { return true }
        let prev = chapters[index - 1]
        return prev.levels.prefix(chapterSize - masterCount).allSatisfy { (stars[$0.id] ?? 0) > 0 }
    }

    /// Levels open one at a time inside their group. In Classic the Master 10 additionally
    /// wait on `masterStarGate` stars from the same chapter's main line.
    static func isUnlocked(_ level: Level, stars: [String: Int], premium: Bool) -> Bool {
        if unlockEverything { return true }
        let group = groupOf(level)
        if group.premium && !premium { return false }
        if (stars[level.id] ?? 0) > 0 { return true }

        if group.kind == .classic {
            let chapter = chapterIndexOf(level)
            if !chapterUnlocked(chapter, stars: stars, premium: premium) { return false }
            if isMaster(level) && !masterUnlocked(group, stars) { return false }
        }

        guard level.index - 1 >= 0 else { return true }
        // The first Master level follows the gate, not level 40's completion.
        if isMaster(level) && level.index == chapterSize - masterCount { return true }
        let prev = group.levels[level.index - 1]
        return (stars[prev.id] ?? 0) > 0
    }
}
