//
//  OnboardingOverlay.swift
//  Blendfall
//
//  First-launch intro: how to play, blending, and the Levels/Blitz/hints
//  structure — a three-page pager over the theme background.
//

import SwiftUI

struct OnboardingOverlay: View {
    let progress: ProgressStore
    let onDone: () -> Void

    @State private var page = 0

    var body: some View {
        let palette = progress.palette
        let s = progress.strings
        let lastPage = page == 2

        ZStack {
            palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(s[.onboarding_skip], action: onDone)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                        .padding(.trailing, 4)
                }
                .padding(.top, 8)

                TabView(selection: $page) {
                    OnboardingPage(
                        art: { SwipeArt(palette: palette, shape: progress.shape) },
                        title: s[.onboarding_1_title],
                        body: s[.onboarding_1_body],
                        palette: palette
                    )
                    .tag(0)
                    OnboardingPage(
                        art: { BlendArt(palette: palette, shape: progress.shape) },
                        title: s[.onboarding_2_title],
                        body: s[.onboarding_2_body],
                        palette: palette
                    )
                    .tag(1)
                    OnboardingPage(
                        art: { ModesArt(palette: palette) },
                        title: s[.onboarding_3_title],
                        body: s[.onboarding_3_body],
                        palette: palette
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i == page ? palette.accent : palette.textSecondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.vertical, 14)

                Button {
                    if lastPage {
                        onDone()
                    } else {
                        withAnimation { page += 1 }
                    }
                } label: {
                    Text(lastPage ? s[.onboarding_done] : s[.onboarding_next])
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(palette.accent, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.bottom, 14)
            }
            .padding(.horizontal, 24)
            .phoneContentWidth()
        }
    }
}

private struct OnboardingPage<Art: View>: View {
    @ViewBuilder let art: Art
    let title: String
    let body_: String
    let palette: BlendPalette

    init(@ViewBuilder art: () -> Art, title: String, body: String, palette: BlendPalette) {
        self.art = art()
        self.title = title
        self.body_ = body
        self.palette = palette
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            art
            Spacer().frame(height: 28)
            Text(title)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
            Text(body_)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
            Spacer()
        }
    }
}

private struct GameBlockArt: View {
    let color: GameColor
    let palette: BlendPalette
    let shape: BlockShape
    var size: Double = 44

    var body: some View {
        BlockView(color: color, palette: palette, shape: shape)
            .frame(width: size, height: size)
    }
}

private struct SwipeArt: View {
    let palette: BlendPalette
    let shape: BlockShape

    var body: some View {
        HStack(spacing: 14) {
            GameBlockArt(color: .red, palette: palette, shape: shape)
            Image(systemName: "arrow.right")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(palette.textSecondary)
            GameBlockArt(color: .red, palette: palette, shape: shape)
        }
    }
}

private struct BlendArt: View {
    let palette: BlendPalette
    let shape: BlockShape

    var body: some View {
        HStack(spacing: 0) {
            GameBlockArt(color: .red, palette: palette, shape: shape)
            Text("  +  ")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(palette.textSecondary)
            GameBlockArt(color: .yellow, palette: palette, shape: shape)
            Text("  =  ")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(palette.textSecondary)
            GameBlockArt(color: .orange, palette: palette, shape: shape, size: 52)
        }
    }
}

private struct ModesArt: View {
    let palette: BlendPalette

    var body: some View {
        HStack(spacing: 24) {
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 34))
                .foregroundStyle(palette.accent)
            Image(systemName: "timer")
                .font(.system(size: 36))
                .foregroundStyle(palette.accent)
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 34))
                .foregroundStyle(palette.star)
        }
    }
}
