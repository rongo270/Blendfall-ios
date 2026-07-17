//
//  Theme.swift
//  Blendfall
//
//  The eleven board themes, ported 1:1 from the Android app's palettes, and the
//  purchase tier each one belongs to. A theme is a full palette: backgrounds,
//  board cells, text and the six block colors.
//

import SwiftUI

/// Which purchase unlocks a theme or block shape. FREE needs nothing.
nonisolated enum Tier: Sendable {
    case free, premium, candy, nature, retro
}

nonisolated enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case classic, midnight, neon, sunset, ocean
    case pastel, bubblegum, forest, autumn
    case retro, arcade

    var id: String { rawValue }

    var nameKey: Strings.K {
        switch self {
        case .classic: return .theme_classic
        case .midnight: return .theme_midnight
        case .neon: return .theme_neon
        case .sunset: return .theme_sunset
        case .ocean: return .theme_ocean
        case .pastel: return .theme_pastel
        case .bubblegum: return .theme_bubblegum
        case .forest: return .theme_forest
        case .autumn: return .theme_autumn
        case .retro: return .theme_retro
        case .arcade: return .theme_arcade
        }
    }

    var tier: Tier {
        switch self {
        case .classic, .midnight: return .free
        case .neon, .sunset, .ocean: return .premium
        case .pastel, .bubblegum: return .candy
        case .forest, .autumn: return .nature
        case .retro, .arcade: return .retro
        }
    }

    static func fromId(_ id: String) -> AppTheme { AppTheme(rawValue: id) ?? .classic }

    var palette: BlendPalette { BlendPalette.palettes[self]! }

    /// Presentation order matching the Android settings grid.
    static let ordered: [AppTheme] = [
        .classic, .midnight, .neon, .sunset, .ocean,
        .pastel, .bubblegum, .forest, .autumn, .retro, .arcade,
    ]
}

nonisolated struct BlendPalette: Sendable {
    let isDark: Bool
    let background: Color
    let surface: Color
    let boardBackground: Color
    let cell: Color
    let wall: Color
    let textPrimary: Color
    let textSecondary: Color
    let accent: Color
    let star: Color
    let blocks: [GameColor: Color]

    func block(_ color: GameColor) -> Color { blocks[color]! }
}

nonisolated extension BlendPalette {

    static let palettes: [AppTheme: BlendPalette] = [
        .classic: classic, .midnight: midnight, .neon: neon, .sunset: sunset,
        .ocean: ocean, .pastel: pastel, .bubblegum: bubblegum, .forest: forest,
        .autumn: autumn, .retro: retro, .arcade: arcade,
    ]

    static let classic = BlendPalette(
        isDark: false,
        background: Color(hex: 0xF6F2EA),
        surface: Color(hex: 0xFFFFFF),
        boardBackground: Color(hex: 0xE8E1D4),
        cell: Color(hex: 0xF3EEE3),
        wall: Color(hex: 0xC9BEA9),
        textPrimary: Color(hex: 0x2E2A24),
        textSecondary: Color(hex: 0x8A8272),
        accent: Color(hex: 0x5B8DEF),
        star: Color(hex: 0xF5B301),
        blocks: [
            .red: Color(hex: 0xE94F4F),
            .yellow: Color(hex: 0xF5C518),
            .blue: Color(hex: 0x3E7BE8),
            .orange: Color(hex: 0xF08C1C),
            .green: Color(hex: 0x3FA65C),
            .purple: Color(hex: 0x8A56C9),
        ]
    )

    static let midnight = BlendPalette(
        isDark: true,
        background: Color(hex: 0x12131C),
        surface: Color(hex: 0x1D1F2E),
        boardBackground: Color(hex: 0x1A1C29),
        cell: Color(hex: 0x242738),
        wall: Color(hex: 0x3A3E56),
        textPrimary: Color(hex: 0xEDEFF7),
        textSecondary: Color(hex: 0x8D92AC),
        accent: Color(hex: 0x7AA2FF),
        star: Color(hex: 0xFFC94D),
        blocks: [
            .red: Color(hex: 0xFF5D5D),
            .yellow: Color(hex: 0xFFD447),
            .blue: Color(hex: 0x4D8DFF),
            .orange: Color(hex: 0xFF9A3D),
            .green: Color(hex: 0x4CC470),
            .purple: Color(hex: 0xA36BFF),
        ]
    )

    static let neon = BlendPalette(
        isDark: true,
        background: Color(hex: 0x0A0A12),
        surface: Color(hex: 0x14141F),
        boardBackground: Color(hex: 0x10101B),
        cell: Color(hex: 0x1A1A2A),
        wall: Color(hex: 0x2C2C48),
        textPrimary: Color(hex: 0xF2F2FF),
        textSecondary: Color(hex: 0x7C7C9E),
        accent: Color(hex: 0x00E5FF),
        star: Color(hex: 0xFFE04D),
        blocks: [
            .red: Color(hex: 0xFF2E63),
            .yellow: Color(hex: 0xFFEA00),
            .blue: Color(hex: 0x00B3FF),
            .orange: Color(hex: 0xFF7A00),
            .green: Color(hex: 0x00E676),
            .purple: Color(hex: 0xC64DFF),
        ]
    )

    static let pastel = BlendPalette(
        isDark: false,
        background: Color(hex: 0xFDF7FA),
        surface: Color(hex: 0xFFFFFF),
        boardBackground: Color(hex: 0xF2E9F0),
        cell: Color(hex: 0xFAF3F8),
        wall: Color(hex: 0xD8C7D6),
        textPrimary: Color(hex: 0x4A3F4C),
        textSecondary: Color(hex: 0xA394A6),
        accent: Color(hex: 0x9C89F2),
        star: Color(hex: 0xF7C873),
        blocks: [
            .red: Color(hex: 0xF08E9B),
            .yellow: Color(hex: 0xF6D488),
            .blue: Color(hex: 0x8FB6F0),
            .orange: Color(hex: 0xF3B27E),
            .green: Color(hex: 0x9CCFA5),
            .purple: Color(hex: 0xC2A3E8),
        ]
    )

    static let sunset = BlendPalette(
        isDark: true,
        background: Color(hex: 0x261329),
        surface: Color(hex: 0x351E3C),
        boardBackground: Color(hex: 0x2E1834),
        cell: Color(hex: 0x3E2447),
        wall: Color(hex: 0x5A3763),
        textPrimary: Color(hex: 0xFFEFE2),
        textSecondary: Color(hex: 0xC79BB4),
        accent: Color(hex: 0xFF7E5F),
        star: Color(hex: 0xFFC15E),
        blocks: [
            .red: Color(hex: 0xFF5470),
            .yellow: Color(hex: 0xFFC15E),
            .blue: Color(hex: 0x5E8BFF),
            .orange: Color(hex: 0xFF8E3D),
            .green: Color(hex: 0x4FCB8B),
            .purple: Color(hex: 0xB967FF),
        ]
    )

    static let ocean = BlendPalette(
        isDark: true,
        background: Color(hex: 0x06202E),
        surface: Color(hex: 0x0C3245),
        boardBackground: Color(hex: 0x0A2A3B),
        cell: Color(hex: 0x11405A),
        wall: Color(hex: 0x1D5D7C),
        textPrimary: Color(hex: 0xE3F5FF),
        textSecondary: Color(hex: 0x7FB2C9),
        accent: Color(hex: 0x2ED3B7),
        star: Color(hex: 0xFFD166),
        blocks: [
            .red: Color(hex: 0xFF6B6B),
            .yellow: Color(hex: 0xFFD93D),
            .blue: Color(hex: 0x4CC9F0),
            .orange: Color(hex: 0xFF9E4F),
            .green: Color(hex: 0x43D9A3),
            .purple: Color(hex: 0x9D8DF1),
        ]
    )

    static let forest = BlendPalette(
        isDark: false,
        background: Color(hex: 0xF0F4E8),
        surface: Color(hex: 0xFDFFF6),
        boardBackground: Color(hex: 0xE0E8D2),
        cell: Color(hex: 0xEBF1DF),
        wall: Color(hex: 0xA8B894),
        textPrimary: Color(hex: 0x2C3A26),
        textSecondary: Color(hex: 0x74846A),
        accent: Color(hex: 0x4C9A57),
        star: Color(hex: 0xE8A93C),
        blocks: [
            .red: Color(hex: 0xD95D4E),
            .yellow: Color(hex: 0xE9BB35),
            .blue: Color(hex: 0x4A7FC1),
            .orange: Color(hex: 0xDE8A2E),
            .green: Color(hex: 0x56A05F),
            .purple: Color(hex: 0x8B6DB4),
        ]
    )

    static let retro = BlendPalette(
        isDark: false,
        background: Color(hex: 0xF6EBD9),
        surface: Color(hex: 0xFFF8EC),
        boardBackground: Color(hex: 0xEADFC8),
        cell: Color(hex: 0xF2E8D3),
        wall: Color(hex: 0xC4AE8B),
        textPrimary: Color(hex: 0x4A3B2A),
        textSecondary: Color(hex: 0x94836B),
        accent: Color(hex: 0xE2703A),
        star: Color(hex: 0xE8A93C),
        blocks: [
            .red: Color(hex: 0xD94F30),
            .yellow: Color(hex: 0xE3B505),
            .blue: Color(hex: 0x2E86AB),
            .orange: Color(hex: 0xE2703A),
            .green: Color(hex: 0x7A9432),
            .purple: Color(hex: 0x8E5572),
        ]
    )

    static let bubblegum = BlendPalette(
        isDark: false,
        background: Color(hex: 0xFFE3EF),
        surface: Color(hex: 0xFFF6FA),
        boardBackground: Color(hex: 0xF7CFE2),
        cell: Color(hex: 0xFBE0EC),
        wall: Color(hex: 0xE39BC0),
        textPrimary: Color(hex: 0x54263E),
        textSecondary: Color(hex: 0xB07A96),
        accent: Color(hex: 0xFF5FA2),
        star: Color(hex: 0xFFB438),
        blocks: [
            .red: Color(hex: 0xFF4D6D),
            .yellow: Color(hex: 0xFFC53D),
            .blue: Color(hex: 0x52A7FF),
            .orange: Color(hex: 0xFF8E4F),
            .green: Color(hex: 0x4FD08B),
            .purple: Color(hex: 0xC969F5),
        ]
    )

    static let autumn = BlendPalette(
        isDark: false,
        background: Color(hex: 0xF7EDDD),
        surface: Color(hex: 0xFFFAF0),
        boardBackground: Color(hex: 0xEDD9BC),
        cell: Color(hex: 0xF3E4C9),
        wall: Color(hex: 0xC49A6C),
        textPrimary: Color(hex: 0x46311F),
        textSecondary: Color(hex: 0x97815F),
        accent: Color(hex: 0xD96C2F),
        star: Color(hex: 0xE8A93C),
        blocks: [
            .red: Color(hex: 0xC94F35),
            .yellow: Color(hex: 0xE0A526),
            .blue: Color(hex: 0x4E7CA8),
            .orange: Color(hex: 0xDD7B2E),
            .green: Color(hex: 0x7E8F3A),
            .purple: Color(hex: 0x95627E),
        ]
    )

    static let arcade = BlendPalette(
        isDark: true,
        background: Color(hex: 0x0E0B1E),
        surface: Color(hex: 0x191433),
        boardBackground: Color(hex: 0x130F28),
        cell: Color(hex: 0x1F1840),
        wall: Color(hex: 0x37296B),
        textPrimary: Color(hex: 0xEFEBFF),
        textSecondary: Color(hex: 0x8B7FB8),
        accent: Color(hex: 0xFF3DBB),
        star: Color(hex: 0xFFDF3D),
        blocks: [
            .red: Color(hex: 0xFF3D5A),
            .yellow: Color(hex: 0xFFE43D),
            .blue: Color(hex: 0x3DA8FF),
            .orange: Color(hex: 0xFF8A3D),
            .green: Color(hex: 0x3DFF88),
            .purple: Color(hex: 0xB43DFF),
        ]
    )
}

// MARK: - Color helpers

nonisolated extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    func lighten(_ amount: Double) -> Color {
        let c = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(
            red: r + (1 - r) * amount,
            green: g + (1 - g) * amount,
            blue: b + (1 - b) * amount,
            opacity: a
        )
    }

    func darken(_ amount: Double) -> Color {
        let c = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(
            red: r * (1 - amount),
            green: g * (1 - amount),
            blue: b * (1 - amount),
            opacity: a
        )
    }
}
