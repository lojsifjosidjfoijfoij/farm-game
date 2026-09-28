import XCTest
@testable import AcresCore

final class WorkshopTests: XCTestCase {

    let map = HomeValleyMap.map
    let balance = Balance.standard
    var rules: Workshops { Workshops(balance: balance) }

    /// A level-8 farmer with coins, standing on the farm.
    private func sim() -> Simulation {
        var state = GameState.newGame(seed: 51)
        state.progress.level = 8
        state.money = 50_000
        state.tutorial = .complete
        state.clock = GameClock(dayIndex: 1, hour: 9)
        state.finance.lastProcessedDay = 1
        state.daily.day = 1
        state.contracts.nextID = 9
        return Simulation(state: state)
    }

    /// Buys and places a workshop on a free grass tile of the farm; returns the tile.
    @discardableResult
    private func place(_ kind: String, in sim: inout Simulation, at tile: TileCoord = TileCoord(20, 31)) -> TileCoord {
        XCTAssertEqual(sim.estate(on: map) { try $0.buyMachine(kind, state: &$1) }.map { _ in 0 }, .success(0))
        sim.stand(at: tile.center)
        XCTAssertEqual(sim.estate(on: map) { try $0.placeMachine(kind, at: tile, state: &$1) }.map { _ in 0 }, .success(0))
        return tile
    }

    func testTheCatalogHangsTogether() {
        let ids = WorkshopCatalog.all.map(\.id) + WorkshopCatalog.recipes.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "unique ids")
        for recipe in WorkshopCatalog.recipes {
            XCTAssertNotNil(ItemCatalog.item(recipe.output), recipe.id)
            XCTAssertTrue(recipe.inputs.keys.allSatisfy { ItemCatalog.item($0) != nil }, "\(recipe.id) inputs exist")
            // Worth making: the output is worth more than the goods going in.
            let cost = recipe.inputs.reduce(0.0) { sum, input in
                let item = ItemCatalog.item(input.key)!
                return sum + Double(item.value.lowerBound + item.value.upperBound) / 2 * Double(input.value)
            }
            let value = Double(recipe.value.lowerBound + recipe.value.upperBound) / 2 * Double(recipe.amount)
            XCTAssertGreaterThan(value, cost * 1.2, "\(recipe.id) adds value")
        }
        XCTAssertTrue(WorkshopCatalog.all.allSatisfy { ItemCatalog.item($0.id)?.category == .machine })
    }

    func testBuyingPlacingAndPickingUp() {
        var sim = sim()
        sim.modify { $0.progress.level = 2 }
        XCTAssertEqual(sim.estate(on: map) { try $0.buyMachine("mill", state: &$1) }, .failure(.locked(level: 3)))
        sim.modify { $0.progress.level = 8 }
        let tile = place("mill", in: &sim)
        XCTAssertEqual(sim.state.estate.workshops.map(\.kind), ["mill"])
        XCTAssertEqual(sim.work(.plow, at: tile, on: map).outcome, .failed(.cannotPlowHere))
        sim.stand(at: tile.center)
        XCTAssertEqual(sim.workshops { try $0.pickUp(at: tile, state: &$1) }.map { _ in 0 }, .success(0))
        XCTAssertEqual(sim.state.inventory.count("mill"), 1)
        XCTAssertTrue(sim.state.estate.workshops.isEmpty)
    }

    func testMillingFlourInBatches() {
        var sim = sim()
        let tile = place("mill", in: &sim)
        sim.modify { $0.inventory.add("wheat", 10) }
        XCTAssertEqual(sim.workshops { try $0.start("flour", batches: 3, at: tile, state: &$1) }.map { _ in 0 }, .failure(.missing(item: "wheat", need: 12)))
        XCTAssertEqual(sim.workshops { try $0.start("flour", batches: 2, at: tile, state: &$1) }.map { _ in 0 }, .success(0))
        XCTAssertEqual(sim.state.inventory.count("wheat"), 2)
        XCTAssertEqual(sim.workshops { try $0.start("cornmeal", at: tile, state: &$1) }.map { _ in 0 }, .failure(.busy))
        XCTAssertEqual(sim.workshops { try $0.collect(at: tile, state: &$1) }.map(\.amount), .failure(.nothingReady))

        // 4 game hours per batch; the whole run finishes even while the game is closed.
        sim.advance(by: 4 * GameTime.hour + 1, mode: .offline)
        XCTAssertEqual(sim.state.estate.workshops[0].ready, 2)
        XCTAssertEqual(sim.state.estate.workshops[0].queued, 1)
        sim.advance(by: 4 * GameTime.hour, mode: .offline)
        XCTAssertEqual(sim.state.estate.workshops[0].ready, 4)
        XCTAssertEqual(sim.state.estate.workshops[0].queued, 0)

        let xp = sim.state.progress.xp
        sim.stand(at: tile.center)
        guard case .success(let collected) = sim.workshops({ try $0.collect(at: tile, state: &$1) }) else { return XCTFail() }
        XCTAssertEqual(collected.item, "flour")
        XCTAssertEqual(collected.amount, 4)
        XCTAssertEqual(sim.state.inventory.count("flour"), 4)
        XCTAssertEqual(sim.state.goals.count(GoalCounter.crafted), 4)
        XCTAssertGreaterThan(sim.state.progress.xp + sim.state.progress.level * 1000, xp + 8 * 1000)
        XCTAssertTrue(sim.state.estate.workshops[0].isIdle)
        XCTAssertNil(sim.state.estate.workshops[0].recipe)
        // Now something else can go in.
        sim.modify { $0.inventory.add("corn", 2) }
        XCTAssertEqual(sim.workshops { try $0.start("cornmeal", at: tile, state: &$1) }.map { _ in 0 }, .success(0))
    }

    func testStepSizeDoesNotChangeTheOutput() {
        var sim = sim()
        let tile = place("jam_kitchen", in: &sim)
        sim.modify { $0.inventory.add("strawberry", 12) }
        _ = sim.workshops { try $0.start("strawberry_jam", batches: 3, at: tile, state: &$1) }
        var frames = sim
        var chunk = sim
        for _ in 0..<(20 * 60) { frames.advance(by: 1, mode: .offline) }
        chunk.advance(by: 20 * 60, mode: .offline)
        XCTAssertEqual(frames.state.estate.workshops, chunk.state.estate.workshops)
        XCTAssertEqual(chunk.state.estate.workshops[0].ready, 2, "two 8-hour batches in 20 hours")
        XCTAssertEqual(chunk.state.estate.workshops[0].progress, 4 * GameTime.hour, accuracy: 1e-6)
    }

    func testBeehivesWorkOnTheirOwnAndRestWhenFull() {
        var sim = sim()
        let tile = place("beehive", in: &sim)
        XCTAssertEqual(sim.workshops { try $0.start("honey", at: tile, state: &$1) }.map { _ in 0 }, .success(0))
        XCTAssertEqual(sim.workshops { try $0.start("honey", at: tile, state: &$1) }.map { _ in 0 }, .failure(.busy))
        sim.advance(by: GameTime.days(7), mode: .offline)
        XCTAssertEqual(sim.state.estate.workshops[0].ready, 2, "holds two jars, then rests")
        sim.stand(at: tile.center)
        XCTAssertEqual(sim.workshops { try $0.collect(at: tile, state: &$1) }.map(\.amount), .success(2))
        XCTAssertEqual(sim.state.estate.workshops[0].queued, 1, "keeps going")
        sim.advance(by: GameTime.days(2) + 1, mode: .offline)
        XCTAssertEqual(sim.state.estate.workshops[0].ready, 1)
    }

    func testCollectingNeedsTheFarmerThereAndRoomInStorage() {
        var sim = sim()
        let tile = place("sawhorse", in: &sim)
        sim.modify { $0.inventory.add("log", 2) }
        _ = sim.workshops { try $0.start("plank", at: tile, state: &$1) }
        sim.advance(by: 3 * GameTime.hour + 1, mode: .offline)
        sim.stand(at: TileCoord(40, 40).center)
        XCTAssertEqual(sim.workshops { try $0.collect(at: tile, state: &$1) }.map(\.amount), .failure(.tooFar))
        sim.stand(at: tile.center)
        let capacity = sim.state.storageCapacity(balance)
        sim.modify { $0.inventory.add("potato", capacity - $0.inventory.storageUsed - 1) }
        XCTAssertEqual(sim.workshops { try $0.collect(at: tile, state: &$1) }.map(\.amount), .failure(.storageFull))
    }

    func testAWorkshopHandCollectsAndRestarts() {
        var sim = sim()
        let tile = place("mill", in: &sim)
        sim.modify { $0.inventory.add("wheat", 12) }
        _ = sim.workshops { try $0.start("flour", at: tile, state: &$1) }
        sim.advance(by: 4 * GameTime.hour + 1, mode: .offline)
        _ = sim.estate(on: map) { try $0.hire(.workshops, state: &$1) }
        sim.goHome()
        sim.modify { $0.clock = GameClock(dayIndex: 1, hour: 9) }
        sim.advance(by: 30 * 60 / balance.gameMinutesPerRealSecond, mode: .live)  // half an hour: four tasks
        XCTAssertEqual(sim.state.inventory.count("flour"), 2, "collected")
        XCTAssertEqual(sim.state.estate.workshops[0].recipe, "flour", "started again")
        XCTAssertEqual(sim.state.inventory.count("wheat"), 4, "with wheat from storage")
        XCTAssertEqual(sim.state.estate.workers[0].lastTask, .craft)
    }

    func testArtisanGoodsAreOrderedAndObtainable() {
        XCTAssertTrue(Contracts.isObtainable("flour", level: 3))
        XCTAssertFalse(Contracts.isObtainable("flour", level: 2))
        XCTAssertFalse(Contracts.isObtainable("goat_cheese", level: 20), "no goats yet")
        XCTAssertTrue(Contracts.isObtainable("honey", level: 3))
        let deli = ClientCatalog.client("valley_deli")!
        XCTAssertTrue(deli.wants.allSatisfy { ItemCatalog.item($0) != nil })
        XCTAssertTrue(ItemCatalog.item("cheese")!.category.isSellable)
    }
}
