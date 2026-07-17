//
//  PacksScreen.swift
//  Blendfall
//
//  Level select: one card per pack with a 5-wide grid of level chips showing
//  number, stars and lock state.
//

import SwiftUI

struct PacksScreen: View {
    let progress: ProgressStore
    let onBack: () -> Void
    let onLevel: (String) -> Void
    let onPremium: () -> Void

    var body: some View {
        let palette = progress.palette
        let s = progress.strings

        VStack(spacing: 0) {
            HStack(spacing: 10) {
                BackButton(palette: palette, action: onBack)
                Text(s[.packs_title])
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(Levels.packs) { pack in
                        PackSection(
                            pack: pack,
                            progress: progress,
                            onLevel: onLevel,
                            onPremium: onPremium
                        )
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .phoneContentWidth()
    }
}

private struct PackSection: View {
    let pack: Pack
    let progress: ProgressStore
    let onLevel: (String) -> Void
    let onPremium: () -> Void

    var body: some View {
        let palette = progress.palette
        let s = progress.strings
        let locked = pack.premium && !progress.premium
        let solved = pack.levels.count { progress.starsFor($0.id) > 0 }

        VStack(spacing: 10) {
            HStack {
                Text(s[pack.nameKey])
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.star)
                    Text(s[.pack_locked])
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(palette.star)
                } else {
                    Text(s.f(.pack_progress, solved, pack.levels.count))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                }
            }

            let rows = stride(from: 0, to: pack.levels.count, by: 5).map {
                Array(pack.levels[$0..<min($0 + 5, pack.levels.count)])
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, rowLevels in
                HStack(spacing: 8) {
                    ForEach(rowLevels) { level in
                        LevelChip(
                            level: level,
                            progress: progress,
                            packLocked: locked,
                            onLevel: onLevel,
                            onPremium: onPremium
                        )
                    }
                    // Pad short rows so chips keep their width.
                    ForEach(0..<(5 - rowLevels.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                    }
                }
            }
        }
        .padding(14)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 16)
    }
}

private struct LevelChip: View {
    let level: Level
    let progress: ProgressStore
    let packLocked: Bool
    let onLevel: (String) -> Void
    let onPremium: () -> Void

    var body: some View {
        let palette = progress.palette
        let earned = progress.starsFor(level.id)
        let playable = !packLocked && Levels.isUnlocked(level, stars: progress.stars, premium: progress.premium)

        Button {
            if packLocked {
                onPremium()
            } else if playable {
                onLevel(level.id)
            }
        } label: {
            VStack(spacing: 2) {
                if playable {
                    Text("\(Levels.globalNumber(level.id))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(palette.textSecondary)
                        .frame(height: 20)
                }
                StarsRow(earned: earned, size: 7, palette: palette, spacing: 1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                earned > 0 ? palette.accent.opacity(0.18) : palette.cell,
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .opacity(playable ? 1 : 0.45)
    }
}
