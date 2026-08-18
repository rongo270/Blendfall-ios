//
//  PremiumScreen.swift
//  Blendfall
//
//  The store sheet: the Premium pitch with live theme previews, the three
//  content packs, the 50-hint refill, and the try-before-you-buy quick look
//  with theme and shape pickers.
//

import SwiftUI

private struct StorePack {
    let packId: String
    let tier: Tier
    let nameKey: Strings.K
    let descKey: Strings.K
}

private let storePacks = [
    StorePack(packId: "candy", tier: .candy, nameKey: .pack_candy_name, descKey: .pack_candy_desc),
    StorePack(packId: "nature", tier: .nature, nameKey: .pack_nature_name, descKey: .pack_nature_desc),
    StorePack(packId: "retro", tier: .retro, nameKey: .pack_retro_name, descKey: .pack_retro_desc),
]

private func themesOf(_ tier: Tier) -> [AppTheme] { AppTheme.ordered.filter { $0.tier == tier } }
private func shapesOf(_ tier: Tier) -> [BlockShape] { BlockShape.allCases.filter { $0.tier == tier } }

struct PremiumScreen: View {
    let progress: ProgressStore
    let store: StoreManager

    @Environment(\.dismiss) private var dismiss
    /// Which tier's quick look is open (nil = none).
    @State private var quickLook: Tier?

    private func buy(_ productId: String) {
        Task { await store.buy(productId) }
    }

    var body: some View {
        let palette = progress.palette
        let s = progress.strings
        let ownedTiers = progress.ownedTiers

        ZStack {
            palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    BackButton(palette: palette, icon: "xmark", label: s[.back]) { dismiss() }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                ScrollView {
                    VStack(spacing: 0) {
                        Text(s[.premium_title])
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(palette.star)
                            .onLongPressGesture {
                                #if DEBUG
                                progress.debugTogglePremium()
                                #endif
                            }
                        Text(s[.premium_pitch])
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(palette.textSecondary)
                            .multilineTextAlignment(.center)

                        Spacer().frame(height: 20)

                        VStack(spacing: 0) {
                            FeatureRow(icon: "square.grid.3x3.fill", text: s.f(.premium_feature_packs, Levels.total), palette: palette)
                            FeatureRow(icon: "paintpalette.fill", text: s[.premium_feature_themes], palette: palette)
                            FeatureRow(icon: "seal.fill", text: s[.premium_feature_shapes], palette: palette)
                            FeatureRow(icon: "heart.fill", text: s[.premium_feature_noads], palette: palette)
                        }

                        // Premium really is only 3 themes and 2 shapes; the other six of
                        // each belong to the packs below. Without saying so, Settings'
                        // nine locked themes read as a promise this screen had broken.
                        Text(s[.premium_packs_separate])
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(palette.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 6)

                        Spacer().frame(height: 10)

                        // Quick look at what Premium contains — tap to zoom in.
                        PreviewStrip(tier: .premium, palette: palette, s: s)
                            .contentShape(Rectangle())
                            .onTapGesture { quickLook = .premium }

                        Spacer().frame(height: 18)

                        if progress.premium {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(palette.accent)
                            Text(s[.premium_owned])
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(palette.textPrimary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 6)
                        } else {
                            Button {
                                buy(StoreManager.premiumID)
                            } label: {
                                // No price until StoreKit actually tells us one: the old
                                // fallback printed a hardcoded "$4.99" to players in every
                                // country and currency.
                                let price = store.prices[StoreManager.premiumID]
                                Text(s[.premium_buy] + (price.map { "  ·  " + $0 } ?? ""))
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    // White on the star color measures under 2:1 in every
                                    // palette, which made the money button the least
                                    // readable text in the app.
                                    .foregroundStyle(onBlockColor(palette.star))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 56)
                                    .background(palette.star, in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(PressableButtonStyle())
                            .disabled(!store.canBuy)
                            if !store.canBuy {
                                Text(s[.premium_unavailable])
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(palette.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 8)
                            }
                        }

                        // ---------------- Extras ----------------
                        Spacer().frame(height: 26)
                        HStack {
                            Text(s[.store_extras])
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(palette.textSecondary)
                            Spacer()
                        }
                        .padding(.bottom, 10)

                        ForEach(storePacks, id: \.packId) { pack in
                            let productId = StoreManager.packProduct(pack.packId)
                            ProductCard(
                                title: s[pack.nameKey],
                                subtitle: s[pack.descKey],
                                owned: ownedTiers.contains(pack.tier),
                                price: store.prices[productId],
                                canBuy: store.canBuy,
                                tier: pack.tier,
                                palette: palette,
                                s: s,
                                onOpen: { quickLook = pack.tier },
                                onBuy: { buy(productId) }
                            )
                            .padding(.bottom, 10)
                        }

                        ProductCard(
                            title: s[.hints_pack_name],
                            subtitle: s[.hints_pack_desc] + " · " + s.f(.hints_left, progress.hints),
                            owned: false,
                            price: store.prices[StoreManager.hintsID],
                            canBuy: store.canBuy,
                            tier: nil,
                            palette: palette,
                            s: s,
                            onOpen: nil,
                            onBuy: { buy(StoreManager.hintsID) }
                        )

                        Button {
                            Task { await store.restore() }
                        } label: {
                            Text(s[.premium_restore])
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(palette.textSecondary)
                        }
                        .padding(.top, 12)

                        Spacer().frame(height: 16)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .phoneContentWidth()

            if let tier = quickLook {
                let isPremiumTier = tier == .premium
                let pack = storePacks.first { $0.tier == tier }
                let productId = isPremiumTier ? StoreManager.premiumID : StoreManager.packProduct(pack!.packId)
                QuickLookOverlay(
                    title: isPremiumTier ? s[.premium_title] : s[pack!.nameKey],
                    tier: tier,
                    showLevels: isPremiumTier,
                    owned: ownedTiers.contains(tier),
                    price: store.prices[productId],
                    canBuy: store.canBuy,
                    palette: palette,
                    s: s,
                    onBuy: { buy(productId); quickLook = nil },
                    onDismiss: { quickLook = nil }
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: quickLook != nil)
        .fontDesign(.rounded)
        .environment(\.layoutDirection, progress.language.isRTL ? .rightToLeft : .leftToRight)
    }
}

// MARK: - Previews

/// A believable mid-game position rendered exactly like the real board:
/// '#' wall, '.' floor, uppercase = block, lowercase = target ring.
private let previewBoard = [
    "#...#",
    ".R.b.",
    "#.BY#",
]

private let previewColors: [Character: GameColor] = [
    "R": .red, "Y": .yellow, "B": .blue, "O": .orange, "G": .green, "P": .purple,
]

/// A mini game board drawn with `preview`'s colors and `blockShape` blocks.
private struct GamePreviewBoard: View {
    let preview: BlendPalette
    let blockShape: BlockShape
    let cellSize: Double

    var body: some View {
        VStack(spacing: cellSize * 0.12) {
            ForEach(previewBoard, id: \.self) { row in
                HStack(spacing: cellSize * 0.12) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, ch in
                        ZStack {
                            RoundedRectangle(cornerRadius: cellSize * 0.16)
                                .fill(ch == "#" ? preview.wall : preview.cell)
                            if let block = previewColors[ch] {
                                BlockView(color: block, palette: preview, shape: blockShape)
                                    .padding(cellSize * 0.08)
                            } else if ch.isLowercase, let target = previewColors[Character(ch.uppercased())] {
                                RoundedRectangle(cornerRadius: cellSize * 0.14)
                                    .stroke(preview.block(target), lineWidth: cellSize * 0.07)
                                    .padding(cellSize * 0.14)
                            }
                        }
                        .frame(width: cellSize, height: cellSize)
                    }
                }
            }
        }
        .padding(cellSize * 0.3)
        .background(preview.background, in: RoundedRectangle(cornerRadius: 12))
        // Pinned LTR like the real board: a board is spatial, and in Hebrew and Arabic
        // these previews mirrored while the game they are previewing does not.
        .environment(\.layoutDirection, .leftToRight)
    }
}

/// One mini board per theme the tier unlocks, labeled, drawn with the pack's own blocks.
private struct PreviewStrip: View {
    let tier: Tier
    let palette: BlendPalette
    let s: Strings

    var body: some View {
        let shape = shapesOf(tier).first ?? .square
        HStack(alignment: .top, spacing: 10) {
            ForEach(themesOf(tier)) { theme in
                VStack(spacing: 4) {
                    GamePreviewBoard(preview: theme.palette, blockShape: shape, cellSize: 15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(palette.textSecondary.opacity(0.2), lineWidth: 1)
                        )
                    Text(s[theme.nameKey])
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Try-before-you-buy: a big live board plus theme and shape pickers,
/// so the player sees exactly what their game will look like.
private struct QuickLookOverlay: View {
    let title: String
    let tier: Tier
    let showLevels: Bool
    let owned: Bool
    /// Null until StoreKit resolves a real, localized price — never a hardcoded figure.
    let price: String?
    let canBuy: Bool
    let palette: BlendPalette
    let s: Strings
    let onBuy: () -> Void
    let onDismiss: () -> Void

    @State private var selectedTheme: AppTheme
    @State private var selectedShape: BlockShape

    init(
        title: String, tier: Tier, showLevels: Bool, owned: Bool, price: String?,
        canBuy: Bool, palette: BlendPalette, s: Strings,
        onBuy: @escaping () -> Void, onDismiss: @escaping () -> Void
    ) {
        self.title = title
        self.tier = tier
        self.showLevels = showLevels
        self.owned = owned
        self.price = price
        self.canBuy = canBuy
        self.palette = palette
        self.s = s
        self.onBuy = onBuy
        self.onDismiss = onDismiss
        _selectedTheme = State(initialValue: themesOf(tier).first ?? .classic)
        _selectedShape = State(initialValue: shapesOf(tier).first ?? .square)
    }

    var body: some View {
        let themes = themesOf(tier)
        let shapes = shapesOf(tier)
        let preview = selectedTheme.palette

        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            ScrollView {
                VStack(spacing: 0) {
                    Text(title)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(palette.star)
                    if showLevels {
                        Text(s.f(.premium_feature_packs, Levels.total))
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(palette.textPrimary)
                            .padding(.top, 4)
                    }

                    GamePreviewBoard(preview: preview, blockShape: selectedShape, cellSize: 34)
                        .padding(.top, 14)
                    Text(s[.store_live_preview])
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)

                    SectionHeader(text: s[.store_themes], palette: palette)
                        .padding(.top, 14)
                    HStack(spacing: 8) {
                        ForEach(themes) { theme in
                            ThemeChip(
                                theme: theme,
                                selected: theme == selectedTheme,
                                palette: palette,
                                s: s
                            ) { selectedTheme = theme }
                        }
                    }

                    if !shapes.isEmpty {
                        SectionHeader(text: s[.store_shapes], palette: palette)
                            .padding(.top, 12)
                        HStack(spacing: 12) {
                            ForEach(shapes) { shape in
                                ShapeChip(
                                    shape: shape,
                                    preview: preview,
                                    selected: shape == selectedShape,
                                    palette: palette,
                                    s: s
                                ) { selectedShape = shape }
                            }
                        }
                    }

                    Spacer().frame(height: 18)

                    if owned {
                        Text(s[.store_owned])
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.accent)
                    } else {
                        Button(action: onBuy) {
                            Text(s[.store_buy] + (price.map { " · " + $0 } ?? ""))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(onBlockColor(palette.star))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 48)
                                .background(palette.star, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(PressableButtonStyle())
                        .disabled(!canBuy)
                    }
                    Button(s[.not_now], action: onDismiss)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                        .padding(.top, 12)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 20)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .transition(.opacity)
    }
}

/// A theme option drawn in its own colors — tap to preview it on the board above.
private struct ThemeChip: View {
    let theme: AppTheme
    let selected: Bool
    let palette: BlendPalette
    let s: Strings
    let onTap: () -> Void

    var body: some View {
        let chipPalette = theme.palette
        Button(action: onTap) {
            VStack(spacing: 4) {
                HStack(spacing: 3) {
                    ForEach([GameColor.red, .yellow, .blue], id: \.self) { c in
                        Circle()
                            .fill(chipPalette.block(c))
                            .frame(width: 11, height: 11)
                    }
                }
                Text(s[theme.nameKey])
                    .font(.system(size: 11, weight: selected ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(chipPalette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            // A full 44pt with the selected state spoken: the 2pt accent border was the
            // only thing saying which theme is being previewed.
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(chipPalette.background, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        selected ? palette.accent : palette.textSecondary.opacity(0.25),
                        lineWidth: selected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(s[theme.nameKey])
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// A shape option rendered like a real block — tap to preview it on the board above.
private struct ShapeChip: View {
    let shape: BlockShape
    let preview: BlendPalette
    let selected: Bool
    let palette: BlendPalette
    let s: Strings
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                BlockView(color: .blue, palette: preview, shape: shape)
                    .frame(width: 34, height: 34)
                Text(s[shape.nameKey])
                    .font(.system(size: 11, weight: selected ? .bold : .regular, design: .rounded))
                    .foregroundStyle(palette.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        selected ? palette.accent : palette.textSecondary.opacity(0.25),
                        lineWidth: selected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(s[shape.nameKey])
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct SectionHeader: View {
    let text: String
    let palette: BlendPalette

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(palette.textSecondary)
    }
}

// MARK: - Pieces

private struct FeatureRow: View {
    let icon: String
    let text: String
    let palette: BlendPalette

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(palette.accent)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(palette.textPrimary)
            Spacer()
        }
        .padding(.vertical, 7)
    }
}

private struct ProductCard: View {
    let title: String
    let subtitle: String
    let owned: Bool
    /// Null until StoreKit resolves a real, localized price — never a hardcoded figure.
    let price: String?
    let canBuy: Bool
    let tier: Tier?
    let palette: BlendPalette
    let s: Strings
    let onOpen: (() -> Void)?
    let onBuy: () -> Void

    var body: some View {
        // The pack's own accent color makes each card feel like its theme.
        let packAccent = tier.flatMap { themesOf($0).first?.palette.accent } ?? palette.accent

        VStack(alignment: .leading, spacing: 0) {
            // Title and Buy share a row; the description gets the full card width
            // underneath. Previously all three sat in one row, so a description of any
            // length wrapped into the space beside and below the button and left orphan
            // fragments ("& Star blocks") hanging under it.
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(packAccent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if owned {
                    Text(s[.store_owned])
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.accent)
                } else {
                    Button(action: onBuy) {
                        Text(s[.store_buy] + (price.map { " · " + $0 } ?? ""))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(onBlockColor(packAccent))
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(packAccent, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(!canBuy)
                }
            }
            Text(subtitle)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            if let tier {
                PreviewStrip(tier: tier, palette: palette, s: s)
                    .padding(.top, 12)
                HStack(spacing: 5) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 11))
                    Text(s[.store_tap_preview])
                        .font(.system(size: 11, design: .rounded))
                }
                .foregroundStyle(palette.textSecondary)
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(packAccent.opacity(0.35), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .onTapGesture { onOpen?() }
    }
}
