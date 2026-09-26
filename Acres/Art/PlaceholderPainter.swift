import UIKit
import AcresCore

/// Draws procedural placeholder art for any asset in the manifest that has a
/// painter. Deterministic: the same name always produces the same image.
enum PlaceholderPainter {

    static func paint(_ name: String) -> UIImage? {
        guard let spec = AssetManifest.spec(named: name) else { return nil }
        var rng = SeededRandom(seed: SeededRandom.stableHash(name))
        let size = CGSize(width: spec.pixelWidth, height: spec.pixelHeight)
        switch spec.category {
        case .terrain: return TerrainPainter.paint(name, size: size, rng: &rng)
        case .tree: return TreePainter.paint(spec, rng: &rng)
        case .nature, .prop: return PropPainter.paint(spec, rng: &rng)
        case .building: return BuildingPainter.paint(spec, rng: &rng)
        case .vehicle: return VehiclePainter.paint(spec, rng: &rng)
        case .effect: return EffectPainter.paint(spec, rng: &rng)
        case .field, .crop, .animal, .item, .ui: return nil  // arrive in later phases
        }
    }

    /// Obvious magenta checkerboard for assets that have neither art nor a painter.
    static func missing(size: CGSize) -> UIImage {
        let side = max(16, min(size.width, size.height) / 4)
        return Canvas.image(size) { ctx in
            for y in stride(from: CGFloat(0), to: size.height, by: side) {
                for x in stride(from: CGFloat(0), to: size.width, by: side) {
                    let even = (Int(x / side) + Int(y / side)) % 2 == 0
                    ctx.setFillColor((even ? UIColor.magenta : UIColor.black).withAlpha(0.8).cgColor)
                    ctx.fill(CGRect(x: x, y: y, width: side, height: side))
                }
            }
        }
    }
}
