import Foundation

/// Metadata for one visual asset: its name, how big it is in the world, the
/// recommended pixel size for real art, and what it should look like.
///
/// The game requests every visual by `name`. At runtime the app looks for a
/// real image with that name in the asset catalog first and only falls back to
/// procedurally-drawn placeholder art when none exists. So replacing
/// placeholder art = dropping in a PNG with the right name. No code changes.
public struct AssetSpec: Hashable, Sendable {
    public enum Category: String, CaseIterable, Sendable {
        case terrain, field, crop, tree, nature, building, prop, vehicle, animal, item, effect, ui

        public var title: String {
            switch self {
            case .terrain: "Terrain (tileable ground textures)"
            case .field: "Fields"
            case .crop: "Crops"
            case .tree: "Trees"
            case .nature: "Nature props"
            case .building: "Buildings"
            case .prop: "Props"
            case .vehicle: "Vehicles"
            case .animal: "Animals"
            case .item: "Item icons"
            case .effect: "Effects & particles"
            case .ui: "User interface"
            }
        }
    }

    /// How the sprite sits in the world.
    public enum Layer: String, Sendable {
        /// Seamless texture repeated across the ground.
        case tileable
        /// Lies flat on the ground (drawn under everything standing).
        case flat
        /// Stands up; depth-sorted by its foot point (3/4 view).
        case standing
        /// Additive light / glow drawn on top at night.
        case light
        /// Particle or effect sprite.
        case particle
        /// Screen-space UI.
        case ui
    }

    /// Unique snake_case name, e.g. `crop_wheat_stage3`.
    public let name: String
    public let category: Category
    public let layer: Layer
    /// Size in the world, in tiles (1 tile = 64 world points). 0 for UI.
    public let tilesWide: Double
    public let tilesHigh: Double
    /// Recommended pixel size for real art.
    public let pixelWidth: Int
    public let pixelHeight: Int
    /// Vertical position of the foot point as a fraction of the height from the
    /// bottom (0 = bottom edge). Horizontal anchor is always the center.
    public let anchorY: Double
    /// Width of the soft contact shadow in tiles (0 = none).
    public let shadowWidth: Double
    /// Phase in which the game first needs this asset.
    public let phase: Int
    /// Art direction for this asset.
    public let notes: String
    /// Frames of one animation or direction set share a family (docs group them).
    public let family: String?

    public init(
        name: String, category: Category, layer: Layer,
        tilesWide: Double, tilesHigh: Double,
        pixelWidth: Int, pixelHeight: Int,
        anchorY: Double, shadowWidth: Double,
        phase: Int, notes: String, family: String? = nil
    ) {
        self.name = name
        self.category = category
        self.layer = layer
        self.tilesWide = tilesWide
        self.tilesHigh = tilesHigh
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.anchorY = anchorY
        self.shadowWidth = shadowWidth
        self.phase = phase
        self.notes = notes
        self.family = family
    }

    /// Recommended art resolution for world sprites.
    public static let pixelsPerTile: Double = 128

    /// A world sprite sized in tiles; pixel size is derived.
    public static func sprite(
        _ name: String, _ category: Category, tiles w: Double, _ h: Double,
        layer: Layer = .standing, anchorY: Double = 0.08, shadow: Double = 0,
        phase: Int, family: String? = nil, _ notes: String
    ) -> AssetSpec {
        AssetSpec(
            name: name, category: category, layer: layer,
            tilesWide: w, tilesHigh: h,
            pixelWidth: Int((w * pixelsPerTile).rounded()), pixelHeight: Int((h * pixelsPerTile).rounded()),
            anchorY: anchorY, shadowWidth: shadow, phase: phase, notes: notes, family: family)
    }

    /// A seamless ground texture covering `tiles` × `tiles` tiles.
    public static func tileable(
        _ name: String, tiles: Double, pixels: Int, phase: Int, _ notes: String
    ) -> AssetSpec {
        AssetSpec(
            name: name, category: .terrain, layer: .tileable,
            tilesWide: tiles, tilesHigh: tiles, pixelWidth: pixels, pixelHeight: pixels,
            anchorY: 0, shadowWidth: 0, phase: phase, notes: notes)
    }

    /// A UI image sized in points (@3x pixels are derived).
    public static func ui(
        _ name: String, _ category: Category = .ui, points w: Double, _ h: Double,
        phase: Int, _ notes: String
    ) -> AssetSpec {
        AssetSpec(
            name: name, category: category, layer: .ui,
            tilesWide: 0, tilesHigh: 0,
            pixelWidth: Int(w * 3), pixelHeight: Int(h * 3),
            anchorY: 0.5, shadowWidth: 0, phase: phase, notes: notes)
    }
}
