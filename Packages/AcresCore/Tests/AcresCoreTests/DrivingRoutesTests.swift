import XCTest
@testable import AcresCore

/// The quick-drive routes: the autopilot gets everywhere from the farm, on the
/// roads, without bumping into anything.
final class DrivingRoutesTests: XCTestCase {
    let map = HomeValleyMap.map
    let tuning = Balance.standard.driving

    /// Every place the drive menu offers (its targets, as the app has them).
    static let destinations: [(String, Vec2)] = {
        var result: [(String, Vec2)] = [("home", HomeValleyMap.truckParkingSpot)]
        result += ShopCatalog.all.map { ($0.name, $0.zone.center) }
        result.append(("corner shop", StoreDefinition.corner.zone.center))
        result += ClientCatalog.all.map { ($0.name, $0.zone.center) }
        result += [("Willow Lake", Vec2(101.4, 13.2)), ("Goat Hill", Vec2(56.6, 50.4))]
        return result
    }()

    struct Trip { var arrived: Bool; var seconds: Double; var bumps: Int; var waypoints: Int; var end: Vec2 }

    func drive(_ path: [Vec2], from start: Vec2, physics: TruckPhysics, to goal: Vec2) -> Trip {
        var truck = TruckState(position: start, heading: .pi / 2)
        var motion = TruckMotion()
        var pilot = Autopilot(path: path, from: start)
        var seconds = 0.0
        var bumps = 0
        while let input = pilot.input(for: truck), seconds < 180 {
            for event in physics.step(&truck, &motion, input: input, dt: 1.0 / 30) {
                if case .bump = event { bumps += 1 }
            }
            seconds += 1.0 / 30
        }
        return Trip(arrived: truck.position.distance(to: path.last!) < 1, seconds: seconds, bumps: bumps,
                    waypoints: path.count, end: truck.position)
    }

    func testTheAutopilotGetsEverywhereWithoutABump() {
        let physics = TruckPhysics(map: map, tuning: tuning)
        let obstacles = DrivingObstacles(map: map)
        let starts = [("the farm", HomeValleyMap.truckParkingSpot), ("the market", HomeValleyMap.marketZone.center),
                      ("the bakery", HomeValleyMap.bakeryZone.center)]
        for (from, start) in starts {
            for (name, goal) in Self.destinations where goal.distance(to: start) > 2 {
                guard let path = Pathfinder.drivingRoute(on: obstacles, from: start, to: goal) else {
                    XCTFail("no route from \(from) to \(name)")
                    continue
                }
                let trip = drive(path, from: start, physics: physics, to: goal)
                XCTAssertTrue(trip.arrived, "\(from) → \(name): stopped at \(trip.end)")
                XCTAssertEqual(trip.bumps, 0, "\(from) → \(name) bumps into something")
                XCTAssertLessThan(trip.seconds, 45, "\(from) → \(name) takes \(Int(trip.seconds)) s")
                XCTAssertLessThan(trip.end.distance(to: goal), 1.5, "\(from) → \(name) ends where it should")
            }
        }
    }

    func testRoutesStayOnTheRoad() {
        // Farm to market: out of the gate, along the road; never across the meadow.
        let obstacles = DrivingObstacles(map: map)
        let path = Pathfinder.drivingRoute(on: obstacles, from: HomeValleyMap.truckParkingSpot, to: HomeValleyMap.marketZone.center)!
        var points = [HomeValleyMap.truckParkingSpot] + path
        var grass = 0.0, total = 0.0
        for (a, b) in zip(points, points.dropFirst()) {
            let steps = max(1, Int(a.distance(to: b) / 0.25))
            for i in 0..<steps {
                let p = a + (b - a) * (Double(i) / Double(steps))
                total += 0.25
                if map.terrain(at: TileCoord(containing: p)) == .grass { grass += 0.25 }
            }
        }
        points.removeAll()
        XCTAssertLessThan(grass / total, 0.1, "mostly road")
        XCTAssertLessThan(path.count, 10, "a handful of turns, not a zigzag")
    }

    func testFencesStopTheTruckButTreesAreJustTheirTrunks() {
        let physics = TruckPhysics(map: map, tuning: tuning)
        // The home farm's fence: rails along its edge.
        let fence = map.objects.first { $0.kind == "prop_fence_wood_h" }!
        XCTAssertTrue(physics.collides(fence.position + Vec2(0, 0.3)), "the truck can't straddle a fence")
        XCTAssertFalse(map.colliders.isEmpty)
        // Driving straight at a fence from inside the farm stops at it.
        var truck = TruckState(position: fence.position + Vec2(0, fence.position.y < 40 ? 2 : -2),
                               heading: fence.position.y < 40 ? -.pi / 2 : .pi / 2)
        var motion = TruckMotion()
        let direction = Vec2(0, fence.position.y < 40 ? -1 : 1)
        for _ in 0..<120 { physics.step(&truck, &motion, input: DriveInput(direction: direction, throttle: 1), dt: 1.0 / 30) }
        XCTAssertGreaterThan(abs(truck.position.y - fence.position.y), 0.4, "stopped at the rails")

        // A tree: you can pass within a tile of it.
        let tree = map.objects.first { $0.kind.hasPrefix("tree_oak") }!
        XCTAssertTrue(physics.collides(tree.position))
        XCTAssertFalse(physics.collides(tree.position + Vec2(0.75, 0)), "a trunk, not a whole tile")
        // Once it's cleared, it's gone.
        var woodland = Woodland()
        woodland.hiddenMapTrees.insert(TileCoord(containing: tree.position))
        let cleared = TruckPhysics(map: map, tuning: tuning, woodland: woodland)
        XCTAssertFalse(cleared.collides(tree.position))
    }
}
