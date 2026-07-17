//
//  HomeScreen.swift
//  Blendfall
//
//  The title screen: bouncing logo blocks over a soft gradient, drifting
//  background blocks, progress card, and the Play / Blitz / Levels /
//  Premium / Settings buttons.
//

import SwiftUI

struct HomeScreen: View {
    let progress: ProgressStore
    let onPlay: (String) -> Void
    let onLevels: () -> Void
    let onBlitz: () -> Void
    let onPremium: () -> Void
    let onSettings: () -> Void

    @State private var playPulse = false

    var body: some View {
        let palette = progress.palette
        let s = progress.strings

        ZStack {
            LinearGradient(
                colors: [palette.background, palette.boardBackground, palette.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            FloatingBlocks(palette: palette, shape: progress.shape)

            VStack(spacing: 0) {
                Spacer()

                BouncingBlocks(palette: palette, shape: progress.shape)
                    .padding(.bottom, 18)

                // The title itself is a blend — red into yellow into blue.
                Text(s[.app_name])
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                palette.block(.red),
                                palette.block(.yellow),
                                palette.block(.blue),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text(s[.home_tagline])
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(palette.textSecondary)

                Spacer().frame(height: 26)

                let solved = progress.stars.values.count { $0 > 0 }
                let totalStars = progress.stars.values.reduce(0, +)
                if solved > 0 {
                    ProgressCard(solved: solved, total: Levels.total, stars: totalStars, palette: palette, s: s)
                        .padding(.bottom, 18)
                } else {
                    Spacer().frame(height: 8)
                }

                let continueId = progress.continueLevelId()
                Button {
                    onPlay(continueId)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text(
                            solved > 0
                                ? s.f(.home_continue, Levels.globalNumber(continueId))
                                : s[.home_play]
                        )
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        LinearGradient(
                            colors: [palette.accent, palette.accent.lighten(0.22)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 18)
                    )
                }
                .buttonStyle(PressableButtonStyle())
                .scaleEffect(playPulse ? 1.025 : 1)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                        playPulse = true
                    }
                }

                Spacer().frame(height: 12)

                HStack(spacing: 12) {
                    Button(action: onBlitz) {
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                                .font(.system(size: 16, weight: .bold))
                            Text(s[.home_blitz])
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(palette.star)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(palette.star.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(PressableButtonStyle())

                    Button(action: onLevels) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.grid.3x3.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text(s[.packs_title])
                                .font(.system(size: 16, design: .rounded))
                        }
                        .foregroundStyle(palette.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                Spacer().frame(height: 12)

                HStack(spacing: 12) {
                    OutlineButton(palette: palette) {
                        onPremium()
                    } label: {
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(palette.star)
                        Text(s[.home_premium])
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(progress.premium ? palette.star : palette.textPrimary)
                    }

                    OutlineButton(palette: palette) {
                        onSettings()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(palette.textSecondary)
                        Text(s[.home_settings])
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(palette.textPrimary)
                    }
                }

                Spacer().frame(height: 26)

                Text(s[.home_no_ads])
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(palette.textSecondary.opacity(0.7))

                Spacer()
            }
            .padding(.horizontal, 28)
            .phoneContentWidth()
        }
    }
}

private struct OutlineButton<Label: View>: View {
    let palette: BlendPalette
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) { label }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(palette.textSecondary.opacity(0.35), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// Faint game blocks drifting behind the menu, so the home screen feels like the game.
private struct FloatingBlocks: View {
    let palette: BlendPalette
    let shape: BlockShape

    private struct Drifter {
        let color: GameColor
        let align: Alignment
        let xOff: Double
        let yOff: Double
        let size: Double
        let period: Double
        let drift: Double
    }

    private static let drifters: [Drifter] = [
        Drifter(color: .red, align: .topLeading, xOff: 24, yOff: 90, size: 34, period: 3.6, drift: 18),
        Drifter(color: .blue, align: .topTrailing, xOff: -30, yOff: 150, size: 26, period: 4.2, drift: -22),
        Drifter(color: .yellow, align: .leading, xOff: 16, yOff: -70, size: 22, period: 3.9, drift: 14),
        Drifter(color: .green, align: .trailing, xOff: -22, yOff: 50, size: 30, period: 4.6, drift: -16),
        Drifter(color: .purple, align: .bottomLeading, xOff: 40, yOff: -130, size: 24, period: 4.1, drift: 20),
        Drifter(color: .orange, align: .bottomTrailing, xOff: -36, yOff: -170, size: 32, period: 3.7, drift: -14),
    ]

    @State private var t = false

    var body: some View {
        ZStack {
            ForEach(Array(Self.drifters.enumerated()), id: \.offset) { i, d in
                BlockView(color: d.color, palette: palette, shape: shape)
                    .frame(width: d.size, height: d.size)
                    .opacity(0.12)
                    .rotationEffect(.degrees(t ? 6 : -6))
                    .offset(x: d.xOff, y: d.yOff + (t ? d.drift : 0))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: d.align)
                    .animation(
                        .easeInOut(duration: d.period).repeatForever(autoreverses: true).delay(Double(i) * 0.26),
                        value: t
                    )
            }
        }
        .onAppear { t = true }
        .allowsHitTesting(false)
    }
}

private struct ProgressCard: View {
    let solved: Int
    let total: Int
    let stars: Int
    let palette: BlendPalette
    let s: Strings

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(s.f(.home_progress, solved, total))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.star)
                Text(s.f(.home_stars, stars))
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(palette.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(palette.textSecondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(palette.accent)
                        .frame(width: geo.size.width * min(1, Double(solved) / Double(total)))
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(palette.surface.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct BouncingBlocks: View {
    let palette: BlendPalette
    let shape: BlockShape

    @State private var bounce = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(Array([GameColor.red, .yellow, .blue].enumerated()), id: \.offset) { i, color in
                BlockView(color: color, palette: palette, shape: shape)
                    .frame(width: 44, height: 44)
                    .offset(y: bounce ? -14 : 0)
                    .animation(
                        .easeInOut(duration: 0.52).repeatForever(autoreverses: true).delay(Double(i) * 0.14),
                        value: bounce
                    )
            }
        }
        .onAppear { bounce = true }
    }
}
