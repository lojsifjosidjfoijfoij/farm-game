import XCTest
@testable import AcresCore

final class LegacyTests: XCTestCase {

    let balance = Balance.standard

    private func sim(money: Int = 0) -> Simulation {
        var state = GameState.newGame(seed: 91)
        state.tutorial = .complete
        state.money = money
        state.inventory = Inventory()
        state.clock = GameClock(dayIndex: 3, hour: 9)
        state.finance.lastProcessedDay = 3
        state.daily.day = 3
        return Simulation(state: state)
    }

    // MARK: Almanac

    func testEveryEntryIsOnAPage() {
        let entries = Set(Almanac.entries.map(\.id))
        let onPages = Set(Almanac.sets.flatMap(\.items))
        XCTAssertEqual(entries.subtracting(onPages), [], "entries with no set")
        XCTAssertEqual(onPages.subtracting(entries), [], "set items that aren't entries")
        XCTAssertEqual(Set(Almanac.sets.map(\.id)).count, Almanac.sets.count)
        XCTAssertGreaterThan(entries.count, 60)
    }

    func testDiscoveriesComeFromStorageAndCounters() {
        var game = sim()
        game.modify {
            $0.inventory.add("wheat", 3)
            $0.inventory.add("wheat_seeds", 5)  // seeds aren't collectibles
            $0.goals.add(GoalCounter.caught("carp"), 1)
            $0.truck.cargo.add("egg", 2)
        }
        let events = game.advance(by: 1, mode: .live)
        XCTAssertEqual(game.state.almanac.discovered, ["carp", "egg", "wheat"])
        XCTAssertEqual(events.filter { if case .discovered = $0 { true } else { false } }.count, 3)
        // Once only.
        game.modify { $0.inventory.remove("wheat", 3) }
        XCTAssertTrue(game.advance(by: 1, mode: .live).allSatisfy { if case .discovered = $0 { false } else { true } })
        XCTAssertTrue(game.state.almanac.has("wheat"), "kept after it's sold")
    }

    func testFinishedSetsPayOnce() {
        var game = sim()
        XCTAssertNil(game.claimAlmanacSet("orchard"), "not finished")
        game.modify { $0.almanac.discovered = ["apple", "cherry"] }
        let money = game.state.money
        guard let claim = game.claimAlmanacSet("orchard") else { return XCTFail("claimable") }
        XCTAssertEqual(claim.coins, Almanac.set("orchard")!.coins)
        XCTAssertEqual(game.state.money, money + claim.coins)
        XCTAssertNil(game.claimAlmanacSet("orchard"), "only once")
        XCTAssertEqual(Almanac.completion(game.state.almanac), 2 / Double(Almanac.entries.count), accuracy: 1e-9)
    }

    // MARK: Net worth and ranks

    func testNetWorthCountsWhatTheFarmOwns() {
        var game = sim(money: 10_000)
        XCTAssertEqual(NetWorth.of(game.state, balance: balance), 10_000)
        game.modify { $0.progress.level = 2 }
        _ = game.estate(on: HomeValleyMap.map) { try $0.buyLand("east_meadow", state: &$1) }
        XCTAssertEqual(NetWorth.of(game.state, balance: balance), 10_000, "coins became land")
        game.modify { $0.inventory.add("egg", 10) }
        XCTAssertEqual(NetWorth.of(game.state, balance: balance), 10_000 + 10 * 22)
        game.modify { $0.finance.loan = Loan(amount: 2_000, balance: 2_200, weeklyPayment: 300, weeksLeft: 8) }
        XCTAssertEqual(NetWorth.of(game.state, balance: balance), 10_000 + 10 * 22 - 2_200)
    }

    func testRanksClimbWithNetWorthAndNeverDrop() {
        XCTAssertEqual(FarmRanks.all.map(\.id), Array(FarmRanks.all.indices))
        XCTAssertEqual(FarmRanks.all.map(\.netWorth), FarmRanks.all.map(\.netWorth).sorted())
        var game = sim(money: 16_000)
        let events = game.advance(by: 1, mode: .live)
        XCTAssertEqual(game.state.rank.rank, 2)
        XCTAssertTrue(events.contains(.rankUp(1)) && events.contains(.rankUp(2)), "each rank passed is announced")
        game.modify { $0.money = 100 }
        _ = game.advance(by: 1, mode: .live)
        XCTAssertEqual(game.state.rank.rank, 2, "a bad week doesn't take it away")
        XCTAssertNil(game.state.rank.finaleDay)
    }

    func testTheFinale() {
        var game = sim(money: FarmRanks.finale.netWorth)
        let events = game.advance(by: 1, mode: .live)
        XCTAssertEqual(game.state.rank.rank, FarmRanks.finale.id)
        XCTAssertEqual(game.state.rank.finaleDay, 3)
        XCTAssertTrue(events.contains(.rankUp(FarmRanks.finale.id)))
        XCTAssertNil(FarmRanks.next(after: game.state.rank.rank), "the top")
        // Farming goes on.
        XCTAssertTrue(game.advance(by: 60, mode: .live).allSatisfy { if case .rankUp = $0 { false } else { true } })
    }
}
