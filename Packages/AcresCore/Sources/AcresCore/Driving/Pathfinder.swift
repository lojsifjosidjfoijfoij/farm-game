import Foundation

/// A* route planning over the tile grid for tap-to-drive. Prefers roads:
/// asphalt is cheapest, grass most expensive, obstacles are impassable.
public enum Pathfinder {

    /// Waypoints (tile units) from `start` to `goal`, or nil if unreachable.
    /// The first waypoint is the first step away from `start`; the last is `goal`
    /// (or the nearest reachable spot next to it).
    public static func path(on map: WorldMap, woodland: Woodland = Woodland(), from start: Vec2, to goal: Vec2) -> [Vec2]? {
        let width = map.width, height = map.height
        let obstacles = Obstacles(map: map, woodland: woodland)
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
                // No cutting corners past obstacles.
                if dx != 0 && dy != 0 &&
                    (!passable(TileCoord(tile.x + dx, tile.y)) || !passable(TileCoord(tile.x, tile.y + dy))) { continue }
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

/// Follows a planned path by producing drive inputs, like a driver steering
/// toward the next waypoint and easing off on arrival.
public struct Autopilot: Equatable, Sendable {
    public private(set) var path: [Vec2]
    public private(set) var index = 0

    public init(path: [Vec2]) {
        self.path = path
    }

    public var destination: Vec2? { path.last }

    /// Input for this frame, or nil once the truck has arrived.
    public mutating func input(for truck: TruckState) -> DriveInput? {
        guard !path.isEmpty else { return nil }
        // Skip waypoints we've reached (or passed close by).
        while index < path.count - 1 && truck.position.distance(to: path[index]) < 0.9 {
            index += 1
        }
        let target = path[index]
        let distance = truck.position.distance(to: target)
        let isLast = index == path.count - 1
        if isLast && distance < 0.45 { return nil }
        let throttle = isLast ? min(1, 0.2 + distance / 3) : 1
        return DriveInput(direction: target - truck.position, throttle: throttle)
    }
}
