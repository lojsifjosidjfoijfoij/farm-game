import SwiftUI
import AcresCore

/// The farm journal's Farm tab: grow the farm. Fields, farmhands, machines,
/// workshops, buildings and land, each with what it costs and what it needs.
/// It opens up with the farmer: only what's here now or next level shows.
struct FarmTabView: View {
    let game: GameController
    @State private var pendingLand: PropertyDefinition?
    @State private var pendingDismissal: Worker?

    /// Shown if it's open now or opens at the next level (something to look forward to).
    private func isInView(_ unlockLevel: Int) -> Bool { unlockLevel <= game.level + 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            fields
            if !game.estateState.workers.isEmpty || game.nextHireLevel.map(isInView) == true { workers }
            if MachineCatalog.all.contains(where: { isInView($0.unlockLevel) }) { machines }
            if WorkshopCatalog.all.contains(where: { isInView($0.unlockLevel) }) { workshops }
            if game.estateState.storageLevel > 0 || game.estateState.truckBedLevel > 0
                || game.nextStorageUpgrade.map({ isInView($0.level) }) == true
                || game.nextTruckBedUpgrade.map({ isInView($0.level) }) == true { buildings }
            if PropertyCatalog.forSale.contains(where: { isInView($0.unlockLevel) || game.ownedLand.contains($0.id) }) { land }
        }
        .confirmationDialog(pendingLand.map { "Buy \($0.name)?" } ?? "", isPresented: Binding(
            get: { pendingLand != nil }, set: { if !$0 { pendingLand = nil } }), titleVisibility: .visible) {
            if let land = pendingLand {
                Button("Buy for \(land.price ?? 0) coins") { game.buyLand(land.id) }
            }
        } message: {
            Text("Every property is taxed \(game.balance.propertyTaxPerWeek) coins on Mondays.")
        }
        .confirmationDialog(pendingDismissal.map { "Let \($0.name) go?" } ?? "", isPresented: Binding(
            get: { pendingDismissal != nil }, set: { if !$0 { pendingDismissal = nil } }), titleVisibility: .visible) {
            if let worker = pendingDismissal {
                Button("Let \(worker.name) go", role: .destructive) { game.dismissWorker(worker.id) }
            }
        } message: {
            Text("Wages already paid aren't refunded.")
        }
    }

    // MARK: Farmhands

    @ViewBuilder
    private var workers: some View {
        FarmSectionTitle(title: "Farmhands", trailing: "\(game.balance.workerWagePerWeek) coins a week each")
        ForEach(game.estateState.workers) { worker in
            workerCard(worker)
        }
        if let level = game.nextHireLevel {
            if game.level < level {
                LockedNote(text: "Hire a farmhand from level \(level). They water, harvest and look after animals 08:00–17:00.")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hire a farmhand: \(game.firstWage) coins now (the days until Monday), then wages with the bills.")
                        .font(Theme.label(13))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        ForEach(WorkerJob.allCases, id: \.self) { job in
                            ActionCapsule(title: "Hire \(job.title.lowercased())", enabled: game.money >= game.firstWage) {
                                game.hire(job)
                            }
                        }
                    }
                }
                .card()
            }
        }
    }

    private func workerCard(_ worker: Worker) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: worker.job.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.leafDark))
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(worker.name) · \(worker.job.title)")
                        .font(Theme.label(15, weight: .semibold))
                    Text(game.status(of: worker))
                        .font(Theme.label(12))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                Button("Let go") { pendingDismissal = worker }
                    .font(Theme.label(12, weight: .semibold))
                    .foregroundStyle(Theme.danger)
            }
            Picker("Job", selection: Binding(get: { worker.job }, set: { game.assign(worker.id, to: $0) })) {
                ForEach(WorkerJob.allCases, id: \.self) { job in
                    Text(job.title).tag(job)
                }
            }
            .pickerStyle(.segmented)
        }
        .foregroundStyle(Theme.ink)
        .card()
    }

    // MARK: Machines

    @ViewBuilder
    private var machines: some View {
        FarmSectionTitle(title: "Machines", trailing: nil)
        ForEach(MachineCatalog.all.filter { isInView($0.unlockLevel) }) { machine in
            machineCard(machine)
        }
    }

    // MARK: Fields

    /// Your fields, and the ones on your land you can buy (crops only grow in fields).
    @ViewBuilder
    private var fields: some View {
        let owned = FieldCatalog.all.filter { game.ownedFields.contains($0.id) }
        FarmSectionTitle(title: "Fields", trailing: "\(owned.map(\.tileCount).reduce(0, +)) tiles to farm")
        let forSale = game.fieldsForSale.filter { isInView($0.unlockLevel) }.sorted { ($0.unlockLevel, $0.price) < ($1.unlockLevel, $1.price) }
        if forSale.isEmpty {
            LockedNote(text: game.fieldsForSale.isEmpty
                       ? "Every field on your land is yours. Buy more land for more fields."
                       : "More fields come up for sale as you level up.")
        }
        ForEach(forSale) { field in
            fieldCard(field)
        }
    }

    private func fieldCard(_ field: FieldDefinition) -> some View {
        let locked = game.level < field.unlockLevel
        let where_ = PropertyCatalog.property(field.propertyID)?.name ?? ""
        return HStack(spacing: 10) {
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(locked ? Theme.inkSoft : Theme.leafDark)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(field.name)
                    .font(Theme.label(15, weight: .semibold))
                Text("\(field.tileCount) tiles of farmland · \(where_)")
                    .font(Theme.label(12))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 4)
            if locked {
                Label("Level \(field.unlockLevel)", systemImage: "lock.fill")
                    .font(Theme.label(12, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            } else {
                ActionCapsule(title: "Buy · \(field.price)", enabled: game.money >= field.price) { game.buyField(field.id) }
            }
        }
        .foregroundStyle(Theme.ink)
        .card()
    }

    private func machineCard(_ machine: MachineDefinition) -> some View {
        let owned = game.inventoryItems[machine.id] ?? 0
        let standing = game.estateState.sprinklers.filter { $0.kind == machine.id }.count
        let locked = game.level < machine.unlockLevel
        return HStack(spacing: 10) {
            ItemIcon(name: machine.icon, size: 40)
                .opacity(locked ? 0.4 : 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(machine.name)
                    .font(Theme.label(15, weight: .semibold))
                Text(machine.blurb)
                    .font(Theme.label(12))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(standing) in the fields · \(owned) to place")
                    .font(Theme.label(11))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 4)
            VStack(spacing: 6) {
                if locked {
                    Label("Level \(machine.unlockLevel)", systemImage: "lock.fill")
                        .font(Theme.label(12, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                } else {
                    ActionCapsule(title: "Buy · \(machine.price)", enabled: game.money >= machine.price) { game.buyMachine(machine.id) }
                    if owned > 0 {
                        ActionCapsule(title: "Place", enabled: true, tint: Theme.gold) { game.startPlacing(machine.id) }
                    }
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .card()
    }

    // MARK: Workshops

    @ViewBuilder
    private var workshops: some View {
        FarmSectionTitle(title: "Workshops", trailing: "Turn crops into goods worth more")
        ForEach(WorkshopCatalog.all.filter { isInView($0.unlockLevel) }) { workshop in
            workshopCard(workshop)
        }
    }

    private func workshopCard(_ workshop: WorkshopDefinition) -> some View {
        let owned = game.inventoryItems[workshop.id] ?? 0
        let standing = game.estateState.workshops.filter { $0.kind == workshop.id }.count
        let locked = game.level < workshop.unlockLevel
        let makes = workshop.recipes.map { $0.name.lowercased() }.joined(separator: ", ")
        return HStack(spacing: 10) {
            ItemIcon(name: workshop.icon, size: 40)
                .opacity(locked ? 0.4 : 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(workshop.name)
                    .font(Theme.label(15, weight: .semibold))
                Text(workshop.blurb)
                    .font(Theme.label(12))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Text(standing + owned > 0 ? "Makes \(makes) · \(standing) set up · \(owned) to place" : "Makes \(makes)")
                    .font(Theme.label(11))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            VStack(spacing: 6) {
                if locked {
                    Label("Level \(workshop.unlockLevel)", systemImage: "lock.fill")
                        .font(Theme.label(12, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                } else {
                    ActionCapsule(title: "Buy · \(workshop.price)", enabled: game.money >= workshop.price) { game.buyMachine(workshop.id) }
                    if owned > 0 {
                        ActionCapsule(title: "Place", enabled: true, tint: Theme.gold) { game.startPlacing(workshop.id) }
                    }
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .card()
    }

    // MARK: Buildings

    @ViewBuilder
    private var buildings: some View {
        FarmSectionTitle(title: "Buildings", trailing: nil)
        upgradeCard(title: "Storage", symbol: "archivebox.fill", now: "Holds \(game.storageCapacity)",
                    next: game.nextStorageUpgrade, nextName: game.estateState.storageLevel == 0 ? "a storage shed" : "a silo") {
            game.upgradeStorage()
        }
        upgradeCard(title: "Truck bed", symbol: "truck.pickup.side.fill", now: "Carries \(game.truckCapacity)",
                    next: game.nextTruckBedUpgrade, nextName: "a bigger bed") {
            game.upgradeTruckBed()
        }
    }

    private func upgradeCard(title: String, symbol: String, now: String, next: (capacity: Int, cost: Int, level: Int)?,
                             nextName: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.leafDark)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.label(15, weight: .semibold))
                Text(next.map { "\(now) · \(nextName): \($0.capacity)" } ?? "\(now) · the biggest there is")
                    .font(Theme.label(12))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 4)
            if let next {
                if game.level < next.level {
                    Label("Level \(next.level)", systemImage: "lock.fill")
                        .font(Theme.label(12, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                } else {
                    ActionCapsule(title: "Build · \(next.cost)", enabled: game.money >= next.cost, action: action)
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .card()
    }

    // MARK: Land

    @ViewBuilder
    private var land: some View {
        FarmSectionTitle(title: "Land for sale", trailing: nil)
        ForEach(PropertyCatalog.forSale.filter { isInView($0.unlockLevel) || game.ownedLand.contains($0.id) }) { property in
            landCard(property)
        }
    }

    private func landCard(_ property: PropertyDefinition) -> some View {
        let owned = game.ownedLand.contains(property.id)
        let price = property.price ?? 0
        let locked = game.level < property.unlockLevel
        return HStack(spacing: 10) {
            Image(systemName: owned ? "checkmark.seal.fill" : "signpost.right.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(owned ? Theme.leaf : Theme.inkSoft)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(property.name)
                    .font(Theme.label(15, weight: .semibold))
                Text(owned ? "Yours." : property.blurb)
                    .font(Theme.label(12))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            if !owned {
                if locked {
                    Label("Level \(property.unlockLevel)", systemImage: "lock.fill")
                        .font(Theme.label(12, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                } else {
                    ActionCapsule(title: "Buy · \(price)", enabled: game.money >= price) { pendingLand = property }
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .card()
    }
}

// MARK: - Pieces

private struct FarmSectionTitle: View {
    let title: String
    let trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Theme.title(19))
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(Theme.label(12))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(.top, 4)
    }
}

private struct LockedNote: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "lock.fill")
            .font(Theme.label(13))
            .foregroundStyle(Theme.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
            .card()
    }
}

/// A small candy button (green, or gold for rewards and placing).
struct ActionCapsule: View {
    let title: String
    let enabled: Bool
    var tint: Color = Theme.leafDark
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(Theme.label(14, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(minHeight: 22)
        }
        .buttonStyle(CandyButtonStyle(tint: enabled ? CandyTint.matching(tint) : .gray, cornerRadius: 12, lip: 3))
        .disabled(!enabled)
    }
}

extension WorkerJob {
    /// SF Symbol for the job.
    var symbol: String {
        switch self {
        case .fields: "leaf.fill"
        case .animals: "hare.fill"
        case .workshops: "hammer.fill"
        }
    }
}
