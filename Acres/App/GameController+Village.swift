import Foundation
import AcresCore

/// Village projects: giving coins and goods, and finishing them.
extension GameController {
    private var works: VillageWorks { VillageWorks(balance: balance) }

    var villageProjects: [VillageProject] { Village.visible(in: simulation.state) }

    func villageFraction(_ project: VillageProject) -> Double { Village.fraction(project, in: simulation.state) }
    func villageCoinsNeeded(_ project: VillageProject) -> Int { works.coinsNeeded(project, in: simulation.state) }
    func villageGoodsNeeded(_ project: VillageProject) -> [(item: String, needed: Int, have: Int)] {
        works.goodsNeeded(project, in: simulation.state)
    }
    func villageIsReady(_ project: VillageProject) -> Bool { works.isReady(project, in: simulation.state) }

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
            Haptics.success()
            Sound.play(.coins)
            showBanner("\(Village.project(id)?.name ?? "The project") is done! The whole village turned out.")
            handle(events)
        }
    }

    private func finishVillage<T>(_ result: Result<T, VillageFailure>, onSuccess: (T) -> Void) {
        switch result {
        case .success(let value):
            Haptics.tap()
            onSuccess(value)
            refreshBusiness()
            refreshInventory()
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
        case .nothingToGive: "Nothing it still needs from your storage or bag."
        }
    }
}
