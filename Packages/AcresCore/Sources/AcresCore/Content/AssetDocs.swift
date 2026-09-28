import Foundation

/// Renders `docs/ASSETS.md` from the manifests.
public enum AssetDocs {

    public static func markdown() -> String {
        var out = """
        # Acres — Asset List

        > Generated from `Packages/AcresCore/Sources/AcresCore/Content/AssetManifest.swift`
        > and `AudioManifest.swift`. Do not edit by hand: run
        > `swift run acres-tools assets > ../../docs/ASSETS.md` from `Packages/AcresCore`.

        Every visual is requested **by name**. To replace placeholder art, add a PNG with
        exactly that name to `Acres/Resources/Assets.xcassets/Art/` (drag it in as an Image Set).
        The game picks it up automatically: no code changes. Anything still missing is drawn
        procedurally in code.

        ## Art direction

        - **Camera:** top-down 3/4 view, looking down at about 60–70°. We see the ground from above
          and the *front* (south-facing) side of things standing on it. Roofs are visible from above.
        - **Light:** from the upper left. Soft contact shadows are added by the game, so **do not
          paint ground shadows** into standing sprites (small self-shadows are fine).
        - **Style:** indie pixel art with small pixels: **32 px per tile** (one tile ≈ one crop
          plot), crisp hard edges (no anti-aliased fringe; transparency is on or off, except soft
          effects like shadows and smoke), darker outlines where shapes need separation. Warm and
          cozy, not bouncy or childish.
        - **Palette:** saturated and punchy: fresh greens, golden wheat, warm browns, clear blues, from
          a limited set of colors per asset. The game tints the whole world for time of day and season.
        - **Format:** PNG with transparency, sRGB, drawn at 32 px per tile. The game scales art with
          nearest-neighbour (no smoothing), so pixels stay square. The pixel sizes listed below are
          what the placeholder painters paint at (\(Int(AssetSpec.pixelsPerTile)) px per tile), which
          the game then shrinks 4× onto the pixel grid: divide them by 4 for pixel art.
        - **Anchor:** the *foot point* (where the object touches the ground) sits horizontally
          centered, at the listed fraction of the height from the bottom edge.
        - **Directions:** unless noted, animals face left (mirrored in code). Vehicles have 16
          directions.

        ## Summary

        | Category | Assets | Needed in Phase 1 |
        |---|---:|---:|

        """
        for category in AssetSpec.Category.allCases {
            let specs = AssetManifest.all.filter { $0.category == category }
            let phase1 = specs.filter { $0.phase == 1 }.count
            out += "| \(category.title) | \(specs.count) | \(phase1) |\n"
        }
        out += "| **Total** | **\(AssetManifest.all.count)** | **\(AssetManifest.all.filter { $0.phase == 1 }.count)** |\n"
        out += "| Audio files | \(AudioManifest.all.count) | 0 |\n\n"

        for category in AssetSpec.Category.allCases {
            let specs = AssetManifest.all.filter { $0.category == category }
            guard !specs.isEmpty else { continue }
            out += "## \(category.title)\n\n"
            out += "| Name | Pixels | World size (tiles) | Anchor | Phase | Description |\n"
            out += "|---|---|---|---|---:|---|\n"
            for row in rows(for: specs) {
                out += row + "\n"
            }
            out += "\n"
        }

        out += "## Audio\n\n"
        for kind in AudioSpec.Kind.allCases {
            out += "### \(kind.title)\n\n| Name | Loop | Length | Phase | Description |\n|---|---|---|---:|---|\n"
            for spec in AudioManifest.all where spec.kind == kind {
                out += "| `\(spec.name)` | \(spec.loops ? "yes" : "no") | \(spec.duration) | \(spec.phase) | \(spec.notes) |\n"
            }
            out += "\n"
        }
        return out
    }

    /// Table rows; frames of the same family with identical sizes collapse into one row.
    private static func rows(for specs: [AssetSpec]) -> [String] {
        var result: [String] = []
        var i = 0
        while i < specs.count {
            let spec = specs[i]
            // Collapse long runs (directional frames) into one row.
            if let family = spec.family, spec.category == .vehicle {
                var j = i
                while j + 1 < specs.count, specs[j + 1].family == family { j += 1 }
                if j > i {
                    let names = "`\(spec.name)` … `\(specs[j].name)` (\(j - i + 1) frames)"
                    let phases = Set(specs[i...j].map(\.phase))
                    let phaseText = phases.count == 1 ? "\(spec.phase)" : "\(phases.min()!)–\(phases.max()!)"
                    let notes = spec.notes.components(separatedBy: " Facing").first ?? spec.notes
                    result.append(row(names: names, spec: spec, phase: phaseText,
                                      notes: notes + " 16 directions, 22.5° apart; frame 00 faces east, counter-clockwise (04 = away from camera, 08 = west, 12 = toward camera)."))
                    i = j + 1
                    continue
                }
            }
            result.append(row(names: "`\(spec.name)`", spec: spec, phase: "\(spec.phase)", notes: spec.notes))
            i += 1
        }
        return result
    }

    private static func row(names: String, spec: AssetSpec, phase: String, notes: String) -> String {
        let world = spec.layer == .ui ? "UI" : "\(format(spec.tilesWide)) × \(format(spec.tilesHigh))"
        let anchor = spec.layer == .standing ? format(spec.anchorY) : "—"
        let flags: String
        switch spec.layer {
        case .tileable: flags = " *(seamless)*"
        case .flat: flags = " *(flat)*"
        case .light: flags = " *(additive light)*"
        default: flags = ""
        }
        return "| \(names) | \(spec.pixelWidth) × \(spec.pixelHeight) | \(world) | \(anchor) | \(phase) | \(notes)\(flags) |"
    }

    private static func format(_ value: Double) -> String {
        if value == value.rounded() { return String(Int(value)) }
        let text = String((value * 100).rounded() / 100)
        return text
    }
}
