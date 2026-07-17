//
//  HomeScreen.swift
//  Blendfall
//
//  The title screen: bouncing logo blocks over a soft gradient with a warm
//  glow, drifting background blocks, progress card, and chunky glossy
//  Play / Blitz / Levels / Premium / Settings buttons.
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

            // Warm spotlight behind the title so the menu has a stage.
            RadialGradient(
                colors: [palette.accent.opacity(palette.isDark ? 0.22 : 0.14), .clear],
                center: UnitPoint(x: 0.5, y: 0.30),
                startRadius: 10,
                endRadius: 360
            )
            .ignoresSafeArea()

            FloatingBlocks(palette: palette, shape: progress.shape)

            VStack(spacing: 0) {
                Spacer()

                BouncingBlocks(palette: palette, shape: progress.shape)
                    .padding(.bottom, 22)

                // The title itself is a blend — red into yellow into blue.
                Text(s[.app_name])
                    .font(.system(size: 50, weight: .black, design: .rounded))
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
                    .shadow(color: .black.opacity(palette.isDark ? 0.45 : 0.16), radius: 10, y: 5)
                Text(s[.home_tagline])
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.textSecondary)
                    .padding(.top, 2)

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
                            .font(.system(size: 19, weight: .bold))
                        Text(
                            solved > 0
                                ? s.f(.home_continue, Levels.globalNumber(continueId))
                                : s[.home_play]
                        )
                        .font(.system(size: 19, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .chunky(fill: palette.accent, corner: 20, lip: 4)
                    .shadow(color: palette.accent.opacity(0.45), radius: 14, y: 8)
                }
                .buttonStyle(PressableButtonStyle())
                .scaleEffect(playPulse ? 1.025 : 1)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                        playPulse = true
                    }
                }

                Spacer().frame(height: 14)

                HStack(spacing: 12) {
                    Button(action: onBlitz) {
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                                .font(.system(size: 16, weight: .bold))
                            Text(s[.home_blitz])
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(palette.isDark ? palette.star : palette.star.darken(0.25))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .chunky(fill: palette.star.opacity(palette.isDark ? 0.24 : 0.30), corner: 16, lip: 3)
                    }
                    .buttonStyle(PressableButtonStyle())

                    Button(action: onLevels) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.grid.3x3.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text(s[.packs_title])
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(palette.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .chunky(fill: palette.surface, corner: 16, lip: 3)
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                Spacer().frame(height: 14)

                HStack(spacing: 12) {
                    OutlineButton(palette: palette) {
                        onPremium()
                    } label: {
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(palette.star)
                        Text(s[.home_premium])
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(progress.premium ? palette.star : palette.textPrimary)
                    }

                    OutlineButton(palette: palette) {
                        onSettings()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(palette.textSecondary)
                        Text(s[.home_settings])
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
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

// MARK: - Chunky game-button surface

private extension View {
    /// The candy-button look: extruded darker lip below, vertical sheen on the
    /// face and a soft gloss cap — the same language as the app icon blocks.
    func chunky(fill: Color, corner: CGFloat, lip: CGFloat) -> some View {
        background(
            ZStack {
                RoundedRectangle(cornerRadius: corner)
                    .fill(fill.darken(0.32))
                    .offset(y: lip)
                RoundedRectangle(cornerRadius: corner)
                    .fill(
                        LinearGradient(
                            colors: [fill.lighten(0.16), fill, fill.darken(0.06)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                RoundedRectangle(cornerRadius: corner)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.30), location: 0),
                                .init(color: .white.opacity(0.06), location: 0.42),
                                .init(color: .clear, location: 0.55),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        )
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
                .background(palette.surface.opacity(palette.isDark ? 0.45 : 0.6), in: RoundedRectangle(cornerRadius: 16))
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
        VStack(spacing: 9) {
            HStack {
                Text(s.f(.home_progress, solved, total))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.star)
                    Text(s.f(.home_stars, stars))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(palette.star.opacity(0.14), in: Capsule())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(palette.textSecondary.opacity(0.15))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [palette.accent, palette.accent.lighten(0.25)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * min(1, Double(solved) / Double(total))))
                        .shadow(color: palette.accent.opacity(0.5), radius: 4)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(palette.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(palette.textSecondary.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct BouncingBlocks: View {
    let palette: BlendPalette
    let shape: BlockShape

    @State private var bounce = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 14) {
            ForEach(Array([GameColor.red, .yellow, .blue].enumerated()), id: \.offset) { i, color in
                BlockView(color: color, palette: palette, shape: shape)
                    .frame(width: 48, height: 48)
                    .shadow(color: .black.opacity(palette.isDark ? 0.5 : 0.22), radius: 5, y: 6)
                    .rotationEffect(.degrees(bounce ? (i.isMultiple(of: 2) ? 5 : -5) : 0))
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
