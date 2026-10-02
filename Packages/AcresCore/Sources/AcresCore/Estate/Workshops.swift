import Foundation

// MARK: - Content

/// A recipe: goods in, an artisan good out after some game hours.
public struct Recipe: Sendable, Hashable, Identifiable {
    /// Also the output item's ID.
    public let id: String
    public let name: String
    public let plural: String
    /// Inputs per batch (empty for beehives).
    public let inputs: [String: Int]
    /// Items made per batch.
    public let amount: Int
    /// Game hours per batch (1 game hour = `GameTime.hour` real seconds).
    public let hours: Double
    public let xp: Int
    /// Market value of the output.
    public let value: ClosedRange<Int>
    /// Item category of the output (planks are wood; the rest artisan goods).
    public let category: ItemCategory

    public var seconds: TimeInterval { hours * GameTime.hour }
    public var output: String { id }
}

/// A workshop you buy, place on your land and feed with goods.
public struct WorkshopDefinition: Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let plural: String
    public let price: Int
    public let unlockLevel: Int
    public let blurb: String
    public let recipes: [Recipe]
    /// Works on its own (beehives): the recipe starts again after each collection.
    public let isAutomatic: Bool
    /// An automatic workshop stops when this many batches wait to be collected.
    public let holds: Int

    public var icon: String { "item_\(id)" }
    public var prop: String { "prop_workshop_\(id)" }
}

public enum WorkshopCatalog {
    public static let all: [WorkshopDefinition] = [
        WorkshopDefinition(
            id: "sawhorse", name: "Sawhorse", plural: "sawhorses", price: 800, unlockLevel: 2,
            blurb: "Saws logs into planks.", recipes: [
                Recipe(id: "plank", name: "Planks", plural: "planks", inputs: ["log": 2], amount: 3, hours: 3, xp: 2,
                       value: 14...18, category: .wood),
            ], isAutomatic: false, holds: 0),
        WorkshopDefinition(
            id: "mill", name: "Hand mill", plural: "hand mills", price: 1_200, unlockLevel: 3,
            blurb: "Grinds grain into flour and meal.", recipes: [
                Recipe(id: "flour", name: "Flour", plural: "sacks of flour", inputs: ["wheat": 4], amount: 2, hours: 4, xp: 3,
                       value: 38...46, category: .artisan),
                Recipe(id: "cornmeal", name: "Cornmeal", plural: "sacks of cornmeal", inputs: ["corn": 2], amount: 2, hours: 4, xp: 4,
                       value: 85...105, category: .artisan),
            ], isAutomatic: false, holds: 0),
        WorkshopDefinition(
            id: "beehive", name: "Beehive", plural: "beehives", price: 600, unlockLevel: 3,
            blurb: "Bees make honey by themselves every two days.", recipes: [
                Recipe(id: "honey", name: "Honey", plural: "jars of honey", inputs: [:], amount: 1, hours: 48, xp: 3,
                       value: 80...100, category: .artisan),
            ], isAutomatic: true, holds: 2),
        WorkshopDefinition(
            id: "jam_kitchen", name: "Jam kitchen", plural: "jam kitchens", price: 1_500, unlockLevel: 3,
            blurb: "Cooks fruit and tomatoes into jars.", recipes: [
                Recipe(id: "strawberry_jam", name: "Strawberry jam", plural: "jars of strawberry jam", inputs: ["strawberry": 4],
                       amount: 1, hours: 8, xp: 4, value: 120...150, category: .artisan),
                Recipe(id: "tomato_sauce", name: "Tomato sauce", plural: "jars of tomato sauce", inputs: ["tomato": 4],
                       amount: 1, hours: 6, xp: 4, value: 110...140, category: .artisan),
                Recipe(id: "blueberry_jam", name: "Blueberry jam", plural: "jars of blueberry jam", inputs: ["blueberry": 5],
                       amount: 1, hours: 8, xp: 5, value: 170...210, category: .artisan),
                Recipe(id: "blackberry_jam", name: "Blackberry jam", plural: "jars of blackberry jam", inputs: ["blackberry": 5],
                       amount: 1, hours: 8, xp: 4, value: 150...180, category: .artisan),
                Recipe(id: "elderflower_cordial", name: "Elderflower cordial", plural: "bottles of elderflower cordial",
                       inputs: ["elderflower": 4], amount: 1, hours: 8, xp: 5, value: 170...200, category: .artisan),
            ], isAutomatic: false, holds: 0),
        WorkshopDefinition(
            id: "drying_rack", name: "Drying rack", plural: "drying racks", price: 1_400, unlockLevel: 4,
            blurb: "Dries herbs and mushrooms from the woods.", recipes: [
                Recipe(id: "chamomile_tea", name: "Chamomile tea", plural: "tins of chamomile tea", inputs: ["chamomile": 3],
                       amount: 1, hours: 6, xp: 4, value: 95...115, category: .artisan),
                Recipe(id: "dried_mushrooms", name: "Dried mushrooms", plural: "bags of dried mushrooms", inputs: ["chanterelle": 3],
                       amount: 1, hours: 8, xp: 5, value: 200...240, category: .artisan),
            ], isAutomatic: false, holds: 0),
        WorkshopDefinition(
            id: "pickling_crock", name: "Pickling crock", plural: "pickling crocks", price: 1_800, unlockLevel: 4,
            blurb: "Slowly pickles vegetables.", recipes: [
                Recipe(id: "pickled_onions", name: "Pickled onions", plural: "jars of pickled onions", inputs: ["onion": 5],
                       amount: 1, hours: 10, xp: 4, value: 160...190, category: .artisan),
                Recipe(id: "sauerkraut", name: "Sauerkraut", plural: "jars of sauerkraut", inputs: ["cabbage": 2],
                       amount: 1, hours: 12, xp: 5, value: 400...460, category: .artisan),
            ], isAutomatic: false, holds: 0),
        WorkshopDefinition(
            id: "cheese_press", name: "Cheese press", plural: "cheese presses", price: 2_500, unlockLevel: 4,
            blurb: "Turns milk into cheese.", recipes: [
                Recipe(id: "cheese", name: "Cheese", plural: "wheels of cheese", inputs: ["milk": 2], amount: 1, hours: 12, xp: 6,
                       value: 190...240, category: .artisan),
                Recipe(id: "goat_cheese", name: "Goat cheese", plural: "goat cheeses", inputs: ["goat_milk": 2], amount: 1, hours: 12,
                       xp: 7, value: 240...300, category: .artisan),
            ], isAutomatic: false, holds: 0),
        WorkshopDefinition(
            id: "juice_press", name: "Juice press", plural: "juice presses", price: 2_200, unlockLevel: 5,
            blurb: "Presses fruit and carrots into juice.", recipes: [
                Recipe(id: "apple_juice", name: "Apple juice", plural: "bottles of apple juice", inputs: ["apple": 3], amount: 1,
                       hours: 6, xp: 4, value: 80...100, category: .artisan),
                Recipe(id: "carrot_juice", name: "Carrot juice", plural: "bottles of carrot juice", inputs: ["carrot": 4], amount: 1,
                       hours: 6, xp: 3, value: 115...140, category: .artisan),
                Recipe(id: "cherry_juice", name: "Cherry juice", plural: "bottles of cherry juice", inputs: ["cherry": 3], amount: 1,
                       hours: 6, xp: 5, value: 115...140, category: .artisan),
            ], isAutomatic: false, holds: 0),
        WorkshopDefinition(
            id: "oil_press", name: "Oil press", plural: "oil presses", price: 2_500, unlockLevel: 5,
            blurb: "Presses sunflowers into golden oil.", recipes: [
                Recipe(id: "sunflower_oil", name: "Sunflower oil", plural: "bottles of sunflower oil", inputs: ["sunflower": 2],
                       amount: 1, hours: 8, xp: 5, value: 340...400, category: .artisan),
            ], isAutomatic: false, holds: 0),
        WorkshopDefinition(
            id: "loom", name: "Loom", plural: "looms", price: 3_500, unlockLevel: 6,
            blurb: "Weaves wool into fine cloth.", recipes: [
                Recipe(id: "cloth", name: "Cloth", plural: "bolts of cloth", inputs: ["wool": 2], amount: 1, hours: 24, xp: 10,
                       value: 300...360, category: .artisan),
            ], isAutomatic: false, holds: 0),
        WorkshopDefinition(
            id: "smokehouse", name: "Smokehouse", plural: "smokehouses", price: 2_800, unlockLevel: 5,
            blurb: "Smokes fish over beech wood.", recipes: [
                Recipe(id: "smoked_trout", name: "Smoked trout", plural: "smoked trout", inputs: ["trout": 2], amount: 1, hours: 8,
                       xp: 5, value: 130...160, category: .artisan),
                Recipe(id: "smoked_salmon", name: "Smoked salmon", plural: "smoked salmon", inputs: ["salmon": 2], amount: 1,
                       hours: 10, xp: 7, value: 250...300, category: .artisan),
                Recipe(id: "smoked_eel", name: "Smoked eel", plural: "smoked eels", inputs: ["eel": 2], amount: 1, hours: 10,
                       xp: 8, value: 280...330, category: .artisan),
            ], isAutomatic: false, holds: 0),
    ]

    public static func workshop(_ id: String) -> WorkshopDefinition? { index[id] }

    public static var recipes: [Recipe] { all.flatMap(\.recipes) }

    /// The workshop and recipe that make an item.
    public static func maker(of item: String) -> (workshop: WorkshopDefinition, recipe: Recipe)? {
        for workshop in all {
            if let recipe = workshop.recipes.first(where: { $0.output == item }) { return (workshop, recipe) }
        }
        return nil
    }

    private static let index: [String: WorkshopDefinition] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}

// MARK: - State

/// A workshop standing on the farm.
public struct Workshop: Codable, Equatable, Sendable {
    public var tile: TileCoord
    public var kind: String
    /// What it's making (nil when idle).
    public var recipe: String?
    /// Batches paid for and not finished yet (the current one included).
    public var queued: Int
    /// Real seconds into the current batch.
    public var progress: TimeInterval
    /// Finished goods waiting to be collected.
    public var ready: Int
    /// The last recipe started (farmhands start it again).
    public var lastRecipe: String?

    public init(tile: TileCoord, kind: String, recipe: String? = nil, queued: Int = 0, progress: TimeInterval = 0,
                ready: Int = 0, lastRecipe: String? = nil) {
        self.tile = tile
        self.kind = kind
        self.recipe = recipe
        self.queued = queued
        self.progress = progress
        self.ready = ready
        self.lastRecipe = lastRecipe
    }

    public var definition: WorkshopDefinition? { WorkshopCatalog.workshop(kind) }
    public var currentRecipe: Recipe? { recipe.flatMap { id in definition?.recipes.first { $0.id == id } } }
    public var isIdle: Bool { queued == 0 && ready == 0 }

    /// Seconds until the current batch is done (nil if nothing is cooking).
    public var timeLeft: TimeInterval? {
        guard queued > 0, let recipe = currentRecipe else { return nil }
        return max(0, recipe.seconds - progress)
    }
}

/// What collecting from a workshop gave.
public struct WorkshopCollection: Sendable {
    public let item: String
    public let amount: Int
    public let xp: Int
    /// Level-ups from the XP.
    public let events: [SimEvent]
}

public enum WorkshopFailure: Error, Equatable, Sendable {
    case noWorkshop
    case tooFar
    case unknownRecipe
    case busy
    case missing(item: String, need: Int)
    case nothingReady
    case storageFull
    case notEmpty
}

// MARK: - Rules

/// Starting batches, collecting goods, picking workshops up.
public struct Workshops: Sendable {
    public let balance: Balance

    public init(balance: Balance) {
        self.balance = balance
    }

    private func index(at tile: TileCoord, _ state: GameState) throws(WorkshopFailure) -> Int {
        guard let index = state.estate.workshops.firstIndex(where: { $0.tile == tile }) else { throw .noWorkshop }
        return index
    }

    private func requireReach(_ tile: TileCoord, _ state: GameState, byWorker: Bool) throws(WorkshopFailure) {
        guard byWorker || (!state.farmer.inTruck && state.farmer.position.distance(to: tile.center) <= balance.workReach + 0.6) else {
            throw .tooFar
        }
    }

    /// How many batches of a recipe storage can pay for.
    public func affordableBatches(_ recipe: Recipe, in state: GameState) -> Int {
        guard !recipe.inputs.isEmpty else { return 1 }
        return recipe.inputs.map { state.inventory.count($0.key) / max(1, $0.value) }.min() ?? 0
    }

    /// Starts (or adds to) batches of a recipe, taking the goods from storage.
    public func start(_ recipeID: String, batches: Int = 1, at tile: TileCoord, state: inout GameState,
                      byWorker: Bool = false) throws(WorkshopFailure) {
        let i = try index(at: tile, state)
        try requireReach(tile, state, byWorker: byWorker)
        var workshop = state.estate.workshops[i]
        guard let definition = workshop.definition, let recipe = definition.recipes.first(where: { $0.id == recipeID }),
              batches > 0 else { throw .unknownRecipe }
        if definition.isAutomatic {
            guard workshop.queued == 0 else { throw .busy }
        } else {
            // More of the same is fine; something else waits until it's empty.
            guard workshop.recipe == recipeID || (workshop.queued == 0 && workshop.ready == 0) else { throw .busy }
        }
        for (item, count) in recipe.inputs.sorted(by: { $0.key < $1.key }) where state.inventory.count(item) < count * batches {
            throw .missing(item: item, need: count * batches)
        }
        for (item, count) in recipe.inputs { state.inventory.remove(item, count * batches) }
        if workshop.queued == 0 { workshop.progress = 0 }
        workshop.recipe = recipeID
        workshop.lastRecipe = recipeID
        workshop.queued += definition.isAutomatic ? 1 : batches
        state.estate.workshops[i] = workshop
    }

    /// Moves finished goods into storage; returns the item and how many.
    @discardableResult
    public func collect(at tile: TileCoord, state: inout GameState, byWorker: Bool = false) throws(WorkshopFailure) -> WorkshopCollection {
        let i = try index(at: tile, state)
        try requireReach(tile, state, byWorker: byWorker)
        var workshop = state.estate.workshops[i]
        guard workshop.ready > 0, let recipe = workshop.currentRecipe ?? workshop.lastRecipe.flatMap({ id in
            workshop.definition?.recipes.first { $0.id == id }
        }) else { throw .nothingReady }
        let amount = workshop.ready
        let usesStorage = ItemCatalog.item(recipe.output)?.category.usesStorage ?? true
        guard !usesStorage || state.inventory.storageUsed + amount <= state.storageCapacity(balance) else { throw .storageFull }
        state.inventory.add(recipe.output, amount)
        workshop.ready = 0
        if workshop.queued == 0, !(workshop.definition?.isAutomatic ?? false) { workshop.recipe = nil }
        state.estate.workshops[i] = workshop
        state.goals.add(GoalCounter.crafted, amount)
        var xp = 0
        var events: [SimEvent] = []
        if !byWorker {
            xp = recipe.xp * max(1, amount / max(1, recipe.amount))
            events = Progression.addXP(xp, to: &state, balance: balance)
        }
        return WorkshopCollection(item: recipe.output, amount: amount, xp: xp, events: events)
    }

    /// The XP a collection gives (for the UI).
    public func xp(forCollecting workshop: Workshop) -> Int {
        guard let recipe = workshop.currentRecipe ?? workshop.lastRecipe.flatMap({ id in workshop.definition?.recipes.first { $0.id == id } })
        else { return 0 }
        return recipe.xp * max(1, workshop.ready / max(1, recipe.amount))
    }

    /// Puts an empty workshop back in the pouch.
    public func pickUp(at tile: TileCoord, state: inout GameState) throws(WorkshopFailure) {
        let i = try index(at: tile, state)
        try requireReach(tile, state, byWorker: false)
        let workshop = state.estate.workshops[i]
        let automatic = workshop.definition?.isAutomatic ?? false
        guard workshop.ready == 0, automatic || workshop.queued == 0 else { throw .notEmpty }
        state.estate.workshops.remove(at: i)
        state.inventory.add(workshop.kind, 1)
    }

    // MARK: Time

    /// Moves every workshop on by `dt` real seconds. Exact for any step:
    /// whole batches finish in order, leftover time carries into the next.
    public func run(_ state: inout GameState, dt: TimeInterval) {
        for i in state.estate.workshops.indices {
            var workshop = state.estate.workshops[i]
            guard workshop.queued > 0, let definition = workshop.definition, let recipe = workshop.currentRecipe,
                  recipe.seconds > 0 else { continue }
            var time = dt
            while time > 0, workshop.queued > 0 {
                if definition.isAutomatic, workshop.ready >= definition.holds * recipe.amount {
                    break  // full: the bees rest until someone collects
                }
                let needed = recipe.seconds - workshop.progress
                if time < needed {
                    workshop.progress += time
                    time = 0
                } else {
                    time -= needed
                    workshop.progress = 0
                    workshop.ready += recipe.amount
                    if !definition.isAutomatic { workshop.queued -= 1 }
                }
            }
            state.estate.workshops[i] = workshop
        }
    }
}

/// Workshops work in real time, online and offline.
public struct WorkshopSystem: SimulationSystem {
    public init() {}

    public var handlesAnyStepSize: Bool { true }

    public func step(_ state: inout GameState, _ context: inout StepContext) {
        guard !state.estate.workshops.isEmpty else { return }
        Workshops(balance: context.balance).run(&state, dt: context.dt)
    }
}

extension EstateState {
    public func workshop(at tile: TileCoord) -> Workshop? { workshops.first { $0.tile == tile } }
}

extension Simulation {
    /// Runs a workshop action; failures leave the state unchanged.
    public mutating func workshops<T>(_ body: (Workshops, inout GameState) throws -> T) -> Result<T, WorkshopFailure> {
        var copy = state
        do {
            let value = try body(Workshops(balance: balance), &copy)
            modify { $0 = copy }
            return .success(value)
        } catch let failure as WorkshopFailure {
            return .failure(failure)
        } catch {
            preconditionFailure("Workshops only throw WorkshopFailure: \(error)")
        }
    }
}
