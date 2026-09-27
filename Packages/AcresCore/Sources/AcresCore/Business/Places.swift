import Foundation

/// Somewhere in the valley the truck stops to do business: a shop, or a
/// client that takes deliveries.
public enum Place: Equatable, Sendable {
    case shop(ShopDefinition)
    case client(ClientDefinition)

    public var id: String {
        switch self {
        case .shop(let shop): shop.id
        case .client(let client): client.id
        }
    }

    public var name: String {
        switch self {
        case .shop(let shop): shop.name
        case .client(let client): client.name
        }
    }

    /// Where the truck stops (tile units).
    public var zone: TileRect {
        switch self {
        case .shop(let shop): shop.zone
        case .client(let client): client.zone
        }
    }

    public var shop: ShopDefinition? {
        if case .shop(let shop) = self { shop } else { nil }
    }

    public var client: ClientDefinition? {
        if case .client(let client) = self { client } else { nil }
    }

    public static var all: [Place] { ShopCatalog.all.map(Place.shop) + ClientCatalog.all.map(Place.client) }

    /// The place whose stopping zone is at (or within `margin` tiles of) a
    /// spot. Where margins overlap, the closest zone wins.
    public static func near(_ position: Vec2, margin: Double = 1) -> Place? {
        all.filter { $0.zone.insetBy(-margin).contains(position) }
            .min { $0.zone.distance(to: position) < $1.zone.distance(to: position) }
    }
}
