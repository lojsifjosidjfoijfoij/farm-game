import SpriteKit
import UIKit
import AcresCore

/// The single entry point for every visual in the game.
///
/// Lookup order for a name like `tree_oak_summer`:
/// 1. A real image with that name in `Assets.xcassets` (drop-in art).
/// 2. Procedural placeholder art from `PlaceholderPainter`.
/// 3. A magenta checkerboard, and a console warning, so gaps are obvious.
///
/// Textures are created once and cached for the lifetime of the app.
@MainActor
final class AssetCatalog {
    static let shared = AssetCatalog()

    private var textures: [String: SKTexture] = [:]
    private var warnedMissing = Set<String>()

    func texture(_ name: String) -> SKTexture {
        if let cached = textures[name] { return cached }
        let texture = SKTexture(image: image(name))
        texture.filteringMode = .linear
        textures[name] = texture
        return texture
    }

    /// Uncached image lookup (real art → placeholder → missing marker).
    func image(_ name: String) -> UIImage {
        if let art = UIImage(named: name) { return art }
        if let placeholder = PlaceholderPainter.paint(name) { return placeholder }
        if warnedMissing.insert(name).inserted {
            print("⚠️ AssetCatalog: no art and no placeholder painter for '\(name)'")
        }
        let spec = AssetManifest.spec(named: name)
        let size = CGSize(width: spec?.pixelWidth ?? 64, height: spec?.pixelHeight ?? 64)
        return PlaceholderPainter.missing(size: size)
    }

    /// World size of an asset in points (from the manifest), or nil if unknown.
    func worldSize(_ name: String) -> CGSize? {
        guard let spec = AssetManifest.spec(named: name) else { return nil }
        return CGSize(width: CGFloat(spec.tilesWide) * World.tileSize, height: CGFloat(spec.tilesHigh) * World.tileSize)
    }

    /// Creates textures ahead of time so the first frames don't stutter.
    func preload(_ names: [String]) {
        for name in names { _ = texture(name) }
    }
}
