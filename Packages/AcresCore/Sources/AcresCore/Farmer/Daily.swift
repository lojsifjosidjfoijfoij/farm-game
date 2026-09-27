import Foundation

// MARK: - Daily chores

/// One small job for today, with a reward. Progress is counted from the goal
/// counters since the chore was set.
public struct DailyChore: Codable, Equatable, Sendable, Identifiable {
    public var id: String { counter }
    /// The `GoalCounter` it counts.
    public var counter: String
    public var title: String
    public var target: Int
    /// The counter's value when the chore was set.
    public var startCount: Int
    public var coins: Int
    public var xp: Int
    public var claimed: Bool

    public init(counter: String, title: String, target: Int, startCount: Int, coins: Int, xp: Int, claimed: Bool = false) {
        self.counter = counter
        self.title = title
        self.target = target
        self.startCount = startCount
        self.coins = coins
        self.xp = xp
        self.claimed = claimed
    }

    public func progress(in state: GameState) -> Int {
        min(target, max(0, state.goals.count(counter) - startCount))
    }

    public func isDone(in state: GameState) -> Bool { progress(in: state) >= target }
}

/// Today's chores, the streak of days with all of them done, and today's
/// market special.
public struct DailyState: Codable, Equatable, Sendable {
    /// The game day the chores are for (-1 before the first morning).
    public var day: Int
    public var chores: [DailyChore]
    /// Days in a row with every chore done (counted each morning).
    public var streak: Int
    public var bestStreak: Int
    /// The all-done bonus was claimed today.
    public var bonusClaimed: Bool
    /// Pays extra at the market today.
    public var specialItem: String?

    public init(day: Int = -1, chores: [DailyChore] = [], streak: Int = 0, bestStreak: Int = 0, bonusClaimed: Bool = false,
                specialItem: String? = nil) {
        self.day = day
        self.chores = chores
        self.streak = streak
        self.bestStreak = bestStreak
        self.bonusClaimed = bonusClaimed
        self.specialItem = specialItem
    }

    public func allDone(in state: GameState) -> Bool {
        !chores.isEmpty && chores.allSatisfy { $0.isDone(in: state) }
    }
}

/// The rules of the daily loop: fresh chores and a market special every
/// morning, rewards for each chore, a bonus for all of them, a streak.
public struct DailyRoutine: Sendable {
    public let balance: Balance

    public init(balance: Balance) {
        self.balance = balance
    }

    /// Chore templates: counter, title (with the target), target and weight by level.
    private func candidates(_ state: GameState) -> [(counter: String, title: (Int) -> String, target: Int)] {
        let level = state.progress.level
        let season = state.clock.date(daysPerSeason: balance.daysPerSeason).season
        let canPlant = CropCatalog.all.contains { $0.canBePlanted(in: season) && $0.unlockLevel <= level }
        var result: [(String, (Int) -> String, Int)] = []
        if canPlant {
            result.append((GoalCounter.planted, { "Plant \($0) crops" }, min(40, 10 + 2 * level)))
            result.append((GoalCounter.watered, { "Water \($0) crops" }, min(40, 10 + 2 * level)))
        }
        if !state.plots.isEmpty {
            result.append((GoalCounter.harvested, { "Harvest \($0) crops" }, min(60, 12 + 3 * level)))
        }
        result.append((GoalCounter.coinsFromSales, { "Sell goods worth \($0) at the market" }, 150 + 60 * level))
        if state.ranch.pens.values.contains(where: { $0.animals.contains { $0.speciesID == "chicken" } }) {
            result.append((GoalCounter.collected("egg"), { "Collect \($0) eggs" }, 3 + level / 2))
        }
        if state.ranch.pens.values.contains(where: { $0.animals.contains { $0.speciesID == "cow" } }) {
            result.append((GoalCounter.collected("milk"), { "Collect \($0) bottles of milk" }, 2 + level / 3))
        }
        result.append((GoalCounter.contractsCompleted, { $0 == 1 ? "Finish an order" : "Finish \($0) orders" }, 1))
        if state.ownedProperties.count > 1 || state.woodland.trees.count > 0 || level >= 2 {
            result.append((GoalCounter.treesChopped, { "Chop \($0) trees" }, 3))
        }
        if state.store.isRented {
            result.append((GoalCounter.coinsFromShop, { "Take in \($0) coins at your shop" }, 100 + 40 * level))
        }
        return result
    }

    /// Items the farm can make now (for the market special).
    private func specialCandidates(_ state: GameState) -> [String] {
        let level = state.progress.level
        return ItemCatalog.all.filter { $0.category.isSellable && Contracts.isObtainable($0.id, level: level) }.map(\.id)
    }

    /// Starts a new day: counts the streak, sets three chores and the special.
    public func rollOver(_ state: inout GameState, day: Int) {
        let previous = state.daily
        var daily = DailyState(day: day, streak: previous.streak, bestStreak: previous.bestStreak)
        if previous.day >= 0 {
            // Missing a day (or not finishing) resets the streak.
            let finished = previous.allDone(in: state) && previous.day == day - 1
            daily.streak = finished ? previous.streak + 1 : 0
            daily.bestStreak = max(previous.bestStreak, daily.streak)
        }
        // Chores and the special come from the day itself, not the game's RNG.
        var rng = SeededRandom(seed: SeededRandom.stableHash("daily") ^ (UInt64(bitPattern: Int64(day)) &* 0x9E37_79B9_7F4A_7C15))
        var pool = candidates(state)
        let level = state.progress.level
        for _ in 0..<min(3, pool.count) {
            let index = Int(rng.nextUnit() * Double(pool.count)) % pool.count
            let pick = pool.remove(at: index)
            daily.chores.append(DailyChore(counter: pick.counter, title: pick.title(pick.target), target: pick.target,
                                           startCount: state.goals.count(pick.counter),
                                           coins: 30 + 8 * level, xp: 3 + level / 2))
        }
        let specials = specialCandidates(state)
        if !specials.isEmpty {
            daily.specialItem = specials[Int(rng.nextUnit() * Double(specials.count)) % specials.count]
        }
        state.daily = daily
    }

    /// The all-done bonus: grows with the streak (up to a week).
    public func bonus(_ state: GameState) -> Int {
        let level = state.progress.level
        return 60 + 15 * level + 20 * min(7, state.daily.streak)
    }

    /// Claims a finished chore's reward. Returns the coins, or nil.
    public func claim(_ counter: String, state: inout GameState) -> (coins: Int, events: [SimEvent])? {
        guard let index = state.daily.chores.firstIndex(where: { $0.counter == counter }) else { return nil }
        let chore = state.daily.chores[index]
        guard !chore.claimed, chore.isDone(in: state) else { return nil }
        state.daily.chores[index].claimed = true
        state.money += chore.coins
        state.finance.earn(chore.coins, LedgerCategory.goals)
        let events = Progression.addXP(chore.xp, to: &state, balance: balance)
        return (chore.coins, events)
    }

    /// Claims the bonus for doing all of today's chores.
    public func claimBonus(state: inout GameState) -> Int? {
        guard !state.daily.bonusClaimed, state.daily.allDone(in: state),
              state.daily.chores.allSatisfy(\.claimed) else { return nil }
        let coins = bonus(state)
        state.daily.bonusClaimed = true
        state.money += coins
        state.finance.earn(coins, LedgerCategory.goals)
        return coins
    }
}

// MARK: - Weather

/// The day's weather. Rain waters every field; snow is for looking at.
public enum Weather: String, Codable, Sendable, CaseIterable {
    case sunny, cloudy, rain, snow

    public var name: String {
        switch self {
        case .sunny: "Sunny"
        case .cloudy: "Cloudy"
        case .rain: "Rain"
        case .snow: "Snow"
        }
    }

    /// Weather is fixed per day (so it can be forecast).
    public static func on(day: Int, balance: Balance) -> Weather {
        guard day > 0 else { return .sunny }  // the very first day is always fair
        let season = CalendarDate(dayIndex: day, daysPerSeason: balance.daysPerSeason).season
        var rng = SeededRandom(seed: SeededRandom.stableHash("weather") ^ (UInt64(bitPattern: Int64(day)) &* 0xD6E8_FEB8_6659_FD93))
        let roll = rng.nextUnit()
        switch season {
        case .spring: return roll < 0.28 ? .rain : (roll < 0.5 ? .cloudy : .sunny)
        case .summer: return roll < 0.14 ? .rain : (roll < 0.28 ? .cloudy : .sunny)
        case .autumn: return roll < 0.32 ? .rain : (roll < 0.6 ? .cloudy : .sunny)
        case .winter: return roll < 0.4 ? .snow : (roll < 0.7 ? .cloudy : .sunny)
        }
    }
}

extension GameState {
    public func weather(_ balance: Balance) -> Weather { Weather.on(day: clock.dayIndex, balance: balance) }
    public func tomorrowsWeather(_ balance: Balance) -> Weather { Weather.on(day: clock.dayIndex + 1, balance: balance) }
}

/// Rainy days water every field while the calendar runs (playing or
/// sleeping); the soil stays wet for half a day after the rain.
///
/// Runs first and for the whole span at once (before crops grow), with the
/// clock at the span's start: the rain lasts until that day ends.
public struct WeatherSystem: SimulationSystem {
    public init() {}

    public var handlesAnyStepSize: Bool { true }

    public func step(_ state: inout GameState, _ context: inout StepContext) {
        guard context.mode == .live, !state.plots.isEmpty, state.weather(context.balance) == .rain else { return }
        let rainLeft = state.clock.minutesUntilNextMorning / context.balance.gameMinutesPerRealSecond
        let until = state.worldTime + min(context.dt, rainLeft) + context.balance.soilWetDuration / 2
        state.plots.updateEach { plot in
            if plot.wetUntil < until { plot.wetUntil = until }
        }
    }
}
