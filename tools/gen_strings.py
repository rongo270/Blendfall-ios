#!/usr/bin/env python3
"""Generate Blendfall iOS Strings.swift from the Android res/values*/strings.xml files."""
import re
import xml.etree.ElementTree as ET
from pathlib import Path

RES = Path("/Users/rongo/AndroidStudioProjects/Blendfall/app/src/main/res")
OUT = Path("/Users/rongo/Desktop/ios/Blendfall/Blendfall/Localization/Strings.swift")

# Keys the iOS app has that Android has no equivalent for. Their translations live
# only in the generated file, so they are read back out of it and carried over
# rather than being lost on every regeneration.
IOS_ONLY = ["home_no_ads", "home_stars"]

# folder suffix -> Language case (values -> en, values-iw -> he)
LANGS = {
    "values": "en", "values-ar": "ar", "values-de": "de", "values-es": "es",
    "values-fr": "fr", "values-it": "it", "values-iw": "he", "values-ja": "ja",
    "values-ko": "ko", "values-pl": "pl", "values-pt": "pt", "values-ru": "ru",
    "values-tr": "tr", "values-zh": "zh",
}


def android_unescape(text: str) -> str:
    """Resolve Android escape sequences into real characters."""
    out = []
    i = 0
    while i < len(text):
        c = text[i]
        if c == "\\" and i + 1 < len(text):
            n = text[i + 1]
            if n == "n":
                out.append("\n")
            elif n == "'":
                out.append("'")
            elif n == '"':
                out.append('"')
            elif n == "\\":
                out.append("\\")
            elif n == "t":
                out.append("\t")
            elif n == "@":
                out.append("@")
            else:
                out.append(n)
            i += 2
        else:
            out.append(c)
            i += 1
    return "".join(out)


def to_swift_format(text: str) -> str:
    """Android %n$s -> %n$@ and bare %s -> %@ for String(format:)."""
    text = re.sub(r"%(\d+\$)s", r"%\1@", text)
    return text.replace("%s", "%@")


def swift_escape(text: str) -> str:
    return (
        text.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\t", "\\t")
    )


def parse(folder: Path):
    strings, plurals = {}, {}
    tree = ET.parse(folder / "strings.xml")
    for el in tree.getroot():
        name = el.get("name")
        if el.tag == "string":
            raw = "".join(el.itertext())
            strings[name] = swift_escape(to_swift_format(android_unescape(raw)))
        elif el.tag == "plurals":
            forms = {}
            for item in el:
                raw = "".join(item.itertext())
                forms[item.get("quantity")] = swift_escape(
                    to_swift_format(android_unescape(raw))
                )
            plurals[name] = forms
    return strings, plurals


def previous_ios_only():
    """Pull the iOS-only keys' translations back out of the last generated file."""
    carried = {lang: {} for lang in LANGS.values()}
    if not OUT.exists():
        return carried
    text = OUT.read_text()
    lang = None
    for line in text.splitlines():
        m = re.match(r"\s*static let table_(\w+): \[K: String\] = \[", line)
        if m:
            lang = m.group(1)
            continue
        if lang is None:
            continue
        m = re.match(r'\s*\.(\w+): "(.*)",$', line)
        if m and m.group(1) in IOS_ONLY:
            carried[lang][m.group(1)] = m.group(2)
    return carried


data = {}
for folder, lang in LANGS.items():
    p = RES / folder
    if (p / "strings.xml").exists():
        data[lang] = parse(p)

carried = previous_ios_only()
for lang, (strings, _) in data.items():
    strings.update(carried.get(lang, {}))

en_strings, en_plurals = data["en"]
keys = list(en_strings.keys())
plural_keys = list(en_plurals.keys())

lines = []
lines.append("""//
//  Strings.swift
//  Blendfall
//
//  GENERATED from the Android app's res/values*/strings.xml — regenerate with
//  tools/gen_strings.py rather than editing tables by hand. Every piece of
//  player-facing text in fourteen languages, switchable at runtime. English is
//  the fallback for any missing key. Keys match the Android string names.
//

import SwiftUI

/// The languages the UI can be shown in, switchable at runtime from Settings.
/// Hebrew and Arabic also flip the whole layout to right-to-left.
nonisolated enum Language: String, CaseIterable, Identifiable {
    case en, ar, de, es, fr, he, it, ja, ko, pl, pt, ru, tr, zh

    var id: String { rawValue }

    var isRTL: Bool { self == .he || self == .ar }

    /// The language's own name, shown in the language picker.
    var nativeName: String {
        switch self {
        case .en: return "English"
        case .ar: return "العربية"
        case .de: return "Deutsch"
        case .es: return "Español"
        case .fr: return "Français"
        case .he: return "עברית"
        case .it: return "Italiano"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .pl: return "Polski"
        case .pt: return "Português"
        case .ru: return "Русский"
        case .tr: return "Türkçe"
        case .zh: return "中文"
        }
    }

    /// Best match for the device locale, used while the player hasn't picked a language.
    static func deviceDefault(for locale: Locale = .current) -> Language {
        let code = locale.language.languageCode?.identifier ?? "en"
        switch code {
        case "iw": return .he // legacy Hebrew code
        default: return Language(rawValue: code) ?? .en
        }
    }
}

nonisolated struct Strings {
    let language: Language
""")

# K enum
lines.append("    enum K: String, CaseIterable {")
for chunk_start in range(0, len(keys), 6):
    chunk = keys[chunk_start:chunk_start + 6]
    lines.append("        case " + ", ".join(chunk))
lines.append("        // plurals")
lines.append("        case " + ", ".join(plural_keys))
lines.append("    }")

lines.append("""
    private let table: [K: String]
    private let pluralTable: [K: [String: String]]

    init(_ language: Language) {
        self.language = language
        table = Strings.tables[language] ?? Strings.table_en
        pluralTable = Strings.pluralTables[language] ?? Strings.plurals_en
    }

    /// Plain lookup: `strings[.home_play]`.
    subscript(_ k: K) -> String { table[k] ?? Strings.table_en[k] ?? k.rawValue }

    /// Formatted lookup for keys with placeholders: `strings.f(.level_label, 12)`.
    func f(_ k: K, _ args: CVarArg...) -> String {
        String(format: self[k], arguments: args)
    }

    /// Quantity-aware lookup: `strings.plural(.win_moves, 3)`.
    func plural(_ k: K, _ n: Int) -> String {
        let forms = pluralTable[k] ?? Strings.plurals_en[k] ?? [:]
        let form = forms[quantity(n)] ?? forms["other"] ?? forms.values.first ?? ""
        return String(format: form, n)
    }

    /// CLDR-ish plural category for the current language — enough for the
    /// quantities the translation tables actually contain.
    private func quantity(_ n: Int) -> String {
        switch language {
        case .ja, .ko, .zh, .tr: return "other"
        case .fr, .pt: return n <= 1 ? "one" : "other"
        case .ru:
            let m10 = n % 10, m100 = n % 100
            if m10 == 1 && m100 != 11 { return "one" }
            if (2...4).contains(m10) && !(12...14).contains(m100) { return "few" }
            return "many"
        case .pl:
            if n == 1 { return "one" }
            let m10 = n % 10, m100 = n % 100
            if (2...4).contains(m10) && !(12...14).contains(m100) { return "few" }
            return "many"
        case .ar:
            switch n {
            case 0: return "zero"
            case 1: return "one"
            case 2: return "two"
            default:
                let m100 = n % 100
                if (3...10).contains(m100) { return "few" }
                if m100 >= 11 { return "many" }
                return "other"
            }
        case .he:
            if n == 1 { return "one" }
            if n == 2 { return "two" }
            return "other"
        default: return n == 1 ? "one" : "other"
        }
    }
}
""")

# tables
langs_present = list(data.keys())
lines.append("// MARK: - Translation tables\n")
lines.append("nonisolated extension Strings {\n")
lines.append("    static let tables: [Language: [K: String]] = [")
for lang in langs_present:
    lines.append(f"        .{lang}: table_{lang},")
lines.append("    ]\n")
lines.append("    static let pluralTables: [Language: [K: [String: String]]] = [")
for lang in langs_present:
    lines.append(f"        .{lang}: plurals_{lang},")
lines.append("    ]")

for lang in langs_present:
    strings, plurals = data[lang]
    lines.append(f"\n    static let table_{lang}: [K: String] = [")
    for k in keys:
        if k in strings:
            lines.append(f'        .{k}: "{strings[k]}",')
    lines.append("    ]")
    lines.append(f"\n    static let plurals_{lang}: [K: [String: String]] = [")
    for k in plural_keys:
        if k in plurals:
            forms = ", ".join(f'"{q}": "{v}"' for q, v in plurals[k].items())
            lines.append(f"        .{k}: [{forms}],")
    lines.append("    ]")
lines.append("}")

lines.append("""
// MARK: - Environment plumbing

private struct StringsKey: EnvironmentKey {
    static let defaultValue = Strings(.en)
}

extension EnvironmentValues {
    var strings: Strings {
        get { self[StringsKey.self] }
        set { self[StringsKey.self] = newValue }
    }
}
""")

OUT.write_text("\n".join(lines))
missing = {lang: [k for k in keys if k not in data[lang][0]] for lang in langs_present}
for lang, m in missing.items():
    if m:
        print(f"{lang}: missing {len(m)} keys: {m[:5]}")
print(f"wrote {OUT} — {len(keys)} keys + {len(plural_keys)} plurals, {len(langs_present)} languages")
