//
//  BlitzScreen.swift
//  Blendfall
//
//  Blitz mode: duration setup with bests, the timed run reusing the shared
//  board, and the time-up result card.
//

import SwiftUI

struct BlitzScreen: View {
    let progress: ProgressStore
    let onBack: () -> Void

    @State private var vm = BlitzModel()

    var body: some View {
        ZStack {
            switch vm.phase {
            case .setup:
                BlitzSetup(vm: vm, progress: progress, onBack: onBack)
            case .playing, .finished:
                BlitzPlay(vm: vm, progress: progress, onExit: onBack)
            }
        }
        .onChange(of: vm.phase) { _, phase in
            // Persist the final score exactly once per finished run.
            if phase == .finished {
                progress.recordBlitzScore(durationSec: vm.durationSec, score: vm.score)
            }
        }
    }
}

// MARK: - Setup

private struct BlitzSetup: View {
    let vm: BlitzModel
    let progress: ProgressStore
    let onBack: () -> Void

    var body: some View {
        let palette = progress.palette
        let s = progress.strings

        VStack(spacing: 0) {
            HStack {
                BackButton(palette: palette, label: s[.back], action: onBack)
                Spacer()
            }
            .padding(.horizontal, 12)

            Spacer()

            Image(systemName: "timer")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(palette.accent)
            Text(s[.blitz_title])
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(palette.textPrimary)
                .padding(.top, 12)
            Text(s[.blitz_tagline])
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 32)

            HStack(spacing: 10) {
                ForEach(blitzDurations, id: \.self) { sec in
                    DurationCard(
                        seconds: sec,
                        best: progress.blitzBests[sec] ?? 0,
                        selected: vm.durationSec == sec,
                        palette: palette,
                        s: s
                    ) {
                        vm.selectDuration(sec)
                    }
                }
            }

            Spacer().frame(height: 32)

            Button {
                vm.start(currentBest: progress.blitzBests[vm.durationSec] ?? 0, premium: progress.premium)
            } label: {
                Text(s[.blitz_start])
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 56)
                    .background(palette.accent, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(PressableButtonStyle())

            Spacer()
        }
        .padding(.horizontal, 28)
        .phoneContentWidth()
    }
}

private struct DurationCard: View {
    let seconds: Int
    let best: Int
    let selected: Bool
    let palette: BlendPalette
    let s: Strings
    let onTap: () -> Void

    var body: some View {
        let label = switch seconds {
        case 60: s[.blitz_minute_1]
        case 180: s[.blitz_minute_3]
        default: s[.blitz_minute_5]
        }
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(selected ? palette.accent : palette.textPrimary)
                Text(best > 0 ? s.f(.blitz_best, best) : s[.blitz_no_best])
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.vertical, 14)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        selected ? palette.accent : palette.textSecondary.opacity(0.25),
                        lineWidth: selected ? 2.5 : 1
                    )
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Play

private struct BlitzPlay: View {
    let vm: BlitzModel
    let progress: ProgressStore
    let onExit: () -> Void

    var body: some View {
        let palette = progress.palette
        let s = progress.strings

        ZStack {
            if let play = vm.play {
                VStack(spacing: 0) {
                    // ---------- Top bar: exit · clock · score ----------
                    ZStack {
                        HStack {
                            BackButton(palette: palette, icon: "xmark", label: s[.blitz_exit]) { vm.exitToSetup() }
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(palette.star)
                                Text("\(vm.score)")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(palette.textPrimary)
                                    .contentTransition(.numericText())
                            }
                            // Otherwise the running score reads as a bare number with no
                            // hint of what it counts.
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(s[.blitz_score]): \(vm.score)")
                            .padding(.trailing, 6)
                        }
                        let urgent = vm.remainingSec <= 10
                        Text(String(format: "%d:%02d", vm.remainingSec / 60, vm.remainingSec % 60))
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(urgent ? palette.accent : palette.textPrimary)
                            .accessibilityLabel(s.f(.a11y_time_left, vm.remainingSec))
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 2)

                    // ---------- Board ----------
                    BoardView(
                        play: play,
                        palette: palette,
                        colorblind: progress.colorblind,
                        blockShape: progress.shape,
                        strings: s
                    )
                    .id(play.level.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(16)

                    SwatchRow(play: play, palette: palette, strings: s)

                    // ---------- Actions ----------
                    HStack(spacing: 12) {
                        ActionButton(
                            icon: "arrow.uturn.backward",
                            iconColor: palette.textPrimary,
                            label: s[.btn_undo],
                            enabled: play.canUndo && !play.won,
                            palette: palette
                        ) {
                            play.undo()
                        }
                        ActionButton(
                            icon: "forward.end.fill",
                            iconColor: palette.textPrimary,
                            label: s[.blitz_skip],
                            enabled: !play.won,
                            palette: palette
                        ) {
                            vm.skip()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                }
                .phoneContentWidth(BoardContentWidth)
            }

            if vm.phase == .finished {
                BlitzResultOverlay(vm: vm, progress: progress, onExit: onExit)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: vm.phase)
        .onAppear {
            vm.onEffect = { [weak progress] effect in
                if progress?.haptics == true { Haptics.play(effect) }
            }
        }
        .onChange(of: vm.play?.won ?? false) { _, won in
            // Advance after the win animation has had a beat to land.
            if won {
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    vm.onSolved()
                }
            }
        }
    }
}

private struct BlitzResultOverlay: View {
    let vm: BlitzModel
    let progress: ProgressStore
    let onExit: () -> Void

    @State private var appeared = false

    var body: some View {
        let palette = progress.palette
        let s = progress.strings

        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 0) {
                Text(s[.blitz_time_up])
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                Text(s.plural(.blitz_solved, vm.score))
                    .font(.system(size: 16, design: .rounded))
                    .foregroundStyle(palette.textSecondary)
                    .padding(.top, 12)
                if vm.isNewBest {
                    Text(s[.blitz_new_best])
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.star)
                        .padding(.top, 6)
                }

                Spacer().frame(height: 20)

                Button {
                    vm.start(currentBest: progress.blitzBests[vm.durationSec] ?? 0, premium: progress.premium)
                } label: {
                    Text(s[.blitz_play_again])
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 50)
                        .background(palette.accent, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(PressableButtonStyle())

                HStack(spacing: 8) {
                    Button(s[.blitz_change_time]) { vm.exitToSetup() }
                    Button(s[.blitz_home], action: onExit)
                }
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(palette.textSecondary)
                .buttonStyle(.plain)
                .padding(.top, 12)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: 340)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.25), radius: 30, y: 10)
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { appeared = true }
        }
    }
}
