import Foundation
import AcresCore

/// Village projects: giving coins and goods, and finishing them.
extension GameController {
    private var works: VillageWorks { VillageWorks(balance: balance) }

    var villageProjects: [VillageProject] {
        _ = village  // the observed copy: re-read when the projects change
        return Village.visible(in: simulation.state)
    }

    /// A project with everything given, waiting to be opened.
    var readyVillageProject: VillageProject? {
        _ = village
        let state = simulation.state
        return Village.all.first { !village.finished.contains($0.id) && state.progress.level >= $0.unlockLevel && works.isReady($0, in: state) }
    }

    /// What the finished projects do for the farm, in plain words.
    var villageGifts: [String] {
        _ = village
        let perks = Village.perks(simulation.state)
        var lines: [String] = []
        if perks.marketDepth > 1.001 {
            lines.append("The market takes \(Int(((perks.marketDepth - 1) * 100).rounded()))% more of everything before prices fall.")
        }
        if perks.marketMemory < 0.999 { lines.append("Buyers come back twice as fast after you've sold a lot.") }
        if perks.marketPrices > 1.001 {
            lines.append("Every market price is \(Int(((perks.marketPrices - 1) * 100).rounded()))% higher.")
        }
        if perks.contractBonus > 0.001 { lines.append("Orders pay \(Int((perks.contractBonus * 100).rounded()))% more.") }
        return lines
    }

    func villageFraction(_ project: VillageProject) -> Double { Village.fraction(project, in: simulation.state) }
    func villageCoinsNeeded(_ project: VillageProject) -> Int { works.coinsNeeded(project, in: simulation.state) }
    func villageGoodsNeeded(_ project: VillageProject) -> [(item: String, needed: Int, have: Int)] {
        works.goodsNeeded(project, in: simulation.state)
    }
    func villageIsReady(_ project: VillageProject) -> Bool { works.isReady(project, in: simulation.state) }

    /// A project's sign or building was tapped: open its page in the journal
    /// (or, before the village asks for help, say what it is).
    func showVillageProject(_ project: VillageProject) {
        Haptics.tap()
        guard businessTabs.contains(.village) else {
            showMessage(project.id == "windmill"
                ? "The old windmill. It hasn't turned in forty years."
                : "\(project.name): the village hopes to get round to it one day.")
            return
        }
        villageFocus = project.id
        businessTab = .village
        showsBusiness = true
    }

    func giveToVillage(_ id: String, coins: Int) {
        let works = self.works
        let result = simulation.modify { state in Result { () throws(VillageFailure) in try works.giveCoins(id, amount: coins, state: &state) } }
        finishVillage(result) { given in
            Sound.play(.coins)
            showMessage("Gave \(given.formatted()) coins. The village thanks you!")
        }
    }

    func giveGoodsToVillage(_ id: String) {
        let works = self.works
        let result = simulation.modify { state in Result { () throws(VillageFailure) in try works.giveGoods(id, state: &state) } }
        finishVillage(result) { given in
            showMessage("Sent \(given) goods off on the cart.")
        }
    }

    func finishVillageProject(_ id: String) {
        let works = self.works
        let result = simulation.modify { state in Result { () throws(VillageFailure) in try works.finish(id, state: &state) } }
        finishVillage(result) { events in
            Sound.play(.coins)
            showsBusiness = false
            openedProject = Village.project(id)
            handle(events)
        }
    }

    /// Closes the "opened!" card; "go and see" pans the camera over to it.
    func dismissOpenedProject(goSee: Bool) {
        if goSee, let project = openedProject { cameraFocusRequest = VillageLayout.focus(for: project) }
        openedProject = nil
    }

    private func finishVillage<T>(_ result: Result<T, VillageFailure>, onSuccess: (T) -> Void) {
        switch result {
        case .success(let value):
            Haptics.tap()
            onSuccess(value)
            refreshBusiness()
            refreshInventory()
            refreshTruck()
            refreshDisplay()
            save()
        case .failure(let failure):
            Haptics.warning()
            showMessage(message(for: failure))
        }
    }

    func message(for failure: VillageFailure) -> String {
        switch failure {
        case .unknownProject: "That project isn't on the board."
        case .locked(let level): "The village asks for help with this at level \(level)."
        case .alreadyFinished: "That's already done."
        case .notEnoughMoney: "Not enough coins."
        case .nothingToGive: "You have none of what it still needs (in storage, your bag or the truck)."
        }
    }
}
