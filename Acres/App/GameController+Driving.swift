import CoreGraphics
import Foundation
import AcresCore

/// A place to drive to from the map menu (like a GPS).
struct Destination: Identifiable, Equatable {
    let id: String
    let name: String
    let symbol: String
    let target: Vec2
}

extension GameController {
    var physics: TruckPhysics { TruckPhysics(map: map, tuning: balance.driving, woodland: simulation.state.woodland) }
    var truckState: TruckState { simulation.state.truck }
    var truckSurface: Terrain { physics.surface(at: simulation.state.truck.position) }
    var cargoFraction: Double { Double(cargoCount) / Double(max(1, balance.truckCargoCapacity)) }

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
        refreshFarmer()
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
        guard let path = Pathfinder.path(on: map, woodland: simulation.state.woodland,
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
            let symbol = switch shop.kind {
            case .market: "basket.fill"
            case .seedShop: "leaf.fill"
            case .gasStation: "fuelpump.fill"
            case .livestock: "hare.fill"
            }
            result.append(Destination(id: shop.id, name: shop.name, symbol: symbol, target: shop.zone.center))
        }
        return result
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
        let stopped = !isDriving || motion.isStopped
        let here = simulation.state.farmerPosition
        let shop = stopped ? ShopCatalog.all.first { $0.zone.insetBy(-1).contains(here) } : nil
        if shop != nearbyShop {
            nearbyShop = shop
            if shop?.kind == .market { advanceTutorial(.arrivedAtMarket) }
        }
        let atFarm = trading.truckIsAtFarm(simulation.state)
        if atFarm != truckAtFarm { truckAtFarm = atFarm }
    }
}
