import Foundation
import AcresCore

/// The tools on the farmer's belt. A field tool only ever does its own job,
/// so a tap or a drag never plows or plants by surprise.
enum BeltTool: String, CaseIterable, Identifiable {
    case hand, hoe, seeds, can, sickle, axe

    var id: String { rawValue }

    var name: String {
        switch self {
        case .hand: "Hand"
        case .hoe: "Hoe"
        case .seeds: "Seeds"
        case .can: "Watering can"
        case .sickle: "Sickle"
        case .axe: "Axe"
        }
    }

    /// The field job this tool does (nil for the hand and the axe).
    var fieldAction: FarmAction.Kind? {
        switch self {
        case .hoe: .plow
        case .seeds: .plant
        case .can: .water
        case .sickle: .harvest
        case .hand, .axe: nil
        }
    }

    /// Painted icon (the seed bag shows the packet in hand instead).
    var icon: String? {
        switch self {
        case .hand: "ui_icon_hand"
        case .hoe: "ui_icon_hoe"
        case .seeds: nil
        case .can: "ui_icon_watering_can"
        case .sickle: "ui_icon_sickle"
        case .axe: "ui_icon_axe"
        }
    }

    /// One line on how to use it (shown above the belt).
    var hint: String {
        switch self {
        case .hand: "Tap to walk, pick ripe crops and fruit, and look after animals."
        case .hoe: "Tap or drag over grass on your land to plow."
        case .seeds: "Tap or drag over plowed soil to plant. Tap the bag again to change seeds."
        case .can: "Tap or drag over your crops to water them."
        case .sickle: "Tap or drag over ripe crops to harvest."
        case .axe: "Tap a grown tree to chop it, or a stump to clear it."
        }
    }
}

extension GameController {
    /// Picks a tool. The seed bag, tapped again, opens the seed picker.
    func selectTool(_ newTool: BeltTool) {
        endPaint()
        if newTool == .seeds {
            if tool == .seeds || (cropSeedInHand == nil && saplingInHand == nil) {
                showsSeedPicker.toggle()
            }
        } else {
            showsSeedPicker = false
        }
        if tool != newTool {
            tool = newTool
            Haptics.selection()
            Sound.play(.tap, volume: 0.5)
        }
    }
}
