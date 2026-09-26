import SwiftUI
import AcresCore

/// "While you were away": a friendly summary after returning to the game.
/// Phase 2+ add crops ready, eggs collected, storage full, etc.
struct WelcomeBackView: View {
    let report: OfflineReport
    let balance: Balance
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Welcome back!")
                .font(Theme.title(28))
                .foregroundStyle(Theme.ink)

            Text("You were away for \(Self.format(report.awayDuration)).")
                .font(Theme.label(16))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(lines, id: \.text) { line in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: line.symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(line.tint)
                            .frame(width: 22)
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
        let symbol: String
        let tint: Color
        let text: String
    }

    private var lines: [Line] {
        var result: [Line] = []
        if report.clockWentBackwards {
            result.append(Line(symbol: "clock.arrow.circlepath", tint: Theme.inkSoft,
                               text: "Your device's clock seems to have changed, so no time passed on the farm."))
        }
        for event in report.events {
            if case .newSeason(let season, _) = event {
                result.append(Line(symbol: Theme.seasonSymbol(season), tint: Theme.seasonColor(season),
                                   text: "\(season.name) has arrived!"))
            }
        }
        if report.startedNewDay {
            let date = report.dateAfter
            result.append(Line(symbol: "sunrise.fill", tint: Theme.gold,
                               text: "A new day begins: \(date.season.name) \(date.dayOfSeason), Year \(date.year)."))
        }
        if report.wasCapped {
            result.append(Line(symbol: "hourglass", tint: Theme.inkSoft,
                               text: "The farm only catches up on \(Self.format(balance.offlineCatchUpCap)) at a time."))
        }
        if result.isEmpty {
            result.append(Line(symbol: "leaf.fill", tint: Theme.leaf, text: "The farm is just as you left it."))
        }
        return result
    }

    static func format(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3600 ? [.day, .hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 2
        return formatter.string(from: max(0, seconds)) ?? "a while"
    }
}
