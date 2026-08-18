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
        case .pickup: light.impactOccurred(intensity: 0.5)
        case .warp: rigid.impactOccurred(intensity: 0.8)
        case .win: notify.notificationOccurred(.success)
        case .fail: notify.notificationOccurred(.error)
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

/// The one-letter colorblind aid drawn on a block.
///
/// Deliberately its own string key rather than `colorName(color).prefix(1)`: taking the
/// first letter of the localized name collides in several of the shipped languages —
/// Hebrew כחול (blue) and כתום (orange) both start כ, German Gelb and Grün both start G —
/// so the aid was ambiguous on exactly the pairs the blend mechanic produces.
func cbLetter(_ color: GameColor, _ s: Strings) -> String {
    switch color {
    case .red: return s[.cb_red]
    case .yellow: return s[.cb_yellow]
    case .blue: return s[.cb_blue]
    case .orange: return s[.cb_orange]
    case .green: return s[.cb_green]
    case .purple: return s[.cb_purple]
    }
}

/// Readable ink for text sitting on a filled block or button.
///
/// White was hardcoded, but yellow, orange and green are all light blocks, so the
/// colorblind letter and the swatch count — the two things most in need of being
/// readable — were the least readable text in the app. Choosing by luminance clears the
/// large-text bar on every block in all eleven palettes.
func onBlockColor(_ block: Color) -> Color {
    block.luminance > 0.4 ? Color(hex: 0x1A1A1A) : .white
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
    /// Spoken name — without it VoiceOver finds a button and can only say "button".
    var label: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(palette.textPrimary)
                .frame(width: 44, height: 44)
                .background(palette.surface.opacity(0.8), in: Circle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(label ?? "")
    }
}

// MARK: - Stars

struct StarsRow: View {
    let earned: Int
    let size: Double
    let palette: BlendPalette
    var spacing: Double = 4

    /// Spoken instead of "star, star, star" — three identical icons say nothing about
    /// how many of them are lit. Pass nil where an enclosing element already says it.
    var label: String?

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<3, id: \.self) { i in
                // An outline rather than a faint fill: earned-vs-unearned is then a
                // difference in shape, not only in colour.
                Image(systemName: i < earned ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(i < earned ? palette.star : palette.textSecondary.opacity(0.45))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? "")
        .accessibilityHidden(label == nil)
    }
}

// MARK: - Pickup star

/// Star Hunt's collectible, drawn rather than iconified so the board and the UI counters
/// share one shape and can never drift apart.
///
/// A five-pointed star, lit from the top: the body carries a vertical gradient and the
/// points are outlined a shade lighter, which keeps the silhouette readable at 14pt in a
/// progress row as well as at 40pt on a board cell.
private let starInnerRatio = 0.45
private let starPoints = 5

/// The star's silhouette, sized so `radius` is the distance to a point.
func pickupStarPath(center: CGPoint, radius: Double) -> Path {
    var path = Path()
    for i in 0..<(starPoints * 2) {
        let r = i.isMultiple(of: 2) ? radius : radius * starInnerRatio
        // Start at the top so the star always sits upright.
        let angle = -Double.pi / 2 + Double(i) * Double.pi / Double(starPoints)
        let p = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
        if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
    }
    path.closeSubpath()
    return path
}

/// Draws a collectible star centered on `center`, with `radius` out to its points.
/// Used by the board canvas for an uncollected pickup and by `PickupStarIcon` everywhere
/// a pickup star appears in the UI.
func drawPickupStar(_ ctx: inout GraphicsContext, center: CGPoint, radius: Double, color: Color) {
    let outline = pickupStarPath(center: center, radius: radius)
    ctx.fill(
        outline,
        with: .linearGradient(
            Gradient(colors: [color.lighten(0.32), color, color.darken(0.22)]),
            startPoint: CGPoint(x: center.x, y: center.y - radius),
            endPoint: CGPoint(x: center.x, y: center.y + radius)
        )
    )
    // A thin lighter edge, thin enough to vanish at small sizes rather than muddy the
    // points.
    ctx.stroke(outline, with: .color(color.lighten(0.45).opacity(0.9)), lineWidth: radius * 0.10)
}

/// The pickup star as a UI element, for counters and pack cards. Sized like an SF Symbol
/// so it drops into an HStack beside text without extra alignment work.
struct PickupStarIcon: View {
    let size: Double
    let color: Color

    var body: some View {
        Canvas { ctx, canvasSize in
            let radius = min(canvasSize.width, canvasSize.height) / 2 * 0.98
            var c = ctx
            drawPickupStar(
                &c,
                center: CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2),
                radius: radius,
                color: color
            )
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Pack badge

/// A pack's signature tile, drawn at badge size for its card.
///
/// These are the same marks the board draws on the cells themselves, so a card is a
/// picture of the thing the pack is about rather than a generic decoration — you can
/// recognise a Portals level from the list before opening it.
struct PackBadge: View {
    let packId: String
    let palette: BlendPalette
    let size: Double

    var body: some View {
        Canvas { ctx, canvasSize in
            let c = min(canvasSize.width, canvasSize.height)
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            switch packId {
            case "starhunt":
                var g = ctx
                drawPickupStar(&g, center: center, radius: c * 0.30, color: palette.star)
            case "portals":
                ctx.stroke(
                    Path(ellipseIn: CGRect(
                        x: center.x - c * 0.30, y: center.y - c * 0.30,
                        width: c * 0.60, height: c * 0.60
                    )),
                    with: .color(palette.portal),
                    lineWidth: c * 0.09
                )
                ctx.stroke(
                    Path(ellipseIn: CGRect(
                        x: center.x - c * 0.15, y: center.y - c * 0.15,
                        width: c * 0.30, height: c * 0.30
                    )),
                    with: .color(palette.portal.opacity(0.5)),
                    lineWidth: c * 0.07
                )
            default:
                break
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Layout helpers

/// Formats "3 / 80" so it keeps its own left-to-right order inside an RTL sentence.
///
/// Without the isolate, Hebrew and Arabic render `0 / 6` as `6 / 0`: the two digit runs
/// are separated by neutral characters, the neutrals take the paragraph's RTL direction,
/// and the runs get laid out right-to-left — so a player on move 0 of 6 reads that they
/// are on move 6 of 0. U+2066/U+2069 pin the fragment; they are invisible either way, so
/// LTR locales are unaffected. String resources with the same shape carry the same pair.
func fraction(_ current: Int, _ total: Int) -> String { "\u{2066}\(current) / \(total)\u{2069}" }

/// The width cap for the two screens whose main content is the board itself.
let BoardContentWidth: Double = 720

extension View {
    /// Caps a screen's content at phone width and centers it, so iPads don't get
    /// edge-to-edge stretched phone UI.
    ///
    /// `max` exists for the play screens: menus read badly when a line of text runs the
    /// width of an iPad, but the board is the opposite — it is the content, and holding
    /// it to phone width was what left a tablet showing a small grid in a sea of
    /// background.
    func phoneContentWidth(_ max: Double = 480) -> some View {
        frame(maxWidth: max)
    }
}
