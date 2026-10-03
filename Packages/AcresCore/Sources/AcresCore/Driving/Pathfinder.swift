import Foundation

/// A* route planning over the tile grid for tap-to-drive. Prefers roads:
/// asphalt is cheapest, grass most expensive, obstacles are impassable.
public enum Pathfinder {

    /// The farmer's walks: over whole tiles (what farming uses), round fences.
    /// Waypoints (tile units) from `start` to `goal`, or nil if unreachable.
    /// The first waypoint is the first step away from `start`; the last is `goal`
    /// (or the nearest reachable spot next to it).
    public static func path(on map: WorldMap, woodland: Woodland = Woodland(), built: Set<TileCoord> = [],
                            wild: WildLand = .none, from start: Vec2, to goal: Vec2) -> [Vec2]? {
        let width = map.width, height = map.height
        let obstacles = Obstacles(map: map, woodland: woodland, built: built, wild: wild)
        func index(_ t: TileCoord) -> Int { t.y * width + t.x }
        func passable(_ t: TileCoord) -> Bool { map.isInside(t) && !obstacles.isBlocked(t) }

        let startTile = TileCoord(containing: start)
        guard map.isInside(startTile) else { return nil }
        guard let goalTile = nearestPassable(to: TileCoord(containing: goal), obstacles: obstacles) else { return nil }
        if startTile == goalTile { return [goal] }

        var cost = [Double](repeating: .infinity, count: width * height)
        var cameFrom = [Int](repeating: -1, count: width * height)
        var closed = [Bool](repeating: false, count: width * height)
        var open = MinHeap()
        cost[index(startTile)] = 0
        open.push(index(startTile), priority: heuristic(startTile, goalTile))

        let neighbours: [(Int, Int, Double)] = [
            (1, 0, 1), (-1, 0, 1), (0, 1, 1), (0, -1, 1),
            (1, 1, 2.0.squareRoot()), (1, -1, 2.0.squareRoot()), (-1, 1, 2.0.squareRoot()), (-1, -1, 2.0.squareRoot()),
        ]
        var found = false
        while let current = open.pop() {
            if closed[current] { continue }
            closed[current] = true
            let tile = TileCoord(current % width, current / width)
            if tile == goalTile { found = true; break }
            for (dx, dy, step) in neighbours {
                let next = TileCoord(tile.x + dx, tile.y + dy)
                guard passable(next) || next == startTile else { continue }
                // No cutting corners past obstacles, and no climbing over fences.
                if dx != 0 && dy != 0 &&
                    (!passable(TileCoord(tile.x + dx, tile.y)) || !passable(TileCoord(tile.x, tile.y + dy))) { continue }
                if map.crossesFence(from: tile.center, to: next.center) { continue }
                let n = index(next)
                if closed[n] { continue }
                let newCost = cost[current] + step * terrainCost(map.terrain(at: next))
                if newCost < cost[n] {
                    cost[n] = newCost
                    cameFrom[n] = current
                    open.push(n, priority: newCost + heuristic(next, goalTile))
                }
            }
        }
        guard found else { return nil }

        var tiles: [TileCoord] = []
        var cursor = index(goalTile)
        while cursor != index(startTile) && cursor >= 0 {
            tiles.append(TileCoord(cursor % width, cursor / width))
            cursor = cameFrom[cursor]
        }
        tiles.reverse()

        // Drop waypoints in the middle of straight runs.
        var points: [Vec2] = []
        for (i, tile) in tiles.enumerated() {
            if i > 0 && i < tiles.count - 1 {
                let a = tiles[i - 1], b = tiles[i + 1]
                if tile.x - a.x == b.x - tile.x && tile.y - a.y == b.y - tile.y { continue }
            }
            points.append(tile.center)
        }
        if goalTile == TileCoord(containing: goal), !points.isEmpty {
            points[points.count - 1] = goal
        }
        return points
    }

    // MARK: Driving

    /// A route for the truck, from the precise shapes it bumps into (trunks,
    /// rails, walls) rather than whole tiles: every tile on it has room for
    /// the truck (`radius`), no step crosses a fence or clips a trunk, roads
    /// are preferred, and the result is straightened wherever the truck can
    /// drive straight without leaving better ground. The first waypoint is the
    /// first one away from `start`; the last is `goal` (or the nearest spot
    /// with room for the truck).
    public static func drivingPath(on obstacles: DrivingObstacles, radius: Double, from start: Vec2, to goal: Vec2) -> [Vec2]? {
        let map = obstacles.map
        let width = map.width, height = map.height
        func index(_ t: TileCoord) -> Int { t.y * width + t.x }
        // Room for the truck in the middle of each tile, worked out as needed.
        var room = [UInt8](repeating: 0, count: width * height)  // 0 unknown, 1 room, 2 no room
        func fits(_ t: TileCoord) -> Bool {
            guard map.isInside(t) else { return false }
            let i = index(t)
            if room[i] == 0 { room[i] = obstacles.blocks(t.center, radius: radius) ? 2 : 1 }
            return room[i] == 1
        }

        let startTile = TileCoord(containing: start)
        guard map.isInside(startTile) else { return nil }
        let goalTile = TileCoord(containing: goal)
        var target: TileCoord?
        search: for ring in 0...4 {
            var best: (TileCoord, Int)?
            for dy in -ring...ring {
                for dx in -ring...ring where max(abs(dx), abs(dy)) == ring {
                    let t = TileCoord(goalTile.x + dx, goalTile.y + dy)
                    guard fits(t) else { continue }
                    let d = dx * dx + dy * dy
                    if best == nil || d < best!.1 { best = (t, d) }
                }
            }
            if let best { target = best.0; break search }
        }
        guard let goalTarget = target else { return nil }
        let goalPoint = goalTarget == goalTile && !obstacles.blocks(goal, radius: radius) ? goal : goalTarget.center
        if startTile == goalTarget { return [goalPoint] }

        var cost = [Double](repeating: .infinity, count: width * height)
        var cameFrom = [Int](repeating: -1, count: width * height)
        var closed = [Bool](repeating: false, count: width * height)
        var open = MinHeap()
        // A slightly greedy search: routes within a few percent of the best, found
        // several times faster (it runs when you tap).
        let greed = 1.3
        cost[index(startTile)] = 0
        open.push(index(startTile), priority: greed * heuristic(startTile, goalTarget))
        let neighbours: [(Int, Int, Double)] = [
            (1, 0, 1), (-1, 0, 1), (0, 1, 1), (0, -1, 1),
            (1, 1, 2.0.squareRoot()), (1, -1, 2.0.squareRoot()), (-1, 1, 2.0.squareRoot()), (-1, -1, 2.0.squareRoot()),
        ]
        var found = false
        while let current = open.pop() {
            if closed[current] { continue }
            closed[current] = true
            let tile = TileCoord(current % width, current / width)
            if tile == goalTarget { found = true; break }
            for (dx, dy, step) in neighbours {
                let next = TileCoord(tile.x + dx, tile.y + dy)
                guard fits(next) else { continue }
                let n = index(next)
                if closed[n] { continue }
                // The step itself: halfway is the tile edge (a fence) or corner (a trunk).
                let from = tile == startTile ? start : tile.center
                if obstacles.blocks((from + next.center) * 0.5, radius: radius) { continue }
                if dx != 0 && dy != 0 && !(fits(TileCoord(tile.x + dx, tile.y)) || fits(TileCoord(tile.x, tile.y + dy))) { continue }
                let newCost = cost[current] + step * drivingCost(map.terrain(at: next))
                if newCost < cost[n] {
                    cost[n] = newCost
                    cameFrom[n] = current
                    open.push(n, priority: newCost + greed * heuristic(next, goalTarget))
                }
            }
        }
        guard found else { return nil }

        var tiles: [TileCoord] = []
        var cursor = index(goalTarget)
        while cursor != index(startTile) && cursor >= 0 {
            tiles.append(TileCoord(cursor % width, cursor / width))
            cursor = cameFrom[cursor]
        }
        tiles.reverse()
        var points = [start] + tiles.map(\.center)
        points[points.count - 1] = goalPoint
        return straightened(points, on: obstacles, radius: radius)
    }

    /// Pulls a tile-by-tile route straight: from each waypoint, drive to the
    /// furthest later one in a clear straight line, as long as the line
    /// doesn't cross slower ground than the stretch it replaces (so a route
    /// along a road stays on it). Returns the waypoints after the first.
    static func straightened(_ route: [Vec2], on obstacles: DrivingObstacles, radius: Double) -> [Vec2] {
        guard route.count > 2 else { return Array(route.dropFirst()) }
        let map = obstacles.map
        // Only the corners matter: drop points in the middle of straight runs.
        var points = [route[0]]
        for i in 1..<(route.count - 1) {
            let a = route[i] - route[i - 1], b = route[i + 1] - route[i]
            if abs(a.x * b.y - a.y * b.x) > 1e-6 || a.x * b.x + a.y * b.y < 0 { points.append(route[i]) }
        }
        points.append(route[route.count - 1])
        // The slowest ground a straight line crosses (sampled every third of a tile).
        func slowest(_ a: Vec2, _ b: Vec2) -> Double {
            let steps = max(1, Int((a.distance(to: b) / 0.35).rounded(.up)))
            var worst = 1.0
            for i in 0...steps {
                let p = a + (b - a) * (Double(i) / Double(steps))
                worst = max(worst, drivingCost(map.terrain(at: TileCoord(containing: p))))
            }
            return worst
        }
        func clear(_ a: Vec2, _ b: Vec2) -> Bool {
            let steps = max(1, Int((a.distance(to: b) / 0.25).rounded(.up)))
            for i in 1..<steps where obstacles.blocks(a + (b - a) * (Double(i) / Double(steps)), radius: radius) { return false }
            return true
        }
        let maxReach = 14.0  // longer lines aren't needed: the driver just aims at the next waypoint
        var result: [Vec2] = []
        var anchor = 0
        while anchor < points.count - 1 {
            var best = anchor + 1
            var worstOnRoute = slowest(points[anchor], points[anchor + 1])
            var j = anchor + 2
            while j < points.count, points[anchor].distance(to: points[j]) <= maxReach {
                worstOnRoute = max(worstOnRoute, slowest(points[j - 1], points[j]))
                guard slowest(points[anchor], points[j]) <= worstOnRoute + 1e-9, clear(points[anchor], points[j]) else { break }
                best = j
                j += 1
            }
            result.append(points[best])
            anchor = best
        }
        return result
    }

    /// The truck's taste in ground: roads by far, a short hop over grass only
    /// when it saves a real detour (like a driver who'd rather not churn up the meadow).
    static func drivingCost(_ terrain: Terrain) -> Double {
        switch terrain {
        case .asphalt: 1.0
        case .gravel: 1.15
        case .dirt: 1.5
        case .grass: 3.0
        }
    }

    /// A route for the truck with room to spare where there is room (so it
    /// never brushes a trunk on a bend), squeezing through narrow tracks only
    /// when it must.
    public static func drivingRoute(on obstacles: DrivingObstacles, from start: Vec2, to goal: Vec2) -> [Vec2]? {
        for radius in [0.75, 0.6, 0.48] {
            if let path = drivingPath(on: obstacles, radius: radius, from: start, to: goal) { return path }
        }
        return nil
    }

    static func terrainCost(_ terrain: Terrain) -> Double {
        switch terrain {
        case .asphalt: 1.0
        case .gravel: 1.15
        case .dirt: 1.4
        case .grass: 2.0
        }
    }

    /// Octile distance: admissible because no tile costs less than 1.
    static func heuristic(_ a: TileCoord, _ b: TileCoord) -> Double {
        let dx = Double(abs(a.x - b.x)), dy = Double(abs(a.y - b.y))
        return max(dx, dy) + (2.0.squareRoot() - 1) * min(dx, dy)
    }

    static func nearestPassable(to tile: TileCoord, obstacles: Obstacles) -> TileCoord? {
        let map = obstacles.map
        if map.isInside(tile) && !obstacles.isBlocked(tile) { return tile }
        for radius in 1...4 {
            var best: TileCoord?
            var bestDistance = Int.max
            for dy in -radius...radius {
                for dx in -radius...radius where max(abs(dx), abs(dy)) == radius {
                    let t = TileCoord(tile.x + dx, tile.y + dy)
                    guard map.isInside(t), !obstacles.isBlocked(t) else { continue }
                    let d = dx * dx + dy * dy
                    if d < bestDistance { bestDistance = d; best = t }
                }
            }
            if let best { return best }
        }
        return nil
    }
}

/// Binary min-heap of (node, priority) for A*.
struct MinHeap {
    private var items: [(node: Int, priority: Double)] = []

    mutating func push(_ node: Int, priority: Double) {
        items.append((node, priority))
        var i = items.count - 1
        while i > 0 {
            let parent = (i - 1) / 2
            guard items[i].priority < items[parent].priority else { break }
            items.swapAt(i, parent)
            i = parent
        }
    }

    mutating func pop() -> Int? {
        guard !items.isEmpty else { return nil }
        let top = items[0].node
        let last = items.removeLast()
        if !items.isEmpty {
            items[0] = last
            var i = 0
            while true {
                let l = 2 * i + 1, r = l + 1
                var smallest = i
                if l < items.count && items[l].priority < items[smallest].priority { smallest = l }
                if r < items.count && items[r].priority < items[smallest].priority { smallest = r }
                if smallest == i { break }
                items.swapAt(i, smallest)
                i = smallest
            }
        }
        return top
    }
}

/// Follows a planned path by producing drive inputs, like a careful driver:
/// keeps to the planned line (aiming a little way ahead along it, not cutting
/// across to the next corner), slows down for sharp turns and eases off on
/// arrival.
public struct Autopilot: Equatable, Sendable {
    public private(set) var path: [Vec2]
    /// The segment being driven: from `path[index - 1]` (or the start) to `path[index]`.
    public private(set) var index = 0
    private var origin: Vec2?

    /// How far ahead along the line the driver aims, in tiles.
    static let lookAhead = 1.0

    public init(path: [Vec2], from start: Vec2? = nil) {
        self.path = path
        self.origin = start
    }

    public var destination: Vec2? { path.last }

    /// Input for this frame, or nil once the truck has arrived.
    public mutating func input(for truck: TruckState) -> DriveInput? {
        guard !path.isEmpty else { return nil }
        let here = truck.position
        if origin == nil { origin = here }
        func segmentStart(_ i: Int) -> Vec2 { i == 0 ? origin! : path[i - 1] }

        // Move on to the next segment once this one's end is reached or passed.
        while index < path.count - 1 {
            let a = segmentStart(index), b = path[index]
            let along = (b - a).length > 1e-6 ? ((here - a).x * (b - a).x + (here - a).y * (b - a).y) / (b - a).length : 0
            if here.distance(to: b) < 0.5 || along >= (b - a).length - 0.05 { index += 1 } else { break }
        }
        let end = path[path.count - 1]
        let isLast = index == path.count - 1
        if isLast && here.distance(to: end) < 0.45 { return nil }

        // Aim a little way ahead along the line from where the truck is.
        let a = segmentStart(index), b = path[index]
        let segment = b - a
        let length = segment.length
        var aim = b
        if length > 1e-6 {
            let t = min(1, max(0, ((here - a).x * segment.x + (here - a).y * segment.y) / (length * length)))
            var from = a + segment * t
            var left = Self.lookAhead
            var i = index
            while true {
                let to = path[i]
                let d = from.distance(to: to)
                if d >= left { aim = from + (to - from) * (left / d); break }
                if i == path.count - 1 { aim = to; break }
                left -= d
                from = to
                i += 1
            }
        }

        // Ease off for a sharp turn ahead, and when arriving.
        var throttle = 1.0
        let toCorner = here.distance(to: b)
        if !isLast {
            let next = path[index + 1] - b
            if length > 1e-6, next.length > 1e-6 {
                let cosTurn = (segment.x * next.x + segment.y * next.y) / (length * next.length)
                let sharpness = (1 - cosTurn) / 2  // 0 straight on … 1 doubling back
                let slow = 1 - 0.7 * sharpness
                throttle = min(1, slow + toCorner / 6)
            }
        } else {
            throttle = min(1, 0.2 + toCorner / 3)
        }
        return DriveInput(direction: aim - here, throttle: max(0.25, throttle))
    }
}
