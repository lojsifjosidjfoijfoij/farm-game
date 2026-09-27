import Foundation

/// Sprinklers keep the soil around them wet, online and offline.
///
/// Runs first and for the whole span at once: it tops up `wetUntil` past the
/// end of the span, so `CropSystem` sees covered crops as wet throughout.
public struct SprinklerSystem: SimulationSystem {
    public init() {}

    public var handlesAnyStepSize: Bool { true }

    public func step(_ state: inout GameState, _ context: inout StepContext) {
        let sprinklers = state.estate.sprinklers
        guard !sprinklers.isEmpty, !state.plots.isEmpty else { return }
        let until = state.worldTime + context.dt + 60
        for sprinkler in sprinklers {
            let r = sprinkler.radius
            for y in (sprinkler.tile.y - r)...(sprinkler.tile.y + r) {
                for x in (sprinkler.tile.x - r)...(sprinkler.tile.x + r) {
                    let tile = TileCoord(x, y)
                    guard tile != sprinkler.tile, var plot = state.plots[tile], plot.wetUntil < until else { continue }
                    plot.wetUntil = until
                    state.plots[tile] = plot
                }
            }
        }
    }
}

/// Farmhands work while the calendar runs, from `workStartHour` to
/// `workEndHour`: one task every few game minutes, the most useful one
/// nearest to where they are. (Like the shop, they rest while the game is
/// closed.)
public struct WorkerSystem: SimulationSystem {
    public init() {}

    public func step(_ state: inout GameState, _ context: inout StepContext) {
        guard context.mode == .live, !state.estate.workers.isEmpty else { return }
        let balance = context.balance
        let end = state.clock.totalMinutes
        let start = end - context.dt * balance.gameMinutesPerRealSecond
        let minutes = StoreSystem.openMinutes(from: start, to: end, opens: balance.workStartHour, closes: balance.workEndHour)
        guard minutes > 0 else { return }
        let hands = Farmhands(balance: balance)
        for index in state.estate.workers.indices {
            state.estate.workers[index].progress += minutes / 60 * balance.workerTasksPerHour
            // (A hair of tolerance so frame-by-frame sums reach whole tasks like big steps do.)
            while state.estate.workers[index].progress >= 1 - 1e-9 {
                guard hands.work(index, &state) else {
                    // Nothing to do: they wait, without banking the idle time.
                    state.estate.workers[index].progress = min(state.estate.workers[index].progress, 1)
                    break
                }
                state.estate.workers[index].progress = max(0, state.estate.workers[index].progress - 1)
            }
        }
    }
}

/// What farmhands do, one task at a time.
struct Farmhands {
    let balance: Balance
    var farming: Farming { Farming(map: HomeValleyMap.map, balance: balance) }
    var ranching: Ranching { Ranching(balance: balance) }

    /// Does the worker's next task; false if there's nothing to do.
    func work(_ index: Int, _ state: inout GameState) -> Bool {
        let worker = state.estate.workers[index]
        switch worker.job {
        case .fields: return fieldTask(index, worker, &state)
        case .animals: return animalTask(index, worker, &state)
        }
    }

    /// Harvest ripe crops first (while storage has room), then water thirsty ones.
    private func fieldTask(_ index: Int, _ worker: Worker, _ state: inout GameState) -> Bool {
        let roomy = state.storageCapacity(balance) - state.inventory.storageUsed
        var best: (tile: TileCoord, action: FarmAction, rank: Int, distance: Double)?
        for plot in state.plots.sorted {
            guard let crop = plot.crop, let def = crop.definition else { continue }
            let action: FarmAction
            let rank: Int
            if crop.isReady {
                guard roomy >= def.yield.upperBound else { continue }
                action = .harvest
                rank = 0
            } else if !plot.isWet(at: state.worldTime) {
                action = .water
                rank = 1
            } else {
                continue
            }
            let distance = worker.position.distance(to: plot.tile.center)
            if best == nil || rank < best!.rank || (rank == best!.rank && distance < best!.distance) {
                best = (plot.tile, action, rank, distance)
            }
        }
        guard let best else { return false }
        let result = farming.perform(best.action, at: best.tile, in: &state, byWorker: true)
        guard result.outcome.succeeded else { return false }
        finish(index, at: best.tile.center, task: best.action == .harvest ? .harvest : .water, &state)
        return true
    }

    /// Collect first, then water troughs, then feed the hungry (if there's food).
    private func animalTask(_ index: Int, _ worker: Worker, _ state: inout GameState) -> Bool {
        var best: (pen: PenDefinition, action: PenAction, rank: Int, distance: Double)?
        for pen in PenCatalog.all {
            let penState = state.ranch[pen.id]
            guard penState.isRepaired, !penState.animals.isEmpty,
                  ranching.accessProblem(pen, in: state, checkReach: false) == nil else { continue }
            var options: [(PenAction, Int)] = []
            if penState.animals.contains(where: \.hasProduct), state.inventory.storageUsed + 2 <= state.storageCapacity(balance) {
                options.append((.collect, 0))
            }
            if !penState.hasWater(at: state.worldTime) { options.append((.water, 1)) }
            if let species = pen.species, penState.animals.contains(where: \.isHungry),
               ranching.food(for: species, in: state.inventory) != nil {
                options.append((.feed, 2))
            }
            guard let (action, rank) = options.min(by: { $0.1 < $1.1 }) else { continue }
            let distance = worker.position.distance(to: Ranching.workSpot(pen))
            if best == nil || rank < best!.rank || (rank == best!.rank && distance < best!.distance) {
                best = (pen, action, rank, distance)
            }
        }
        guard let best else { return false }
        let result = ranching.perform(best.action, on: best.pen, in: &state, byWorker: true)
        guard result.outcome.succeeded else { return false }
        if case .collected(let items, _) = result.outcome {
            for (item, amount) in items { state.goals.add(GoalCounter.collected(item), amount) }
        }
        let task: WorkerTask = switch best.action {
        case .collect: .collect
        case .water: .fillTrough
        default: .feed
        }
        finish(index, at: Ranching.workSpot(best.pen), task: task, &state)
        return true
    }

    private func finish(_ index: Int, at spot: Vec2, task: WorkerTask, _ state: inout GameState) {
        state.estate.workers[index].position = spot
        state.estate.workers[index].tasksDone += 1
        state.estate.workers[index].lastTask = task
    }
}
