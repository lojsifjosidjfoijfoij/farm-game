import SwiftUI
import AcresCore

/// "While you were away": what grew, what's ready and what needs care.
struct WelcomeBackView: View {
    let summary: AwaySummary
    let onContinue: () -> Void

    var body: some View {
        RewardCard(ribbon: "WELCOME BACK!", tint: .green, celebrates: false) {
            Text("You were away for \(Self.format(summary.awayDuration)).")
                .font(Theme.label(15, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 9) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .center, spacing: 10) {
                        if let asset = line.asset {
                            ItemIcon(name: asset, size: 24)
                        } else {
                            MenuIcon(symbol: line.symbol, tint: line.tint)
                        }
                        Text(line.text)
                            .font(Theme.label(15))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(InsetPanel())

            RewardButton(title: "Back to the farm", action: onContinue)
        }
    }

    private struct Line {
        var symbol = "leaf.fill"
        var asset: String?
        var tint = Theme.leaf
        let text: String
    }

    private var lines: [Line] {
        summary.lines.map { line in
            switch line {
            case .clockChanged:
                return Line(symbol: "clock.arrow.circlepath", tint: Theme.inkSoft,
                            text: "Your device's clock seems to have changed, so no time passed on the farm.")
            case .newSeason(let season):
                return Line(symbol: Theme.seasonSymbol(season), tint: Theme.seasonColor(season), text: "\(season.name) has arrived!")
            case .cropsReady(let cropID, let count):
                return Line(asset: "item_\(cropID)", text: "\(Self.count(count, cropID)) ready to harvest.")
            case .cropsGrowing(let cropID, let count, let secondsLeft):
                return Line(asset: "item_\(cropID)",
                            text: "\(Self.count(count, cropID)) still growing, all ripe in \(Format.duration(secondsLeft)).")
            case .thirstyCrops(let count):
                return Line(symbol: "drop.fill", tint: Color(red: 0.35, green: 0.6, blue: 0.8),
                            text: "\(count) thirsty \(count == 1 ? "crop" : "crops"): water them to grow twice as fast.")
            case .productsReady(let itemID, let count):
                return Line(asset: "item_\(itemID)", text: "\(ItemCatalog.describe(count, itemID).capitalizedFirst) waiting in the pens.")
            case .grewUp(let names):
                let list = switch names.count {
                case 1: names[0]
                case 2, 3: names.dropLast().joined(separator: ", ") + " and " + names.last!
                default: "\(names.count) young animals"
                }
                return Line(symbol: "heart.fill", tint: Color(red: 0.85, green: 0.35, blue: 0.4), text: "\(list) grew up!")
            case .hungryAnimals(let count):
                return Line(symbol: "fork.knife", tint: Theme.gold,
                            text: "\(count) hungry \(count == 1 ? "animal is" : "animals are") waiting for a meal.")
            case .fruitReady(let count):
                return Line(asset: "item_apple", text: "\(count) fruit \(count == 1 ? "tree has" : "trees have") ripe fruit to pick.")
            case .treesGrown(let count):
                return Line(symbol: "tree.fill", tint: Theme.leaf, text: "\(count) \(count == 1 ? "tree has" : "trees have") grown tall.")
            case .storageFull(let used, let capacity):
                return Line(symbol: "shippingbox.fill", tint: Color(red: 0.8, green: 0.3, blue: 0.25),
                            text: "Storage is full (\(used)/\(capacity)).")
            case .capped(let seconds):
                return Line(symbol: "hourglass", tint: Theme.inkSoft,
                            text: "The farm only catches up on \(Self.format(seconds)) at a time.")
            case .nothingNew:
                return Line(text: "The farm is just as you left it.")
            }
        }
    }

    /// "1 carrot", "4 carrots", "3 wheat".
    /// (Crops only; other items use `ItemCatalog.describe`.)
    static func count(_ count: Int, _ cropID: String) -> String {
        guard let crop = CropCatalog.crop(cropID) else { return "\(count) \(cropID)" }
        return "\(count) \(count == 1 ? crop.name.lowercased() : crop.plural)"
    }

    static func format(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3600 ? [.day, .hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 2
        return formatter.string(from: max(0, seconds)) ?? "a while"
    }
}

extension String {
    /// "4 eggs" → "4 eggs"; "eggs" → "Eggs".
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
