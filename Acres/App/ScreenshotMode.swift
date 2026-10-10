import Foundation
import AcresCore

/// Launch options for screenshots of the real game in the Simulator (debug
/// builds only; `scripts/screenshots.sh` passes them):
///
///     -AcresShot <scene>    farm | title | finale | map | goals | bag
///                           journal:<tab> (orders, money, village, almanac…)
///                           shop:<kind> (seedShop, market, livestock…)
///     -AcresCamera <x,y>    where the camera looks, in tiles
///     -AcresTiles <n>       how many tiles fit the short side of the screen
///
/// A save loaded this way isn't fast-forwarded (no "while you were away") and
/// is never written back, so every shot starts from the same moment.
struct ScreenshotMode {
    let scene: String
    let camera: Vec2?
    let tilesAcross: Double?

    static let current: ScreenshotMode? = {
        #if DEBUG
        let defaults = UserDefaults.standard
        guard let scene = defaults.string(forKey: "AcresShot") else { return nil }
        let camera = defaults.string(forKey: "AcresCamera").flatMap { text -> Vec2? in
            let numbers = text.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            return numbers.count == 2 ? Vec2(numbers[0], numbers[1]) : nil
        }
        let tiles = defaults.object(forKey: "AcresTiles") == nil ? nil : defaults.double(forKey: "AcresTiles")
        return ScreenshotMode(scene: scene, camera: camera, tilesAcross: tiles)
        #else
        return nil
        #endif
    }()

    var showsTitle: Bool { scene == "title" }
}

extension GameController {
    /// Sets the stage for a screenshot: where the camera looks, and what's open.
    func setUpScreenshot(_ shot: ScreenshotMode) {
        if let camera = shot.camera { presentation.cameraCenter = camera }
        let parts = shot.scene.split(separator: ":").map(String.init)
        let detail = parts.count > 1 ? parts[1] : ""
        switch parts.first ?? "" {
        case "finale":
            rankUpCard = RankUpCard(rank: FarmRanks.finale, renovated: false)
        case "map":
            showsDriveMap = true
        case "goals":
            showsGoals = true
        case "bag":
            showsInventory = true
        case "journal":
            if let tab = BusinessTab.allCases.first(where: { "\($0)" == detail }) { businessTab = tab }
            showsBusiness = true
        case "shop":
            openShop = ShopKind(rawValue: detail).flatMap { ShopCatalog.first($0) }
        default:
            break
        }
    }
}
