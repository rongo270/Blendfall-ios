//
//  BlockShapes.swift
//  Blendfall
//
//  The silhouette every block (and fusion ghost) is drawn with.
//  SQUARE is free, CIRCLE/DIAMOND come with Premium, the rest with their pack:
//  Candy = Heart & Star, Nature = Hexagon & Flower, Retro = Triangle & Gem.
//

import SwiftUI

nonisolated enum BlockShape: String, CaseIterable, Identifiable, Sendable {
    case square, circle, diamond
    case heart, star
    case hexagon, flower
    case triangle, gem

    var id: String { rawValue }

    var nameKey: Strings.K {
        switch self {
        case .square: return .shape_square
        case .circle: return .shape_circle
        case .diamond: return .shape_diamond
        case .heart: return .shape_heart
        case .star: return .shape_star
        case .hexagon: return .shape_hexagon
        case .flower: return .shape_flower
        case .triangle: return .shape_triangle
        case .gem: return .shape_gem
        }
    }

    var tier: Tier {
        switch self {
        case .square: return .free
        case .circle, .diamond: return .premium
        case .heart, .star: return .candy
        case .hexagon, .flower: return .nature
        case .triangle, .gem: return .retro
        }
    }

    static func fromId(_ id: String) -> BlockShape { BlockShape(rawValue: id) ?? .square }
}

/// SwiftUI Shape that draws any of the block silhouettes.
nonisolated struct TileShape: Shape {
    let kind: BlockShape

    func path(in rect: CGRect) -> Path {
        switch kind {
        case .square:
            return Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) * 0.2)
        case .circle:
            return Path(ellipseIn: rect)
        case .diamond:
            var p = Path()
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            p.closeSubpath()
            return p
        case .heart:
            let w = rect.width, h = rect.height
            let x0 = rect.minX, y0 = rect.minY
            var p = Path()
            p.move(to: CGPoint(x: x0 + w / 2, y: y0 + h * 0.92))
            p.addCurve(
                to: CGPoint(x: x0 + w / 2, y: y0 + h * 0.26),
                control1: CGPoint(x: x0 - w * 0.18, y: y0 + h * 0.52),
                control2: CGPoint(x: x0 + w * 0.08, y: y0 - h * 0.08)
            )
            p.addCurve(
                to: CGPoint(x: x0 + w / 2, y: y0 + h * 0.92),
                control1: CGPoint(x: x0 + w * 0.92, y: y0 - h * 0.08),
                control2: CGPoint(x: x0 + w * 1.18, y: y0 + h * 0.52)
            )
            p.closeSubpath()
            return p
        case .star:
            let cx = rect.midX, cy = rect.midY
            let outer = min(rect.width, rect.height) / 2
            let inner = outer * 0.45
            var p = Path()
            for i in 0..<10 {
                let r = i % 2 == 0 ? outer : inner
                let angle = -Double.pi / 2 + Double(i) * .pi / 5
                let pt = CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
            return p
        case .hexagon:
            let r = min(rect.width, rect.height) / 2
            let cx = rect.midX, cy = rect.midY
            var p = Path()
            for i in 0..<6 {
                let angle = Double.pi / 6 + Double(i) * .pi / 3 // pointy-top
                let pt = CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
            return p
        case .flower:
            // Four petal circles plus a core circle; overlapping ovals union into a clover.
            let cx = rect.midX, cy = rect.midY
            let r = min(rect.width, rect.height) / 2
            let petal = r * 0.52
            var p = Path()
            let rects = [
                CGRect(x: cx - r, y: cy - petal, width: petal * 2, height: petal * 2),
                CGRect(x: cx + r - petal * 2, y: cy - petal, width: petal * 2, height: petal * 2),
                CGRect(x: cx - petal, y: cy - r, width: petal * 2, height: petal * 2),
                CGRect(x: cx - petal, y: cy + r - petal * 2, width: petal * 2, height: petal * 2),
                CGRect(x: cx - petal, y: cy - petal, width: petal * 2, height: petal * 2),
            ]
            for r in rects { p.addEllipse(in: r) }
            return p
        case .triangle:
            var p = Path()
            p.move(to: CGPoint(x: rect.minX + rect.width / 2, y: rect.minY + rect.height * 0.06))
            p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.96, y: rect.minY + rect.height * 0.94))
            p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.04, y: rect.minY + rect.height * 0.94))
            p.closeSubpath()
            return p
        case .gem:
            // Regular pointy-top pentagon.
            let cx = rect.midX, cy = rect.midY
            let r = min(rect.width, rect.height) / 2
            var p = Path()
            for i in 0..<5 {
                let angle = -Double.pi / 2 + Double(i) * 2 * .pi / 5
                let pt = CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
            return p
        }
    }
}
