import Foundation

/// What the driver wants: a direction on the map and how hard to push.
public struct DriveInput: Equatable, Sendable {
    /// Desired direction of travel (tile units, any length; zero = none).
    public var direction: Vec2
    /// 0…1 (joystick distance from center).
    public var throttle: Double

    public init(direction: Vec2, throttle: Double) {
        self.direction = direction
        self.throttle = throttle
    }

    public static let idle = DriveInput(direction: .zero, throttle: 0)
}

/// Motion that only exists while driving (not saved: a saved truck is parked).
public struct TruckMotion: Equatable, Sendable {
    /// Speed along the truck's nose, tiles per second (never negative).
    public var speed: Double = 0
    /// Actual velocity, lagging the nose on loose surfaces (that's the drift).
    public var velocity: Vec2 = .zero

    public init() {}

    public var isStopped: Bool { speed < 0.3 && velocity.length < 0.3 }
}

/// Feedback from a physics step, for haptics and messages.
public enum DriveEvent: Equatable, Sendable {
    /// Hit something at this speed (tiles/s).
    case bump(speed: Double)
    case ranOutOfFuel
}

/// Simple, satisfying arcade handling: push the stick toward where you want to
/// go and the truck swings its nose around and drives there. Faster on asphalt,
/// a little drift on gravel and dirt, bumps off trees and buildings.
public struct TruckPhysics: Sendable {
    public let map: WorldMap
    public let tuning: DrivingTuning

    /// Trees as the player changed them (chopped, cleared, planted).
    public let woodland: Woodland
    public let built: Set<TileCoord>
    /// Brush the truck can't drive through (see `WildLand`).
    public let wild: WildLand

    public init(map: WorldMap, tuning: DrivingTuning, woodland: Woodland = Woodland(), built: Set<TileCoord> = [],
                wild: WildLand = .none) {
        self.built = built
        self.map = map
        self.woodland = woodland
        self.tuning = tuning
        self.wild = wild
    }

    var obstacles: Obstacles { Obstacles(map: map, woodland: woodland, built: built, wild: wild) }

    public func surface(at position: Vec2) -> Terrain {
        map.terrain(at: TileCoord(containing: position))
    }

    @discardableResult
    public func step(_ truck: inout TruckState, _ motion: inout TruckMotion, input: DriveInput, dt rawDT: Double) -> [DriveEvent] {
        let dt = min(max(rawDT, 0), 0.1)
        guard dt > 0 else { return [] }
        var events: [DriveEvent] = []
        let terrain = surface(at: truck.position)
        var topSpeed = tuning.maxSpeed(on: terrain)
        if truck.fuel <= 0 { topSpeed *= tuning.outOfFuelSpeedFactor }

        let wantsToMove = input.throttle > 0.05 && input.direction.length > 1e-6
        if wantsToMove {
            let target = atan2(input.direction.y, input.direction.x)
            let diff = Self.angleDifference(target, truck.heading)
            // Turning is quicker when rolling, but possible from standstill.
            let turnRate = tuning.turnRate * (0.4 + 0.6 * min(1, motion.speed / 2))
            let maxTurn = turnRate * dt
            truck.heading = Self.normalize(truck.heading + min(max(diff, -maxTurn), maxTurn))
            // Ease off while swinging around a sharp turn.
            let alignment = max(0, cos(diff))
            let targetSpeed = topSpeed * min(1, input.throttle) * (0.3 + 0.7 * alignment)
            if motion.speed < targetSpeed {
                motion.speed = min(targetSpeed, motion.speed + tuning.acceleration * dt)
            } else {
                motion.speed = max(targetSpeed, motion.speed - tuning.braking * dt)
            }
        } else {
            motion.speed = max(0, motion.speed - tuning.coastDrag * dt)
        }

        // Velocity chases the nose; low grip = the rear slides a bit.
        let forward = Vec2(cos(truck.heading), sin(truck.heading))
        let desired = forward * motion.speed
        let grip = min(1, tuning.grip(on: terrain) * dt)
        motion.velocity = motion.velocity + (desired - motion.velocity) * grip
        if motion.speed == 0 && motion.velocity.length < 0.05 { motion.velocity = .zero }

        // Move, sliding along obstacles when possible.
        let start = truck.position
        let delta = motion.velocity * dt
        let next = start + delta
        // A truck that starts inside an obstacle (e.g. the map changed) may drive out freely.
        let ignoreCollisions = collides(start)
        if ignoreCollisions || !collides(next) {
            truck.position = next
        } else if !collides(Vec2(next.x, start.y)) {
            truck.position = Vec2(next.x, start.y)
            motion.velocity.y = 0
            motion.speed *= 0.8
        } else if !collides(Vec2(start.x, next.y)) {
            truck.position = Vec2(start.x, next.y)
            motion.velocity.x = 0
            motion.speed *= 0.8
        } else {
            if motion.speed > 2 { events.append(.bump(speed: motion.speed)) }
            motion.speed = 0
            motion.velocity = .zero
        }

        // Fuel.
        let moved = truck.position.distance(to: start)
        if truck.fuel > 0 && moved > 0 {
            truck.fuel = max(0, truck.fuel - moved * tuning.fuelPerTile)
            if truck.fuel == 0 { events.append(.ranOutOfFuel) }
        }
        return events
    }

    /// True if the truck's collision circle at `p` touches an obstacle or the map edge.
    public func collides(_ p: Vec2) -> Bool {
        let r = tuning.collisionRadius
        if p.x - r < 0 || p.y - r < 0 || p.x + r > Double(map.width) || p.y + r > Double(map.height) { return true }
        let x0 = Int((p.x - r).rounded(.down)), x1 = Int((p.x + r).rounded(.down))
        let y0 = Int((p.y - r).rounded(.down)), y1 = Int((p.y + r).rounded(.down))
        for ty in y0...y1 {
            for tx in x0...x1 where obstacles.isBlocked(TileCoord(tx, ty)) {
                let cx = min(max(p.x, Double(tx)), Double(tx + 1))
                let cy = min(max(p.y, Double(ty)), Double(ty + 1))
                let dx = p.x - cx, dy = p.y - cy
                if dx * dx + dy * dy < r * r { return true }
            }
        }
        return false
    }

    /// Smallest signed angle from `b` to `a`, in (-π, π].
    public static func angleDifference(_ a: Double, _ b: Double) -> Double {
        var d = (a - b).truncatingRemainder(dividingBy: 2 * .pi)
        if d > .pi { d -= 2 * .pi }
        if d <= -.pi { d += 2 * .pi }
        return d
    }

    /// Angle in [0, 2π).
    public static func normalize(_ angle: Double) -> Double {
        let a = angle.truncatingRemainder(dividingBy: 2 * .pi)
        return a < 0 ? a + 2 * .pi : a
    }

    /// Which of 16 sprite directions a heading uses (0 = east, counter-clockwise).
    public static func directionIndex(for heading: Double) -> Int {
        Int((normalize(heading) / (2 * .pi / 16)).rounded()) % 16
    }
}
