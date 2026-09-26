import SwiftUI
import AcresCore

/// "While you were away": what grew, what's ready and what needs care.
struct WelcomeBackView: View {
    let summary: AwaySummary
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Welcome back!")
                .font(Theme.title(28))
                .foregroundStyle(Theme.ink)

            Text("You were away for \(Self.format(summary.awayDuration)).")
                .font(Theme.label(16))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .center, spacing: 10) {
                        if let asset = line.asset {
                            ItemIcon(name: asset, size: 26)
                        } else {
                            Image(systemName: line.symbol)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(line.tint)
                                .frame(width: 26)
                        }
                        Text(line.text)
                            .font(Theme.label(15))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.parchmentDark.opacity(0.6)))

            Button(action: onContinue) {
                Text("Back to the farm")
                    .font(Theme.label(18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(colors: [Theme.leaf, Theme.leafDark], startPoint: .top, endPoint: .bottom))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.parchment)
                .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
        .padding(.horizontal, 28)
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
            case .newDay(let date):
                return Line(symbol: "sunrise.fill", tint: Theme.gold,
                            text: "A new day begins: \(date.season.name) \(date.dayOfSeason), Year \(date.year).")
            case .cropsReady(let cropID, let count):
                return Line(asset: "item_\(cropID)", text: "\(Self.count(count, cropID)) ready to harvest.")
            case .cropsGrowing(let cropID, let count, let secondsLeft):
                return Line(asset: "item_\(cropID)",
                            text: "\(Self.count(count, cropID)) still growing, all ripe in \(Format.duration(secondsLeft)).")
            case .thirstyCrops(let count):
                return Line(symbol: "drop.fill", tint: Color(red: 0.35, green: 0.6, blue: 0.8),
                            text: "\(count) thirsty \(count == 1 ? "crop" : "crops"): water them to grow twice as fast.")
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
