//
//  SettingsScreen.swift
//  Blendfall
//
//  Theme and block-shape grids (locked entries route to the paywall),
//  colorblind and haptics toggles, the language picker and About.
//

import SwiftUI

struct SettingsScreen: View {
    let progress: ProgressStore
    let onPremium: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let palette = progress.palette
        let s = progress.strings
        let ownedTiers = progress.ownedTiers

        ZStack {
            palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Text(s[.settings_title])
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                    Spacer()
                    BackButton(palette: palette, icon: "xmark") { dismiss() }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // ---------------- Theme ----------------
                        SectionLabel(text: s[.settings_theme], palette: palette)
                        let themeRows = AppTheme.ordered.chunked(4)
                        ForEach(Array(themeRows.enumerated()), id: \.offset) { _, row in
                            HStack(spacing: 10) {
                                ForEach(row) { candidate in
                                    ThemeCard(
                                        theme: candidate,
                                        selected: candidate == progress.theme,
                                        locked: !ownedTiers.contains(candidate.tier),
                                        palette: palette,
                                        s: s
                                    ) {
                                        if ownedTiers.contains(candidate.tier) {
                                            progress.setTheme(candidate)
                                        } else {
                                            onPremium()
                                        }
                                    }
                                }
                                ForEach(0..<(4 - row.count), id: \.self) { _ in
                                    Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                                }
                            }
                            .padding(.bottom, 10)
                        }

                        // ---------------- Block shape ----------------
                        SectionLabel(text: s[.settings_shape], palette: palette)
                            .padding(.top, 14)
                        let shapeRows = BlockShape.allCases.chunked(3)
                        ForEach(Array(shapeRows.enumerated()), id: \.offset) { _, row in
                            HStack(spacing: 10) {
                                ForEach(row) { candidate in
                                    ShapeCard(
                                        shape: candidate,
                                        selected: candidate == progress.shape,
                                        locked: !ownedTiers.contains(candidate.tier),
                                        palette: palette,
                                        s: s
                                    ) {
                                        if ownedTiers.contains(candidate.tier) {
                                            progress.setShape(candidate)
                                        } else {
                                            onPremium()
                                        }
                                    }
                                }
                                ForEach(0..<(3 - row.count), id: \.self) { _ in
                                    Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                                }
                            }
                            .padding(.bottom, 10)
                        }

                        // ---------------- Toggles ----------------
                        Spacer().frame(height: 14)
                        ToggleRow(
                            title: s[.settings_colorblind],
                            subtitle: s[.settings_colorblind_desc],
                            isOn: Binding(
                                get: { progress.colorblind },
                                set: { progress.setColorblind($0) }
                            ),
                            palette: palette
                        )
                        ToggleRow(
                            title: s[.settings_haptics],
                            subtitle: s[.settings_haptics_desc],
                            isOn: Binding(
                                get: { progress.haptics },
                                set: { progress.setHaptics($0) }
                            ),
                            palette: palette
                        )

                        // ---------------- Language ----------------
                        Spacer().frame(height: 14)
                        SectionLabel(text: s[.settings_language], palette: palette)
                        LanguagePicker(progress: progress, palette: palette, s: s)

                        Spacer().frame(height: 28)
                        SectionLabel(text: s[.settings_about], palette: palette)
                        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                        Text(s.f(.about_body, version))
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(palette.textSecondary)
                            .padding(.top, 6)
                            .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .phoneContentWidth()
        }
        .fontDesign(.rounded)
        .environment(\.layoutDirection, progress.language.isRTL ? .rightToLeft : .leftToRight)
    }
}

private extension Array {
    func chunked(_ size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}

private struct LanguagePicker: View {
    let progress: ProgressStore
    let palette: BlendPalette
    let s: Strings

    var body: some View {
        Menu {
            Button {
                progress.setLanguage(nil)
            } label: {
                if progress.languageOverride == nil {
                    Label(s[.language_system], systemImage: "checkmark")
                } else {
                    Text(s[.language_system])
                }
            }
            ForEach(Language.allCases) { lang in
                Button {
                    progress.setLanguage(lang)
                } label: {
                    if progress.languageOverride == lang {
                        Label(lang.nativeName, systemImage: "checkmark")
                    } else {
                        Text(lang.nativeName)
                    }
                }
            }
        } label: {
            HStack {
                Text(progress.languageOverride?.nativeName ?? s[.language_system])
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(palette.textSecondary.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

private struct SectionLabel: View {
    let text: String
    let palette: BlendPalette

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(palette.textSecondary)
            .padding(.vertical, 8)
    }
}

private struct ThemeCard: View {
    let theme: AppTheme
    let selected: Bool
    let locked: Bool
    let palette: BlendPalette
    let s: Strings
    let onTap: () -> Void

    var body: some View {
        let preview = theme.palette
        Button(action: onTap) {
            VStack(spacing: 6) {
                HStack(spacing: 3) {
                    ForEach([GameColor.red, .yellow, .blue], id: \.self) { c in
                        Circle()
                            .fill(preview.block(c))
                            .frame(width: 12, height: 12)
                    }
                }
                HStack(spacing: 3) {
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(preview.textSecondary)
                    }
                    Text(s[theme.nameKey])
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(preview.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(preview.background, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        selected ? palette.accent : palette.textSecondary.opacity(0.3),
                        lineWidth: selected ? 2.5 : 1
                    )
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}

private struct ShapeCard: View {
    let shape: BlockShape
    let selected: Bool
    let locked: Bool
    let palette: BlendPalette
    let s: Strings
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                TileShape(kind: shape)
                    .fill(palette.block(.blue).opacity(locked ? 0.35 : 1))
                    .frame(width: 30, height: 30)
                HStack(spacing: 3) {
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(palette.textSecondary)
                    }
                    Text(s[shape.nameKey])
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(locked ? palette.textSecondary : palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        selected ? palette.accent : palette.textSecondary.opacity(0.3),
                        lineWidth: selected ? 2.5 : 1
                    )
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}

private struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let palette: BlendPalette

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(palette.textSecondary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(palette.accent)
        }
        .padding(.vertical, 8)
    }
}
