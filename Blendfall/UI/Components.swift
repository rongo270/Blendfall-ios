//
//  Components.swift
//  Blendfall
//
//  Small shared pieces: haptics, block tiles, buttons, headers and the
//  name helpers for colors and directions.
//

import SwiftUI
import UIKit

// MARK: - Haptics

/// Haptic ticks for slides, blends, blocked moves and wins — the iOS-native
/// equivalents of the Android HapticFeedbackConstants mapping.
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let notify = UINotificationFeedbackGenerator()

    static func play(_ effect: GameEffect) {
        switch effect {
        case .slide: light.impactOccurred()
        case .fuse: rigid.impactOccurred(intensity: 1.0)
        case .blocked: soft.impactOccurred(intensity: 0.6)
        case .win: notify.notificationOccurred(.success)
        }
    }

    static func tap() { light.impactOccurred(intensity: 0.7) }
}

// MARK: - Names

func colorName(_ color: GameColor, _ s: Strings) -> String {
    switch color {
    case .red: return s[.color_red]
    case .yellow: return s[.color_yellow]
    case .blue: return s[.color_blue]
    case .orange: return s[.color_orange]
    case .green: return s[.color_green]
    case .purple: return s[.color_purple]
    }
}

func dirName(_ dir: Direction, _ s: Strings) -> String {
    switch dir {
    case .up: return s[.dir_up]
    case .down: return s[.dir_down]
    case .left: return s[.dir_left]
    case .right: return s[.dir_right]
    }
}

// MARK: - Block tile

/// A single game block: the theme color with a soft top-light gradient, cut to
/// the chosen silhouette. Used by the board, the home screen and every preview.
struct BlockView: View {
    let color: GameColor
    let palette: BlendPalette
    let shape: BlockShape

    var body: some View {
        let tint = palette.block(color)
        TileShape(kind: shape)
            .fill(
                LinearGradient(
                    colors: [tint.lighten(0.18), tint, tint.darken(0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

// MARK: - Buttons

/// Undo / Refresh / Hint style button: icon + label on a rounded surface.
struct ActionButton: View {
    let icon: String
    let iconColor: Color
    let label: String
    let enabled: Bool
    let palette: BlendPalette
    var big = false
    var emphasized = false
    let action: () -> Void

    @State private var pulse = false

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: big ? 20 : 16, weight: .semibold))
                    .foregroundStyle(emphasized ? .white : iconColor)
                Text(label)
                    .font(.system(size: big ? 17 : 14, weight: emphasized ? .black : .semibold, design: .rounded))
                    .foregroundStyle(emphasized ? .white : palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, big ? 12 : 10)
            .padding(.vertical, big ? 14 : 10)
            .frame(maxWidth: .infinity)
            .background(emphasized ? palette.accent : palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .scaleEffect(emphasized && pulse ? 1.07 : 1)
        .onChange(of: emphasized, initial: true) { _, isOn in
            if isOn {
                withAnimation(.easeInOut(duration: 0.42).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) { pulse = false }
            }
        }
    }
}

/// Springy press-down scale, the standard game-button feel.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Round chevron back button used on every pushed screen.
struct BackButton: View {
    let palette: BlendPalette
    var icon = "chevron.left"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(palette.textPrimary)
                .frame(width: 40, height: 40)
                .background(palette.surface.opacity(0.8), in: Circle())
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Stars

struct StarsRow: View {
    let earned: Int
    let size: Double
    let palette: BlendPalette
    var spacing: Double = 4

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: "star.fill")
                    .font(.system(size: size))
                    .foregroundStyle(i < earned ? palette.star : palette.textSecondary.opacity(0.25))
            }
        }
    }
}

// MARK: - Layout helpers

extension View {
    /// Caps a screen's content at phone width and centers it, so iPads don't get
    /// edge-to-edge stretched phone UI.
    func phoneContentWidth() -> some View {
        frame(maxWidth: 480)
    }
}
