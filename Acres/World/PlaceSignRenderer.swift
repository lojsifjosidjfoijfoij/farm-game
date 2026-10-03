import SpriteKit
import SwiftUI
import AcresCore

/// A name plaque over every place you can drive to in the village and up the
/// county road: the shops, your corner shop and the customers. The same paper
/// in a wooden frame as the menus, with the place's icon (the one the drive
/// menu uses), so a glance tells you which is which. They stay readable at
/// night, like the HUD.
@MainActor
final class PlaceSignRenderer {
    private struct Sign {
        let kind: String
        /// Which of several objects of that kind (the market's middle stall).
        var variant: Int? = nil
        let symbol: String
        let name: (GameController) -> String
    }

    private static let signs: [Sign] = [
        Sign(kind: "building_gas_station", symbol: GameController.symbol(for: .gasStation)) { _ in shop(.gasStation) },
        Sign(kind: "building_seed_shop", symbol: GameController.symbol(for: .seedShop)) { _ in shop(.seedShop) },
        Sign(kind: "building_farmers_market_stall", variant: 1, symbol: GameController.symbol(for: .market)) { _ in shop(.market) },
        Sign(kind: "building_livestock_market", symbol: GameController.symbol(for: .livestock)) { _ in shop(.livestock) },
        Sign(kind: "building_bank", symbol: GameController.symbol(for: .bank)) { _ in shop(.bank) },
        Sign(kind: "building_town_shop", symbol: "storefront.fill") { game in
            game.storeState.isRented ? "Your shop" : "\(StoreDefinition.corner.name) · for rent"
        },
        Sign(kind: "building_restaurant", symbol: client("rusty_spoon").symbol) { _ in client("rusty_spoon").name },
        Sign(kind: "building_bakery", symbol: client("hansens_bakery").symbol) { _ in client("hansens_bakery").name },
        Sign(kind: "building_lumber_yard", symbol: client("lumber_yard").symbol) { _ in client("lumber_yard").name },
        Sign(kind: "building_deli", symbol: client("valley_deli").symbol) { _ in client("valley_deli").name },
    ]

    private static func shop(_ kind: ShopKind) -> String { ShopCatalog.first(kind)?.name ?? "" }

    private static func client(_ id: String) -> (name: String, symbol: String) {
        guard let client = ClientCatalog.all.first(where: { $0.id == id }) else { return ("", "shippingbox.fill") }
        return (client.name, GameController.symbol(for: client))
    }

    /// World points per point of the plaque: at the default zoom it reads at
    /// its design size on screen.
    private static let worldScale: CGFloat = 1.6

    private let layer: SKNode
    private let map: WorldMap
    private var nodes: [Int: SKSpriteNode] = [:]
    private var shownNames: [Int: String] = [:]

    init(layer: SKNode, map: WorldMap) {
        self.layer = layer
        self.map = map
    }

    /// Puts up the plaques, and repaints one whose name changed (the corner shop, once rented).
    func sync(game: GameController) {
        for (index, sign) in Self.signs.enumerated() {
            let name = sign.name(game)
            guard shownNames[index] != name else { continue }
            shownNames[index] = name
            nodes[index]?.removeFromParent()
            guard let anchor = anchor(for: sign), let plaque = Self.plaque(name: name, symbol: sign.symbol) else { continue }
            let node = SKSpriteNode(texture: plaque.texture)
            node.size = CGSize(width: plaque.size.width * Self.worldScale, height: plaque.size.height * Self.worldScale)
            node.anchorPoint = CGPoint(x: 0.5, y: 0)
            node.position = World.point(anchor)
            // Above the day/night grade (like the HUD), below the night lights.
            node.zPosition = ZLayer.lightingOverlay + 20
            layer.addChild(node)
            nodes[index] = node
        }
    }

    /// Just above the building's roof.
    private func anchor(for sign: Sign) -> Vec2? {
        let matches = map.objects.filter { $0.kind == sign.kind }
        guard let object = sign.variant.flatMap({ v in matches.first { $0.variant == v } }) ?? matches.first,
              let spec = AssetManifest.spec(named: sign.kind) else { return nil }
        return Vec2(object.position.x, object.position.y + spec.tilesHigh * (1 - spec.anchorY) - 0.35)
    }

    /// The plaque, drawn by SwiftUI in the menus' style and turned into a texture.
    private static func plaque(name: String, symbol: String) -> (texture: SKTexture, size: CGSize)? {
        let view = HStack(spacing: 5) {
            MenuIcon(symbol: symbol, size: 20)
            Text(name)
                .font(HUD.font(15, .black))
                .foregroundStyle(HUD.text)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(PixelFrame(.panel))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        guard let image = renderer.uiImage else { return nil }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return (texture, image.size)
    }
}
