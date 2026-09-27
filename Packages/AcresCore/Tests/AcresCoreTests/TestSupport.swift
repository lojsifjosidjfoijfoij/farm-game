import Foundation
@testable import AcresCore

/// Test helpers: put the farmer where a job happens, the way the app walks them there.
extension Simulation {
    /// The farmer stands at a spot, on foot, fully rested.
    mutating func stand(at spot: Vec2) {
        let energy = balance.energyMax
        modify { state in
            state.farmer.inTruck = false
            state.farmer.position = spot
            state.farmer.energy = energy
        }
    }

    /// Walks over to a tile and does a field job.
    @discardableResult
    mutating func work(_ action: FarmAction, at tile: TileCoord, on map: WorldMap) -> FarmResult {
        stand(at: tile.center)
        return perform(action, at: tile, on: map)
    }

    /// Walks to a pen's gate and works it.
    @discardableResult
    mutating func work(_ action: PenAction, on pen: PenDefinition) -> RanchResult {
        stand(at: Ranching.workSpot(pen))
        return perform(action, on: pen)
    }

    /// Walks up to a tree (or the plowed tile, to plant) and works it.
    @discardableResult
    mutating func work(_ action: TreeAction, at tile: TileCoord, on map: WorldMap) -> TreeResult {
        if case .plant = action {
            stand(at: tile.center)
        } else {
            stand(at: Forestry(map: map, balance: balance).workSpot(for: tile, in: state))
        }
        return perform(action, at: tile, on: map)
    }

    /// Drives to a shop zone during opening hours (farmer in the truck).
    mutating func visit(_ zone: TileRect) {
        modify { state in
            state.truck.position = zone.center
            state.farmer.inTruck = true
            if !(9..<16).contains(state.clock.hour) {
                state.clock = GameClock(dayIndex: state.clock.dayIndex + (state.clock.hour >= 16 ? 1 : 0), hour: 10)
            }
        }
    }

    /// Back home: truck in the yard, farmer out of it.
    mutating func goHome() {
        modify { state in
            state.truck.position = HomeValleyMap.truckParkingSpot
            state.farmer.inTruck = false
            state.farmer.position = HomeValleyMap.farmhouseDoor
        }
    }
}
