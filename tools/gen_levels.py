#!/usr/bin/env python3
"""Generate Blendfall iOS GeneratedLevels.swift from the Android level data files.

Reads the three Kotlin sources that hold raw boards — GeneratedClassic.kt (Classic
chapters I-III), LegacyClassic.kt (chapters IV-VI) and BigPackLevels.kt (the two
80-level mechanic packs) — and emits one Swift file of `RawLevel` arrays. The level
*catalog* (grouping, tips, move limits, unlock rules) lives in Levels.swift by hand;
only the board data is generated.
"""
import re
from pathlib import Path

SRC = Path("/Users/rongo/AndroidStudioProjects/Blendfall/app/src/main/java/com/rongo/blendfall/levels")
OUT = Path("/Users/rongo/Desktop/ios/Blendfall/Blendfall/Levels/GeneratedLevels.swift")

R_CALL = re.compile(r'^r\((\d+),\s*(.*?)\),?$')


def parse_level(line: str):
    """`r(3, "###", "#R#", "###"),` -> (3, ["###", "#R#", "###"]) or None."""
    m = R_CALL.match(line.strip())
    if not m:
        return None
    return int(m.group(1)), re.findall(r'"([^"]*)"', m.group(2))


def parse_chapters(path: Path):
    """The `List<List<RawLevel>>` in GeneratedClassic.kt / LegacyClassic.kt."""
    chapters, current = [], None
    for line in path.read_text().splitlines():
        s = line.strip()
        if s == "listOf(":
            current = []
        elif s in (")", "),") and current is not None:
            chapters.append(current)
            current = None
        elif current is not None:
            lvl = parse_level(s)
            if lvl:
                current.append(lvl)
    return chapters


def parse_named_lists(path: Path):
    """The top-level `val <name>: List<RawLevel> = listOf(` blocks in BigPackLevels.kt."""
    lists, name, current = {}, None, None
    for line in path.read_text().splitlines():
        s = line.strip()
        m = re.match(r"val (\w+): List<RawLevel> = listOf\($", s)
        if m:
            name, current = m.group(1), []
            continue
        if current is None:
            continue
        if s in (")", "),"):
            lists[name] = current
            name, current = None, None
            continue
        lvl = parse_level(s)
        if lvl:
            current.append(lvl)
    return lists


def emit(levels, indent):
    pad = " " * indent
    out = []
    for par, rows in levels:
        joined = ", ".join(f'"{r}"' for r in rows)
        out.append(f"{pad}r({par}, {joined}),")
    return out


generated = parse_chapters(SRC / "GeneratedClassic.kt")
legacy = parse_chapters(SRC / "LegacyClassic.kt")
packs = parse_named_lists(SRC / "BigPackLevels.kt")

lines = ["""//
//  GeneratedLevels.swift
//  Blendfall
//
//  GENERATED from the Android app's level data — regenerate with tools/gen_levels.py
//  rather than editing boards by hand. Every board is solver-verified with
//  par == BFS optimal. Classic (GeneratedClassic + LegacyClassic) carries no special
//  tiles at all; the mechanic tiles live only in the two BigPackLevels campaigns.
//

import Foundation

nonisolated private func r(_ par: Int, _ rows: String...) -> RawLevel { RawLevel(par: par, rows: rows) }
"""]

lines.append("""/// Classic levels 15-150: index 0 finishes chapter I (36 levels); 1 and 2 are
/// chapters II and III.
nonisolated enum GeneratedClassic {
    static let chapters: [[RawLevel]] = [""")
for chapter in generated:
    lines.append("        [")
    lines.extend(emit(chapter, 12))
    lines.append("        ],")
lines.append("    ]\n}\n")

lines.append("""/// The back half of Classic — 150 boards that become chapters IV, V and VI after
/// being re-sorted by par across all three.
nonisolated enum LegacyClassic {
    static let chapters: [[RawLevel]] = [""")
for chapter in legacy:
    lines.append("        [")
    lines.extend(emit(chapter, 12))
    lines.append("        ],")
lines.append("    ]\n}\n")

lines.append("""/// The two 80-level campaign packs. Par climbs 4 -> 8 in blocks of sixteen. Star Hunt
/// stars sit off the solver's optimal line; Portals boards break without their rings.
nonisolated enum BigPackLevels {""")
for name in ("starHunt", "portals"):
    lines.append(f"\n    static let {name}: [RawLevel] = [")
    lines.extend(emit(packs[name], 8))
    lines.append("    ]")
lines.append("}")

OUT.write_text("\n".join(lines) + "\n")

total_classic = sum(len(c) for c in generated) + sum(len(c) for c in legacy)
print(f"wrote {OUT}")
print(f"  GeneratedClassic: {[len(c) for c in generated]} = {sum(len(c) for c in generated)}")
print(f"  LegacyClassic:    {[len(c) for c in legacy]} = {sum(len(c) for c in legacy)}")
print(f"  starHunt: {len(packs['starHunt'])}  portals: {len(packs['portals'])}")
print(f"  classic total (+14 hand-authored tutorial) = {total_classic + 14}")
