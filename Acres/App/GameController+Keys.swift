import Foundation
import AcresCore

/// What a key does (an iPad with a keyboard, or the Mac). Held arrows or
/// WASD walk the farmer or steer the truck; the rest are one-press actions.
enum KeyAction: Equatable {
    case truck       // Space: hop in or out
    case map         // M: the drive-to card
    case journal     // J
    case bag         // B: the bag and farm storage
    case goals       // G
    case use         // E or Return: the shop, customer or store you're at
    case tool(Int)   // 1…7: the belt, left to right
    case escape      // Esc: put away whatever is open on the field
}

extension GameController {
    /// Nothing big on screen in front of the field (a card, sleep, a sheet).
    var keysReachTheField: Bool {
        welcome == nil && sleep == nil && levelUpCard == nil && rankUpCard == nil && openedProject == nil
            && weeklyReport == nil && openShop == nil && openWorkshop == nil
            && !showsBusiness && !showsInventory && !showsGoals && !showsStore && !showsRoadmap && !showsDebugPanel
    }

    /// A one-press key. Returns false when it isn't for the field right now
    /// (so a card's own Return button gets it instead).
    func handleKey(_ action: KeyAction) -> Bool {
        guard keysReachTheField else { return false }
        switch action {
        case .truck:
            tapTruck()
        case .map:
            guard isDriving || tutorial.hasReached(.drive) else { return false }
            showsDriveMap.toggle()
            Haptics.tap()
        case .journal:
            guard has(.phone) && tutorial.hasReached(.phone) else { return false }
            showsSeedPicker = false
            showsBusiness = true
        case .bag:
            showsSeedPicker = false
            showsInventory = true
        case .goals:
            showsGoals = true
        case .use:
            if nearbyShop != nil {
                openNearbyShop()
            } else if let client = nearbyClient {
                if client.isOpen(atHour: hour) {
                    deliverToNearbyClient()
                } else {
                    showMessage("\(client.name) is closed. It opens at \(String(format: "%02d:00", client.opens)).")
                }
            } else if nearbyStore != nil {
                openNearbyStore()
            } else {
                return false
            }
        case .tool(let index):
            guard !isDriving, beltTools.indices.contains(index) else { return false }
            selectTool(beltTools[index])
        case .escape:
            if showsDriveMap {
                showsDriveMap = false
            } else if showsSeedPicker {
                showsSeedPicker = false
            } else if inspection != nil {
                dismissInspection()
            } else if placingMachine != nil {
                cancelPlacing()
            } else {
                return false
            }
        }
        return true
    }

    // MARK: Held keys

    /// On foot: the farmer walks where the keys point (round anything solid,
    /// never through a fence), dropping whatever was lined up.
    func walkByKeys(dt: TimeInterval) {
        if !isKeyWalking {
            isKeyWalking = true
            cancelJobs()
        }
        let length = keyDirection.length
        guard length > 0 else { return }
        let direction = keyDirection * (1 / length)
        let tired = simulation.state.farmer.energy <= 0
        let step = direction * (balance.walkSpeed * (tired ? 0.55 : 1) * dt)
        let from = simulation.state.farmer.position
        let obstacles = Obstacles(map: map, state: simulation.state)
        func canStand(_ p: Vec2) -> Bool {
            let tile = TileCoord(containing: p)
            guard map.isInside(tile), !map.crossesFence(from: from, to: p) else { return false }
            // Stuck somewhere solid (an old save): any step out is fine.
            return !obstacles.isBlocked(tile) || obstacles.isBlocked(TileCoord(containing: from))
        }
        var to = from + step
        if !canStand(to) {
            let alongX = Vec2(to.x, from.y), alongY = Vec2(from.x, to.y)
            to = canStand(alongX) ? alongX : (canStand(alongY) ? alongY : from)
        }
        farmerFacing = direction
        if farmerActivity != .walking { farmerActivity = .walking }
        let moved = to
        simulation.modify { $0.farmer.position = moved }
    }

    /// The keys let go: the farmer stands still.
    func stopKeyWalking() {
        guard isKeyWalking else { return }
        isKeyWalking = false
        if farmerActivity == .walking { farmerActivity = .idle }
    }
}
