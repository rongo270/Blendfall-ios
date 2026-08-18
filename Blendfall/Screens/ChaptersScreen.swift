//
//  ChaptersScreen.swift
//  Blendfall
//
//  The single way into levels: the six Classic chapters, then the mechanic packs under
//  their own header. Tapping one opens LevelGridScreen — a chapter's 40-level main line
//  with its gated Master 10 below, or a pack's levels in one run.
//

import SwiftUI

struct ChaptersScreen: View {
    let progress: ProgressStore
    let onBack: () -> Void
    let onGroup: (String) -> Void
    let onPremium: () -> Void

    var body: some View {
        let palette = progress.palette
        let s = progress.strings

        SelectScaffold(title: s[.levels_title], palette: palette, backLabel: s[.back], onBack: onBack) {
            LazyVStack(spacing: 10) {
                ForEach(Array(Levels.chapters.enumerated()), id: \.element.id) { index, chapter in
                    let unlocked = Levels.chapterUnlocked(
                        index, stars: progress.stars, premium: progress.premium
                    )
                    let paywalled = Levels.isPaywalled(chapter, premium: progress.premium)
                    ChapterCard(
                        chapter: chapter,
                        unlocked: unlocked,
                        needsPremium: paywalled,
                        progress: progress
                    ) {
                        if paywalled {
                            onPremium()
                        } else if unlocked {
                            onGroup(chapter.id)
                        }
                    }
                }

                // The star total lives here because stars only come from packs.
                SectionHeader(title: s[.packs_header], palette: palette) {
                    PickupStarIcon(size: 15, color: palette.star)
                    Text(fraction(progress.pickupsCollected, Levels.totalPickups))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                }

                ForEach(Levels.specialPacks) { pack in
                    PackCard(pack: pack, progress: progress) { onGroup(pack.id) }
                }
            }
            .padding(.bottom, 24)
        }
    }
}

/// One group's levels. A chapter shows its 40-level main line, then its gated Master 10
/// under their own header; a pack shows all of its levels in one run.
struct LevelGridScreen: View {
    let groupId: String
    let progress: ProgressStore
    let onBack: () -> Void
    let onLevel: (String) -> Void

    var body: some View {
        let palette = progress.palette
        let s = progress.strings
        let group = Levels.groups.first { $0.id == groupId }!
        let isChapter = group.kind == .classic

        let mainLine = isChapter
            ? Array(group.levels.prefix(Levels.chapterSize - Levels.masterCount))
            : group.levels
        let master = isChapter
            ? Array(group.levels.dropFirst(Levels.chapterSize - Levels.masterCount))
            : []
        let masterOpen = isChapter && Levels.masterUnlocked(group, progress.stars)

        let title = group.numeral.map { s.f(.chapter_label, $0) + " · " + s[group.nameKey] }
            ?? s[group.nameKey]

        SelectScaffold(title: title, palette: palette, backLabel: s[.back], onBack: onBack) {
            LazyVStack(spacing: 8) {
                if let blurb = group.blurbKey {
                    Text(s[blurb])
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 2)
                }

                // Rows go straight into the lazy stack rather than through a wrapper view,
                // so each is its own item and the stack materializes them independently.
                ForEach(LevelRow.chunk(mainLine)) { row in
                    LevelRow(row: row, progress: progress, onLevel: onLevel)
                }

                if isChapter {
                    SectionHeader(title: s[.master_section], palette: palette) {
                        if !masterOpen {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(palette.star)
                            Text(s.f(
                                .master_locked,
                                Levels.mainLineStars(group, progress.stars),
                                Levels.masterStarGate
                            ))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(palette.star)
                        }
                    }
                    ForEach(LevelRow.chunk(master)) { row in
                        LevelRow(row: row, progress: progress, onLevel: onLevel)
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Pieces

private struct SelectScaffold<Content: View>: View {
    let title: String
    let palette: BlendPalette
    let backLabel: String
    let onBack: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                BackButton(palette: palette, label: backLabel, action: onBack)
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            ScrollView { content }
        }
        .phoneContentWidth()
    }
}

private struct ChapterCard: View {
    let chapter: LevelGroup
    let unlocked: Bool
    let needsPremium: Bool
    let progress: ProgressStore
    let onTap: () -> Void

    var body: some View {
        let palette = progress.palette
        let s = progress.strings
        let solved = Levels.groupSolved(chapter, progress.stars)
        let earned = Levels.groupStars(chapter, progress.stars)
        let maxStars = chapter.levels.count * 3

        Button(action: onTap) {
            HStack(spacing: 12) {
                // Roman numeral badge
                Text(chapter.numeral ?? "")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(palette.accent)
                    .frame(width: 44, height: 44)
                    .background(palette.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 6) {
                    Text(s[chapter.nameKey])
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)

                    if needsPremium {
                        Text(s[.pack_locked])
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(palette.star)
                    } else if !unlocked {
                        Text(s[.chapter_locked])
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(palette.textSecondary)
                    } else {
                        ProgressBar(
                            fraction: Double(solved) / Double(chapter.levels.count),
                            palette: palette
                        )
                        HStack(spacing: 4) {
                            Text(s.f(.chapter_progress, solved, chapter.levels.count))
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(palette.textSecondary)
                            Spacer().frame(width: 6)
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(palette.star)
                            Text(fraction(earned, maxStars))
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(palette.textSecondary)
                            Spacer()
                        }
                    }
                }

                if needsPremium || !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(needsPremium ? palette.star : palette.textSecondary)
                        .accessibilityLabel(s[.locked])
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(PressableButtonStyle())
        .opacity(unlocked || needsPremium ? 1 : 0.5)
        .padding(.horizontal, 16)
    }
}

/// A pack card leads with the pack's own tile, so the list is scannable by shape as well
/// as by name, and carries the same badge + progress structure as a chapter card so the
/// two sections read as one screen rather than two bolted together.
private struct PackCard: View {
    let pack: LevelGroup
    let progress: ProgressStore
    let onTap: () -> Void

    var body: some View {
        let palette = progress.palette
        let s = progress.strings
        let solved = Levels.groupSolved(pack, progress.stars)
        let starsHere = Levels.groupPickups(pack)
        let starsFound = pack.levels.reduce(0) { $0 + progress.pickupsFor($1.id) }

        Button(action: onTap) {
            HStack(spacing: 12) {
                PackBadge(packId: pack.id, palette: palette, size: 30)
                    .frame(width: 44, height: 44)
                    .background(palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(s[pack.nameKey])
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.textPrimary)
                        Spacer()
                        // The 80-level packs earn a badge.
                        if pack.levels.count >= 80 {
                            Text(s[.pack_campaign])
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(palette.accent)
                        }
                    }
                    if let blurb = pack.blurbKey {
                        Text(s[blurb])
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(palette.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer().frame(height: 5)
                    ProgressBar(
                        fraction: Double(solved) / Double(pack.levels.count),
                        palette: palette
                    )
                    HStack(spacing: 4) {
                        Text(s.f(.pack_progress, solved, pack.levels.count))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(palette.textSecondary)
                        if starsHere > 0 {
                            Spacer().frame(width: 6)
                            PickupStarIcon(size: 12, color: palette.star)
                            Text(fraction(starsFound, starsHere))
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(palette.textSecondary)
                        }
                        Spacer()
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.horizontal, 16)
    }
}

/// A section divider inside a level list, with optional trailing content on the right.
private struct SectionHeader<Trailing: View>: View {
    let title: String
    let palette: BlendPalette
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(palette.textPrimary)
            Rectangle()
                .fill(palette.textSecondary.opacity(0.18))
                .frame(height: 1)
            trailing
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 2)
    }
}

private struct ProgressBar: View {
    let fraction: Double
    let palette: BlendPalette

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.cell)
                Capsule()
                    .fill(palette.accent)
                    .frame(width: geo.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 6)
    }
}

/// One row of five level chips. Identified by its first level, which is unique across the
/// whole catalog, so two runs of rows in the same list can never collide.
private struct LevelRow: View, Identifiable {
    let row: Chunk
    let progress: ProgressStore
    let onLevel: (String) -> Void

    var id: String { row.id }

    struct Chunk: Identifiable {
        let id: String
        let levels: [Level]
    }

    static func chunk(_ levels: [Level]) -> [Chunk] {
        stride(from: 0, to: levels.count, by: 5).map { start in
            let slice = Array(levels[start..<min(start + 5, levels.count)])
            return Chunk(id: slice[0].id, levels: slice)
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(row.levels) { level in
                LevelChip(level: level, progress: progress, onLevel: onLevel)
            }
            // Keeps a short final row aligned with the full ones above it.
            if row.levels.count < 5 {
                ForEach(0..<(5 - row.levels.count), id: \.self) { _ in
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

private struct LevelChip: View {
    let level: Level
    let progress: ProgressStore
    let onLevel: (String) -> Void

    var body: some View {
        let palette = progress.palette
        let earned = progress.starsFor(level.id)
        let playable = Levels.isUnlocked(level, stars: progress.stars, premium: progress.premium)
        let starsHere = Levels.pickupsIn(level)
        let starsFound = progress.pickupsFor(level.id)
        let s = progress.strings
        let number = Levels.displayNumber(level)
        // One merged label per chip: the pips inside are decorative, so without this a
        // screen reader read out a bare number and never mentioned stars or the lock.
        let label = if !playable {
            s.f(.a11y_level_locked, number)
        } else if earned > 0 {
            s.f(.a11y_level_stars, number, earned)
        } else {
            s.f(.a11y_level_unsolved, number)
        }

        Button {
            if playable { onLevel(level.id) }
        } label: {
            VStack(spacing: 2) {
                if playable {
                    Text("\(number)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(palette.textSecondary)
                        .frame(height: 20)
                }
                StarsRow(earned: earned, size: 7, palette: palette, spacing: 1)
                // Star Hunt only: which of this board's stars you have actually swept up.
                // Dim pips are the reason to come back to a level you already solved.
                if starsHere > 0 && playable {
                    HStack(spacing: 2) {
                        ForEach(0..<starsHere, id: \.self) { i in
                            PickupStarIcon(
                                size: 9,
                                color: i < starsFound ? palette.star : palette.textSecondary.opacity(0.3)
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.vertical, 8)
            .background(
                earned > 0 ? palette.accent.opacity(0.18) : palette.cell,
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!playable)
        .opacity(playable ? 1 : 0.45)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }
}
