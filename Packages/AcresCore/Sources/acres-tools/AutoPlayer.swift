import AcresCore
import Foundation

/// A computer player: plays a new farm to the end by the game's own rules,
/// making the same calls into the simulation as the app's buttons and taps.
/// It doesn't animate the walking and driving in between, but lets their time
/// pass, and it keeps the same hours (shops' opening times, sleep at night).
/// Used for screenshots of a late game and for checking the balance.
struct AutoPlayer {
    private(set) var sim: Simulation
    let map = HomeValleyMap.map
    private(set) var diary: [String] = []

    private var balance: Balance { sim.balance }
    private var state: GameState { sim.state }
    private var level: Int { state.progress.level }
    private var hour: Double { state.clock.hourOfDay }
    private var season: Season { state.clock.date(daysPerSeason: balance.daysPerSeason).season }
    var day: Int { state.clock.dayIndex }
    var netWorth: Int { NetWorth.of(state, balance: balance) }

    /// Which crop each field grows (one crop to a field reads well on screen).
    private var fieldCrops: [String: String] = [:]

    init(seed: UInt64) {
        sim = Simulation(state: .newGame(seed: seed))
        // Arne's first loop is for people: the player knows the ropes.
        sim.modify { $0.tutorial.skip() }
    }

    // MARK: Days

    /// Plays whole days until `done` says stop (checked each morning and evening).
    mutating func play(maxDays: Int, until done: (AutoPlayer) -> Bool) {
        while day < maxDays, !done(self) {
            playDay()
        }
    }

    /// One day: chores and the fields in the morning, a trip to the village,
    /// the fields and workshops again, the evening at home, then bed.
    mutating func playDay() {
        morning()
        afternoon()
        evening()
        sleep()
    }

    mutating func morning() {
        claimRewards()
        invest()
        tendAnimals()
        workWorkshops()
        chopForPlanks()
        goFishing()
        workFields()
        if hour < 15 { tripToVillage() }
        workFields()
        workWorkshops()
        claimRewards()
        giveToVillage()
    }

    /// A short morning (for a picture at midday): the chores, the workshops
    /// and a trip to the market, the fields left to the field hand.
    mutating func lightMorning() {
        claimRewards()
        invest()
        workWorkshops()
        tripToVillage()
        giveToVillage()
        claimRewards()
    }

    /// The afternoon: the farmhands work, crops grow; a second round of
    /// harvesting, and selling if a lot is waiting.
    mutating func afternoon() {
        passUntil(hour: 15)
        workFields()
        if state.inventory.storageUsed > state.storageCapacity(balance) / 2 { tripToVillage() }
        workWorkshops()
        tendAnimals()
        claimRewards()
    }

    /// Home for the evening.
    mutating func evening(until bedtime: Double = 21.5) {
        passUntil(hour: bedtime)
        goHome()
    }

    mutating func sleep() {
        let startRank = state.rank.rank
        sim.sleep()
        if state.rank.rank > startRank {
            note("Rank: \(FarmRanks.rank(state.rank.rank).title) (net worth \(netWorth))")
        }
    }

    /// Lets the day run on to a time (the farmhands and the workshops keep at it).
    mutating func wait(until target: Double) { passUntil(hour: target) }

    /// Strolls over to a spot (for a picture).
    mutating func stroll(to spot: Vec2) { walk(to: spot) }

    /// Drives to a shop and gets out at its door (for a picture).
    mutating func visit(_ zone: TileRect) { drive(to: spot(in: zone)) }

    // MARK: Time and moving about

    private mutating func pass(_ seconds: TimeInterval) {
        sim.advance(by: seconds, mode: .live)
    }

    private mutating func passUntil(hour target: Double) {
        let minutes = (target - hour) * 60
        guard minutes > 0 else { return }
        pass(minutes / balance.gameMinutesPerRealSecond)
    }

    /// Walks over (the walk's time passes).
    private mutating func walk(to spot: Vec2) {
        let distance = state.farmer.position.distance(to: spot)
        sim.modify {
            $0.farmer.inTruck = false
            $0.farmer.position = spot
        }
        pass(distance / balance.walkSpeed)
    }

    /// Drives the truck to a spot and gets out beside it (the drive's time
    /// passes and it burns fuel; refuels when low).
    private mutating func drive(to spot: Vec2) {
        let from = state.truck.position
        let distance = from.distance(to: spot) * 1.3  // roads wind
        let heading = atan2(spot.y - from.y, spot.x - from.x)
        let fuelUsed = distance * balance.driving.fuelPerTile
        sim.modify { state in
            state.truck.position = spot
            state.truck.heading = heading
            state.truck.fuel = max(0, state.truck.fuel - fuelUsed)
            state.farmer.inTruck = false
            state.farmer.position = spot + Vec2(0, -1)
        }
        pass(distance / 5.5)
    }

    private mutating func goHome() {
        if state.truck.position.distance(to: HomeValleyMap.truckParkingSpot) > 1 {
            drive(to: HomeValleyMap.truckParkingSpot)
            sim.modify { $0.truck.heading = .pi }
        }
        walk(to: HomeValleyMap.farmhouseDoor)
    }

    private func spot(in zone: TileRect) -> Vec2 { Vec2((zone.minX + zone.maxX) / 2, zone.minY + 1) }

    // MARK: Rewards

    private mutating func claimRewards() {
        for goal in GoalCatalog.open(in: state) where GoalCatalog.isComplete(goal, in: state) {
            _ = sim.claimGoal(goal.id)
        }
        let routine = DailyRoutine(balance: balance)
        for chore in state.daily.chores where !chore.claimed && chore.isDone(in: state) {
            _ = sim.modify { routine.claim(chore.counter, state: &$0) }
        }
        _ = sim.modify { routine.claimBonus(state: &$0) }
    }

    // MARK: Fields

    /// Field tiles kept free for a big sprinkler (the middle of each 5 × 5 block).
    private func isSprinklerSpot(_ tile: TileCoord, in field: FieldDefinition) -> Bool {
        let dx = tile.x - Int(field.area.minX.rounded(.down)), dy = tile.y - Int(field.area.minY.rounded(.down))
        return dx % 5 == 2 && dy % 5 == 2
    }

    private func tiles(of field: FieldDefinition) -> [TileCoord] {
        let area = field.area
        var result: [TileCoord] = []
        for y in Int(area.minY.rounded(.down))..<Int(area.maxY.rounded(.up)) {
            for x in Int(area.minX.rounded(.down))..<Int(area.maxX.rounded(.up)) {
                let tile = TileCoord(x, y)
                if field.contains(tile) { result.append(tile) }
            }
        }
        return result
    }

    private var ownedFields: [FieldDefinition] {
        FieldCatalog.all.filter { state.ownedFields.contains($0.id) }
    }

    /// Coins a tile earns a day growing this crop (after seeds).
    private func value(_ crop: CropDefinition) -> Double {
        let price = Double(crop.sellPrice.lowerBound + crop.sellPrice.upperBound) / 2
        let yield = Double(crop.yield.lowerBound + crop.yield.upperBound) / 2
        if let regrow = crop.regrowSeconds { return price * yield / (regrow / GameTime.day) }
        return (price * yield - Double(crop.seedCost)) / (crop.growthSeconds / GameTime.day)
    }

    /// What the workshops and the village want grown, beyond what pays best.
    private var wantedCrops: [String] {
        var wanted: [String] = []
        for workshop in state.estate.workshops {
            for recipe in workshop.definition?.recipes ?? [] {
                for input in recipe.inputs.keys where CropCatalog.crop(input) != nil { wanted.append(input) }
            }
        }
        for project in Village.all where !state.village.finished.contains(project.id) && level >= project.unlockLevel {
            for item in project.goods.keys where CropCatalog.crop(item) != nil { wanted.append(item) }
        }
        return wanted
    }

    /// Picks a crop for a field that's (nearly) empty: the best payers in
    /// season, taking turns, with what the workshops and village need mixed in.
    private mutating func chooseCrop(for field: FieldDefinition, index: Int) -> String? {
        let plantable = CropCatalog.all.filter { level >= $0.unlockLevel && $0.canBePlanted(in: season) }
        guard !plantable.isEmpty else { return nil }
        let growing = Set(fieldCrops.filter { $0.key != field.id }.values)
        let regrowFields = fieldCrops.filter { $0.key != field.id && CropCatalog.crop($0.value)?.regrowSeconds != nil }.count
        let allowed = plantable.filter { $0.regrowSeconds == nil || regrowFields < 2 }
        // Something the village or the workshops need that no field grows yet comes first.
        if let needed = wantedCrops.first(where: { id in !growing.contains(id) && allowed.contains { $0.id == id } }) {
            return needed
        }
        let best = allowed.sorted { value($0) > value($1) }.prefix(5).map(\.id)
        guard !best.isEmpty else { return nil }
        return best.first { !growing.contains($0) } ?? best[index % best.count]
    }

    /// Harvests, replants, waters and plows, field by field, while energy lasts.
    private mutating func workFields() {
        for (index, field) in ownedFields.enumerated() {
            let fieldTiles = tiles(of: field).filter { !isSprinklerSpot($0, in: field) }
            // A new crop once the field is empty enough (or its crop is out of season).
            let planted = fieldTiles.filter { state.plots[$0]?.crop != nil }.count
            if let current = fieldCrops[field.id], let crop = CropCatalog.crop(current), crop.canBePlanted(in: season),
               planted > 0 || state.inventory.count(crop.seedItemID) > 0 {
                // Keep it.
            } else if planted * 3 < fieldTiles.count {
                fieldCrops[field.id] = chooseCrop(for: field, index: index)
            }
            let seed = fieldCrops[field.id]
            for tile in fieldTiles {
                guard state.farmer.energy > 8 else { return }
                if state.inventory.storageUsed >= state.storageCapacity(balance) - 2 { break }
                var acted = false
                for _ in 0..<4 {
                    let farming = Farming(map: map, balance: balance)
                    guard let action = farming.suggestedAction(at: tile, in: state, seed: plantableSeed(seed), checkReach: false)
                    else { break }
                    if case .plant = action, seed == nil { break }
                    if !acted {
                        walk(to: tile.center + Vec2(0, -0.6))
                        acted = true
                    }
                    let result = sim.perform(action, at: tile, on: map)
                    guard result.outcome.succeeded else { break }
                    pass(1.2)
                    if case .water = action { break }
                }
            }
        }
    }

    /// The seed to plant if any are in storage.
    private func plantableSeed(_ cropID: String?) -> String? {
        guard let cropID, let crop = CropCatalog.crop(cropID), state.inventory.count(crop.seedItemID) > 0 else { return nil }
        return cropID
    }

    /// Seeds still wanted for the fields' crops (empty soil and unplowed ground).
    private func seedsWanted() -> [String: Int] {
        var wanted: [String: Int] = [:]
        for field in ownedFields {
            guard let cropID = fieldCrops[field.id], let crop = CropCatalog.crop(cropID) else { continue }
            let free = tiles(of: field).filter { !isSprinklerSpot($0, in: field) && state.plots[$0]?.crop == nil }.count
            wanted[cropID, default: 0] += free
            _ = crop
        }
        for (cropID, count) in wanted {
            let have = CropCatalog.crop(cropID).map { state.inventory.count($0.seedItemID) } ?? 0
            wanted[cropID] = max(0, count - have)
        }
        return wanted.filter { $0.value > 0 }
    }

    // MARK: The village

    /// What to keep at home rather than sell: workshop inputs and village goods.
    private var keep: [String: Int] {
        var keep: [String: Int] = [:]
        for workshop in state.estate.workshops {
            for recipe in workshop.definition?.recipes ?? [] {
                for (item, count) in recipe.inputs { keep[item] = max(keep[item] ?? 0, count * 4) }
            }
        }
        let works = VillageWorks(balance: balance)
        for project in Village.all where !state.village.finished.contains(project.id) && level >= project.unlockLevel - 1 {
            for need in works.goodsNeeded(project, in: state) where need.needed > 0 {
                keep[need.item, default: 0] += need.needed
            }
        }
        for species in AnimalCatalog.all where state.ranch[species.penID].animals.count > 0 {
            keep["animal_feed", default: 0] += 0  // feed isn't sold anyway
        }
        return keep
    }

    /// Loads the goods, drives to the village: sells at the market (while
    /// prices hold up), buys seeds, animals and feed, fills the tank, comes home.
    private mutating func tripToVillage() {
        if hour < 8 { passUntil(hour: 8) }
        guard hour < 18 else { return }
        goHome()
        let keep = keep
        let room = state.truckCapacity(balance) - state.truck.cargoCount
        if room > 0 {
            let trading = Trading(balance: balance)
            let goods = ItemCatalog.all
                .filter { $0.category.isSellable && trading.price(of: $0.id, in: state) != nil }
                .sorted { $0.value.upperBound > $1.value.upperBound }
            for item in goods {
                let spare = state.inventory.count(item.id) - (keep[item.id] ?? 0)
                let space = state.truckCapacity(balance) - state.truck.cargoCount
                guard spare > 0, space > 0 else { continue }
                _ = sim.trade { try $0.load(item.id, count: min(spare, space), state: &$1) }
            }
            pass(Double(state.truck.cargoCount) * 0.15)
        }
        if state.truck.fuel < balance.driving.fuelCapacity * 0.5 {
            drive(to: spot(in: HomeValleyMap.gasStationZone))
            _ = sim.trade { try $0.refuel(state: &$1) }
        }
        if state.truck.cargoCount > 0 {
            drive(to: spot(in: HomeValleyMap.marketZone))
            sell()
        }
        buySeeds()
        buyAnimals()
        goHome()
        // Whatever didn't sell goes back in the barn.
        for (item, count) in state.truck.cargo.items {
            _ = sim.trade { try $0.unload(item, count: count, state: &$1) }
        }
    }

    /// Sells what's in the truck while the market still pays well for it.
    private mutating func sell() {
        let trading = Trading(balance: balance)
        let fullness = Double(state.inventory.storageUsed) / Double(state.storageCapacity(balance))
        let floor = fullness > 0.6 ? 0.32 : 0.55
        for item in state.truck.cargo.items.keys.sorted() {
            guard let base = trading.price(of: item, in: state) else { continue }
            while state.truck.cargo.count(item) > 0,
                  let now = trading.currentPrice(of: item, in: state), Double(now) >= Double(base) * floor {
                let chunk = min(5, state.truck.cargo.count(item))
                guard case .success = sim.trade({ try $0.sell(item, count: chunk, state: &$1) }) else { break }
            }
        }
        pass(60)
    }

    private mutating func buySeeds() {
        let wanted = seedsWanted()
        guard !wanted.isEmpty else { return }
        drive(to: spot(in: HomeValleyMap.seedShopZone))
        if hour < 8 { passUntil(hour: 8) }
        for (cropID, count) in wanted.sorted(by: { $0.key < $1.key }) {
            guard let crop = CropCatalog.crop(cropID) else { continue }
            let affordable = (state.money - reserve) / max(1, crop.seedCost)
            let buy = min(count, affordable)
            if buy > 0 { _ = sim.trade { try $0.buySeeds(cropID, count: buy, state: &$1) } }
        }
        pass(40)
    }

    /// Coins to keep for Monday's bills and seeds.
    private var reserve: Int {
        let wages = state.estate.workers.count * balance.workerWagePerWeek
        let tax = state.ownedProperties.count * balance.propertyTaxPerWeek
        let rent = state.store.isRented ? balance.storeRentPerWeek : 0
        return wages + tax + rent + 200
    }

    // MARK: Animals

    private var pensInOrder: [PenDefinition] {
        ["coop", "pasture", "sheepfold", "goat_pen", "pigsty"].compactMap { PenCatalog.pen($0) }
    }

    private func hasKeeper() -> Bool { state.estate.workers.contains { $0.job == .animals } }

    /// Repairs pens as they open up and looks after the animals (until an
    /// animal keeper does).
    private mutating func tendAnimals() {
        for pen in pensInOrder {
            let penState = state.ranch[pen.id]
            let ranching = Ranching(balance: balance)
            if !penState.isRepaired {
                guard level >= pen.unlockLevel, ranching.accessProblem(pen, in: state, checkReach: false) == nil,
                      state.money > pen.repairCost + reserve + 500 else { continue }
                walk(to: Ranching.workSpot(pen))
                _ = sim.perform(.repair, on: pen)
                pass(3)
                continue
            }
            guard !penState.animals.isEmpty, !hasKeeper() else { continue }
            walk(to: Ranching.workSpot(pen))
            for action in [PenAction.collect, .water, .feed] {
                guard state.farmer.energy > 4 else { break }
                if sim.perform(action, on: pen).outcome.succeeded { pass(2) }
            }
        }
    }

    /// Buys animals for pens with room, and feed for the week.
    private mutating func buyAnimals() {
        let open = pensInOrder.filter { state.ranch[$0.id].isRepaired }
        guard !open.isEmpty, hour < 17 else { return }
        drive(to: spot(in: HomeValleyMap.livestockZone))
        if hour < 8 { passUntil(hour: 8) }
        for pen in open {
            guard let species = AnimalCatalog.species(pen.speciesID) else { continue }
            while state.ranch[pen.id].animals.count < pen.capacity, state.money > species.price + reserve + 800 {
                guard case .success = sim.trade({ try $0.buyAnimal(species.id, state: &$1) }) else { break }
            }
        }
        let animals = state.ranch.allAnimals.count
        let wanted = animals * 6 - state.inventory.count("animal_feed")
        let room = state.storageCapacity(balance) - state.inventory.storageUsed - 20
        let count = min(wanted, room, (state.money - reserve) / balance.feedPrice)
        if count > 0 { _ = sim.trade { try $0.buyFeed(count: count, state: &$1) } }
        pass(40)
    }

    // MARK: Workshops

    /// Collects finished goods and starts what the storage can feed.
    private mutating func workWorkshops() {
        let rules = Workshops(balance: balance)
        for workshop in state.estate.workshops {
            let tile = workshop.tile
            let hasWork = workshop.ready > 0 || workshop.queued == 0
            guard hasWork else { continue }
            if workshop.ready > 0 || workshop.queued == 0 {
                walk(to: tile.center + Vec2(0, -1))
            }
            if workshop.ready > 0 {
                _ = sim.workshops { rules, state in try rules.collect(at: tile, state: &state) }
                pass(1)
            }
            guard let current = state.estate.workshop(at: tile), current.queued == 0,
                  let definition = current.definition else { continue }
            // The recipe the village needs, else the one with the most inputs on hand.
            let needs = Set(keepForVillage().keys)
            let recipes = definition.recipes
                .filter { rules.affordableBatches($0, in: state) > 0 }
                .sorted { a, b in
                    let aNeeded = needs.contains(a.output), bNeeded = needs.contains(b.output)
                    if aNeeded != bNeeded { return aNeeded }
                    return rules.affordableBatches(a, in: state) > rules.affordableBatches(b, in: state)
                }
            guard let recipe = recipes.first else { continue }
            let batches = definition.isAutomatic ? 1 : min(6, rules.affordableBatches(recipe, in: state))
            _ = sim.workshops { rules, state in try rules.start(recipe.id, batches: batches, at: tile, state: &state) }
            pass(1)
        }
    }

    private func keepForVillage() -> [String: Int] {
        var result: [String: Int] = [:]
        let works = VillageWorks(balance: balance)
        for project in Village.all where !state.village.finished.contains(project.id) && level >= project.unlockLevel {
            for need in works.goodsNeeded(project, in: state) where need.needed > need.have {
                result[need.item] = need.needed - need.have
            }
        }
        return result
    }

    /// Chops wild trees on the farm's land when the village wants planks or logs.
    private mutating func chopForPlanks() {
        let wanted = keepForVillage()
        let logsWanted = (wanted["log"] ?? 0) + (wanted["plank"] ?? 0) * 2 / 3 - state.inventory.count("log")
        guard logsWanted > 0, state.estate.workshops.contains(where: { $0.kind == "sawhorse" }) || wanted["log"] != nil else { return }
        let forestry = Forestry(map: map, balance: balance)
        var chopped = 0
        for (tile, _) in map.treesByFoot.sorted(by: { ($0.key.y, $0.key.x) < ($1.key.y, $1.key.x) }) {
            guard chopped < 4, state.farmer.energy > balance.energyCost.chop + 10 else { return }
            guard forestry.suggestedAction(at: tile, in: state, checkReach: false) == .chop else { continue }
            // Leave the farm's own trees (the yard looks bare without them).
            guard PropertyCatalog.property(containing: tile)?.id != PropertyCatalog.homeFarm.id else { continue }
            walk(to: forestry.workSpot(for: tile, in: state))
            if sim.perform(.chop, at: tile, on: map).outcome.succeeded {
                chopped += 1
                pass(2)
            }
        }
    }

    /// Fishes Willow Lake for trout when the smokehouse and the village want it.
    private mutating func goFishing() {
        let wanted = (keepForVillage()["smoked_trout"] ?? 0) * 2 - state.inventory.count("trout")
        guard wanted > 0, state.estate.workshops.contains(where: { $0.kind == "smokehouse" }),
              state.has(.rod), state.farmer.energy > 40 else { return }
        let lake = HomeValleyMap.lakeArea
        let shore = Vec2((lake.minX + lake.maxX) / 2, lake.maxY + 1.2)
        drive(to: shore + Vec2(0, 2))
        walk(to: shore)
        var caught = 0
        while caught < wanted, state.farmer.energy > 35, hour < 14 {
            let target = Vec2(shore.x, lake.maxY - 1)
            guard case .success(let bite) = sim.outdoors({ fishing, _, state in try fishing.cast(at: target, state: &state) })
            else { break }
            pass(8)  // waiting for the bite
            guard case .success = sim.outdoors({ fishing, _, state in try fishing.land(bite, state: &state) }) else { break }
            if bite.fishID == "trout" { caught += 1 }
            pass(4)
        }
        goHome()
    }

    private mutating func giveToVillage() {
        let works = VillageWorks(balance: balance)
        for project in Village.all where !state.village.finished.contains(project.id) && level >= project.unlockLevel {
            if works.goodsNeeded(project, in: state).contains(where: { $0.needed > 0 && $0.have > 0 }) {
                _ = sim.modify { state in try? works.giveGoods(project.id, state: &state) }
            }
            let spare = state.money - reserve - nextPurchaseCost - 2_000
            let needed = works.coinsNeeded(project, in: state)
            let coins = min(needed, spare)
            if coins > 0, coins >= min(500, needed) {
                _ = sim.modify { state in try? works.giveCoins(project.id, amount: coins, state: &state) }
            }
            if works.isReady(project, in: state) {
                _ = sim.modify { state in try? works.finish(project.id, state: &state) }
                note("Village: \(project.name) opened")
            }
        }
    }

    // MARK: Buying

    /// What the farm buys next, in order, and what it costs (0 when nothing's left).
    private var nextPurchaseCost: Int { purchases().first?.cost ?? 0 }

    private struct Purchase {
        let name: String
        let cost: Int
        let buy: (inout Simulation, WorldMap) -> Bool
    }

    private func purchases() -> [Purchase] {
        var list: [Purchase] = []
        let rules = EstateRules(map: map, balance: balance)
        func estate(_ body: @escaping (EstateRules, inout GameState) throws -> Void) -> (inout Simulation, WorldMap) -> Bool {
            { sim, map in
                if case .success = sim.estate(on: map, { rules, state in try body(rules, &state) }) { return true }
                return false
            }
        }
        // Fields on land already owned.
        for field in rules.fieldsForSale(state) where level >= field.unlockLevel {
            list.append(Purchase(name: field.name, cost: field.price, buy: estate { rules, state in _ = try rules.buyField(field.id, state: &state) }))
        }
        if let next = rules.nextHireLevel(state), level >= next {
            let job: WorkerJob = state.estate.workers.isEmpty ? .fields : (state.estate.workers.count == 1 ? .workshops : .animals)
            list.append(Purchase(name: "a \(job.title.lowercased())", cost: rules.firstWage(state) + 400,
                                 buy: estate { rules, state in _ = try rules.hire(job, state: &state) }))
        }
        if let upgrade = rules.nextStorageUpgrade(state), level >= upgrade.level {
            list.append(Purchase(name: "storage for \(upgrade.capacity)", cost: upgrade.cost,
                                 buy: estate { rules, state in _ = try rules.upgradeStorage(state: &state) }))
        }
        if let upgrade = rules.nextTruckBedUpgrade(state), level >= upgrade.level {
            list.append(Purchase(name: "a truck bed for \(upgrade.capacity)", cost: upgrade.cost,
                                 buy: estate { rules, state in _ = try rules.upgradeTruckBed(state: &state) }))
        }
        // Land with fields (and Goat Hill, North Woods for the goats and the wood).
        for id in ["east_meadow", "west_field", "north_woods", "south_pasture", "goat_hill"] {
            guard let property = PropertyCatalog.property(id), let price = property.price,
                  !state.ownedProperties.contains(id), level >= property.unlockLevel else { continue }
            list.append(Purchase(name: property.name, cost: price, buy: estate { rules, state in _ = try rules.buyLand(id, state: &state) }))
        }
        // Workshops, one of each to start (two beehives).
        let order = ["beehive", "mill", "sawhorse", "jam_kitchen", "pickling_crock", "oil_press", "juice_press",
                     "cheese_press", "beehive", "drying_rack", "loom", "smokehouse"]
        var counts: [String: Int] = [:]
        for kind in order {
            counts[kind, default: 0] += 1
            let owned = state.estate.workshops.filter { $0.kind == kind }.count + state.inventory.count(kind)
            guard owned < counts[kind]!, let workshop = WorkshopCatalog.workshop(kind), level >= workshop.unlockLevel else { continue }
            list.append(Purchase(name: workshop.name, cost: workshop.price,
                                 buy: estate { rules, state in _ = try rules.buyMachine(kind, state: &state) }))
            break
        }
        // Big sprinklers for the fields, when they come.
        if let sprinkler = MachineCatalog.machine("sprinkler_pro"), level >= sprinkler.unlockLevel,
           state.inventory.count("sprinkler_pro") == 0, freeSprinklerSpot() != nil {
            list.append(Purchase(name: "a big sprinkler", cost: sprinkler.price,
                                 buy: estate { rules, state in _ = try rules.buyMachine("sprinkler_pro", state: &state) }))
        }
        return list
    }

    /// Buys what's next on the list while the money lasts, then sets out
    /// what was delivered.
    private mutating func invest() {
        var bought = 0
        while bought < 6, let next = purchases().first(where: { state.money - $0.cost >= reserve + 300 }) {
            guard next.buy(&sim, map) else { break }
            note("Bought \(next.name) for \(next.cost)")
            bought += 1
        }
        placeFromPouch()
    }

    private func freeSprinklerSpot() -> TileCoord? {
        let rules = EstateRules(map: map, balance: balance)
        for field in ownedFields {
            for tile in tiles(of: field) where isSprinklerSpot(tile, in: field) {
                if rules.placeProblem(at: tile, in: state, checkReach: false) == nil { return tile }
            }
        }
        return nil
    }

    /// Where workshops stand: grass on the home farm by the yard, clear of
    /// fields, pens and paths, a tile apart.
    private func workshopSpot() -> TileCoord? {
        let rules = EstateRules(map: map, balance: balance)
        let anchor = Vec2(24.5, 40.5)
        let home = PropertyCatalog.homeFarm.area
        var candidates: [TileCoord] = []
        for y in Int(home.minY)..<Int(home.maxY) {
            for x in Int(home.minX)..<Int(home.maxX) {
                let tile = TileCoord(x, y)
                guard map.terrain(at: tile) == .grass, FieldCatalog.field(containing: tile) == nil,
                      !PenCatalog.all.contains(where: { $0.area.insetBy(-1.5).contains(tile.center) }),
                      rules.placeProblem(at: tile, in: state, checkReach: false) == nil else { continue }
                // Room around it: no other workshop, field or path right next to it.
                let around = (-1...1).flatMap { dy in (-1...1).map { dx in TileCoord(x + dx, y + dy) } }
                guard around.allSatisfy({ map.terrain(at: $0) == .grass && FieldCatalog.field(containing: $0) == nil
                    && !state.estate.isOccupied($0) }) else { continue }
                candidates.append(tile)
            }
        }
        return candidates.min { $0.center.distance(to: anchor) < $1.center.distance(to: anchor) }
    }

    private mutating func placeFromPouch() {
        for kind in WorkshopCatalog.all.map(\.id) + ["sprinkler_pro"] where state.inventory.count(kind) > 0 {
            guard let tile = kind == "sprinkler_pro" ? freeSprinklerSpot() : workshopSpot() else { continue }
            walk(to: tile.center + Vec2(0, -1))
            _ = sim.estate(on: map) { rules, state in try rules.placeMachine(kind, at: tile, state: &state) }
            pass(1)
        }
    }

    // MARK: Notes

    /// Where the farm stands: the village, animals, workshops, storage.
    var report: [String] {
        var lines: [String] = []
        let works = VillageWorks(balance: balance)
        for project in Village.all {
            if state.village.finished.contains(project.id) {
                lines.append("Village \(project.id): finished")
            } else {
                let goods = works.goodsNeeded(project, in: state).map { "\($0.item) \($0.needed) needed, \($0.have) on hand" }
                lines.append("Village \(project.id): \(works.coinsNeeded(project, in: state)) coins to go; " + goods.joined(separator: ", "))
            }
        }
        for pen in PenCatalog.all {
            let pen2 = state.ranch[pen.id]
            lines.append("Pen \(pen.id): repaired \(pen2.isRepaired), \(pen2.animals.count) animals")
        }
        lines.append("Workshops: " + state.estate.workshops.map { "\($0.kind)@\($0.tile.x),\($0.tile.y)" }.joined(separator: " "))
        lines.append("Workers: " + state.estate.workers.map { $0.job.rawValue }.joined(separator: ", "))
        lines.append("Fields: \(state.ownedFields.count), plots \(state.plots.count), sprinklers \(state.estate.sprinklers.count)")
        lines.append("Storage \(state.inventory.storageUsed)/\(state.storageCapacity(balance)): "
            + state.inventory.items.filter { $0.value > 0 }.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", "))
        lines.append("Ledger this week: \(state.finance.thisWeek)")
        return lines
    }

    private mutating func note(_ text: String) {
        diary.append("Day \(day + 1) (\(season.name), level \(level), \(state.money) coins): \(text)")
    }
}
