import CoreGraphics
import Foundation
import AcresCore

/// A place to drive to from the map menu (like a GPS).
struct Destination: Identifiable, Equatable {
    let id: String
    let name: String
    let symbol: String
    let target: Vec2
    /// Extra words for the menu ("order").
    var note: String? = nil

    var menuTitle: String { note.map { "\(name) · \($0)" } ?? name }
}

extension GameController {
    var physics: TruckPhysics {
        TruckPhysics(map: map, tuning: balance.driving, woodland: simulation.state.woodland, built: builtTiles, wild: wildLand)
    }
    var truckState: TruckState { simulation.state.truck }
    var truckSurface: Terrain { physics.surface(at: simulation.state.truck.position) }
    var cargoFraction: Double { Double(cargoCount) / Double(max(1, truckCapacity)) }

    // MARK: Getting in and out

    /// The farmer climbs in (they must be standing by the truck).
    func enterTruck() {
        guard !isDriving, welcome == nil else { return }
        endPaint()
        simulation.modify { $0.farmer.inTruck = true }
        isDriving = true
        motion = TruckMotion()
        cameraFollowPaused = false
        showsSeedPicker = false
        dismissInspection()
        Haptics.tap()
        Sound.play(.door, volume: 0.8)
        refreshFarmer()
        // There's no button for it, so say how, the first couple of drives each session.
        if truckHintsShown < 2 {
            truckHintsShown += 1
            showMessage("Tap where to go. Tap the truck to get out.")
        }
    }

    /// Stops the truck and the farmer steps out beside it.
    func park() {
        guard isDriving else { return }
        isDriving = false
        motion = TruckMotion()
        autopilot = nil
        destination = nil
        let spot = exitSpot()
        simulation.modify { state in
            state.farmer.inTruck = false
            state.farmer.position = spot
        }
        refreshTruck()
        refreshFarmer()
        save()
        Haptics.tap()
        Sound.play(.door, volume: 0.8)
    }

    /// Old saves: the farmer or the truck may stand where brush grows now
    /// (the home fields moved). Put them back in the yard.
    func rescueFromBrush() {
        let wild = wildLand
        simulation.modify { state in
            if wild.contains(TileCoord(containing: state.truck.position)) {
                state.truck.position = HomeValleyMap.truckParkingSpot
            }
            if !state.farmer.inTruck, wild.contains(TileCoord(containing: state.farmer.position)) {
                state.farmer.position = HomeValleyMap.farmhouseDoor
            }
        }
    }

    /// A free spot next to the truck for the farmer to step out onto.
    private func exitSpot() -> Vec2 {
        let truck = simulation.state.truck
        let obstacles = Obstacles(map: map, state: simulation.state)
        // Driver's side first, then the other side, then behind and in front.
        let side = truck.heading + .pi / 2
        let candidates = [side, side + .pi, truck.heading + .pi, truck.heading].map { angle in
            Vec2(truck.position.x + cos(angle) * 1.1, truck.position.y + sin(angle) * 1.1)
        }
        return candidates.first { spot in
            let tile = TileCoord(containing: spot)
            return map.isInside(tile) && !obstacles.isBlocked(tile)
        } ?? truck.position
    }

    // MARK: Driving by tapping

    /// Plans a route to a spot and lets the autopilot take the wheel.
    func driveTo(_ target: Vec2) {
        guard isDriving else { return }
        guard let path = Pathfinder.path(on: map, woodland: simulation.state.woodland, built: builtTiles, wild: wildLand,
                                         from: simulation.state.truck.position, to: target) else {
            showMessage("Can't find a way there.")
            return
        }
        autopilot = Autopilot(path: path)
        destination = path.last
        cameraFollowPaused = false
        Haptics.selection()
    }

    /// Places the map menu offers (the GPS).
    var destinations: [Destination] {
        var result = [Destination(id: "home", name: "Home farm", symbol: "house.fill", target: HomeValleyMap.truckParkingSpot)]
        for shop in ShopCatalog.all {
            result.append(Destination(id: shop.id, name: shop.name, symbol: Self.symbol(for: shop.kind), target: shop.zone.center))
        }
        let store = StoreDefinition.corner
        result.append(Destination(id: store.id, name: storeState.isRented ? "Your shop" : store.name, symbol: "storefront.fill",
                                  target: store.zone.center, note: storeState.isRented ? nil : "for rent"))
        // Clients with orders on, then the rest.
        let busy = Set(contractBoard.active.map(\.clientID))
        for client in ClientCatalog.all.sorted(by: { busy.contains($0.id) && !busy.contains($1.id) }) {
            result.append(Destination(id: client.id, name: client.name, symbol: Self.symbol(for: client), target: client.zone.center,
                                      note: busy.contains(client.id) ? "order" : nil))
        }
        // The outdoors (Phase 11).
        result.append(Destination(id: "willow_lake", name: "Willow Lake", symbol: "fish.fill", target: Vec2(101.4, 13.2),
                                  note: "fishing"))
        result.append(Destination(id: "goat_hill", name: "Goat Hill", symbol: "mountain.2.fill", target: Vec2(56.6, 50.4),
                                  note: ownedLand.contains("goat_hill") ? nil : "for sale"))
        return result
    }

    static func symbol(for kind: ShopKind) -> String {
        switch kind {
        case .market: "basket.fill"
        case .seedShop: "leaf.fill"
        case .gasStation: "fuelpump.fill"
        case .livestock: "hare.fill"
        case .bank: "building.columns.fill"
        }
    }

    func drive(to destination: Destination) {
        driveTo(destination.target)
        showMessage("Driving to \(destination.name).")
    }

    // MARK: Per frame

    func updateDriving(dt: TimeInterval) {
        guard isDriving else { return }
        var input = DriveInput.idle
        if var pilot = autopilot {
            if let next = pilot.input(for: simulation.state.truck) {
                input = next
                autopilot = pilot
            } else {
                autopilot = nil
                destination = nil
            }
        }
        var truck = simulation.state.truck
        let events = physics.step(&truck, &motion, input: input, dt: dt)
        let moved = truck
        simulation.modify { $0.truck = moved }
        for event in events {
            switch event {
            case .bump(let speed):
                Haptics.bump(intensity: min(1, speed / balance.driving.maxSpeedAsphalt))
                autopilot = nil
                destination = nil
            case .ranOutOfFuel:
                showMessage("Out of fuel! The truck limps along. Fill up at the village gas station.")
            }
        }
        refreshTruck()
    }

    /// Copies truck values the HUD shows (only when they change).
    func refreshTruck() {
        let truck = simulation.state.truck
        let fraction = max(0, min(1, truck.fuel / balance.driving.fuelCapacity))
        if abs(fraction - fuelFraction) >= 0.005 || (fraction == 0 && fuelFraction != 0) { fuelFraction = fraction }
        if cargoItems != truck.cargo.items {
            cargoItems = truck.cargo.items
            cargoCount = truck.cargoCount
        }
        let bag = simulation.state.farmer.bag
        if bagItems != bag.items {
            bagItems = bag.items
            bagCount = simulation.state.farmer.bagCount
        }
        let onFarm = trading.isOnFarm(simulation.state)
        if onFarm != farmerOnFarm { farmerOnFarm = onFarm }
        let stopped = !isDriving || motion.isStopped
        let here = simulation.state.farmerPosition
        let place = stopped ? Place.near(here) : nil
        let shop = place?.shop
        if shop != nearbyShop {
            nearbyShop = shop
            if shop?.kind == .market { advanceTutorial(.arrivedAtMarket) }
        }
        let client = place?.client
        if client != nearbyClient { nearbyClient = client }
        let store = place?.store
        if store != nearbyStore { nearbyStore = store }
        let atFarm = trading.truckIsAtFarm(simulation.state)
        if atFarm != truckAtFarm {
            truckAtFarm = atFarm
            if atFarm { advanceTutorial(.arrivedHome) }
        }
    }
}
