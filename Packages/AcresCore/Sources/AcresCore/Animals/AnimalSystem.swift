import Foundation

/// Grows up young animals, runs production for fed ones and lets hungry
/// ones grow a little sad. Runs on real time, online and offline.
///
/// Exact for any step size: the watered part of a step comes from the
/// trough's `waterUntil`, growing up splits the step at the exact moment,
/// and happiness changes linearly, so a 3-day catch-up equals 60 fps play.
public struct AnimalSystem: SimulationSystem {
    public init() {}

    public var handlesAnyStepSize: Bool { true }

    public func step(_ state: inout GameState, _ context: inout StepContext) {
        guard !state.ranch.pens.isEmpty else { return }
        let start = state.worldTime
        let dt = context.dt
        let balance = context.balance
        let decayPerSecond = balance.happinessDecayPerDay / balance.realSecondsPerGameDay

        for penID in state.ranch.pens.keys.sorted() {
            var pen = state.ranch.pens[penID]!
            guard !pen.animals.isEmpty else { continue }
            let wetEnd = pen.waterUntil
            for index in pen.animals.indices {
                var animal = pen.animals[index]
                guard let species = animal.species else { continue }

                // Growing up: the part of the step spent as an adult.
                let wasAdult = animal.isAdult
                animal.age += dt
                let adultFrom: TimeInterval  // seconds into the step when it became adult
                if wasAdult {
                    adultFrom = 0
                } else if animal.isAdult {
                    adultFrom = dt - (animal.age - species.growUpSeconds)
                    context.events.append(.animalGrewUp(penID: penID, animalID: animal.id))
                } else {
                    pen.animals[index] = animal
                    continue
                }
                let adultTime = dt - adultFrom

                if let production = animal.production {
                    guard production < species.produceSeconds else {
                        pen.animals[index] = animal
                        continue  // a product is waiting; the animal is content
                    }
                    let segmentStart = start + adultFrom
                    let wetTime = min(max(wetEnd - segmentStart, 0), adultTime)
                    let gain = wetTime + (adultTime - wetTime) * balance.dryProductionRate
                    animal.production = min(species.produceSeconds, production + gain)
                    if animal.production! >= species.produceSeconds {
                        context.events.append(.animalProductReady(penID: penID, animalID: animal.id))
                    }
                } else {
                    // Hungry: a little sadder every hour until someone brings food.
                    animal.happiness = max(0, animal.happiness - adultTime * decayPerSecond)
                }
                pen.animals[index] = animal
            }
            state.ranch.pens[penID] = pen
        }
    }
}
