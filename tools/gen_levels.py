import re
from pathlib import Path

src = Path("/Users/rongo/AndroidStudioProjects/Blendfall/app/src/main/java/com/rongo/blendfall/levels/GeneratedLevels.kt").read_text()
out = []
out.append("""//
//  GeneratedLevels.swift
//  Blendfall
//
//  GENERATED from the Android app's GeneratedLevels.kt — do not edit by hand.
//  260 solver-verified levels, packs 5..30, par == BFS-optimal.
//

import Foundation

nonisolated enum GeneratedLevels {

    private static func l(_ pack: Int, _ index: Int, _ par: Int, _ rows: String...) -> Level {
        Level(id: "p\\(pack + 1)l\\(index + 1)", pack: pack, index: index, par: par, rows: rows)
    }

    static let packs: [Pack] = [""")

for line in src.splitlines():
    s = line.strip()
    m = re.match(r"Pack\((\d+), R\.string\.(\w+), premium = (true|false), levels = listOf\(", s)
    if m:
        out.append(f"        Pack(id: {m.group(1)}, nameKey: .{m.group(2)}, premium: {m.group(3)}, levels: [")
        continue
    if re.match(r"l\(\d+, \d+, \d+,", s):
        out.append("            " + s)
        continue
    if s == ")),":
        out.append("        ]),")
        continue

out.append("    ]")
out.append("}")
Path("/Users/rongo/Desktop/ios/Blendfall/Blendfall/GeneratedLevels.swift").write_text("\n".join(out) + "\n")
# sanity: count levels and packs
text = "\n".join(out)
print("packs:", text.count("Pack(id:"), "levels:", len(re.findall(r"\bl\(\d+, \d+, \d+,", text)))
