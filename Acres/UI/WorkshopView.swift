import SwiftUI
import AcresCore

/// A workshop's panel (opens when the farmer walks up to it): what it's
/// making and when it's done, the goods ready to collect, and its recipes
/// with what they take from storage.
struct WorkshopView: View {
    let game: GameController
    let sheet: WorkshopSheet

    var body: some View {
        MenuSheet(title: game.workshopSnapshot?.definition?.name ?? "Workshop", icon: "ui_icon_hammer",
                  onClose: { game.closeWorkshop() }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let workshop = game.workshopSnapshot, let definition = workshop.definition {
                        header(definition)
                        status(workshop, definition)
                        if !definition.isAutomatic {
                            PageHeading(title: "Recipes")
                            ForEach(definition.recipes) { recipe in
                                recipeRow(recipe, workshop: workshop)
                            }
                        }
                        pickUp(workshop, definition)
                    }
                }
                .padding(16)
            }
        }
    }

    private func header(_ definition: WorkshopDefinition) -> some View {
        HStack(spacing: 12) {
            ItemIcon(name: definition.icon, size: 52)
            Text(definition.blurb)
                .font(Theme.label(14))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Status

    @ViewBuilder
    private func status(_ workshop: Workshop, _ definition: WorkshopDefinition) -> some View {
        let recipe = workshop.currentRecipe
        VStack(alignment: .leading, spacing: 10) {
            if workshop.ready > 0, let made = recipe ?? workshop.lastRecipe.flatMap({ id in definition.recipes.first { $0.id == id } }) {
                HStack(spacing: 10) {
                    ItemIcon(name: "item_\(made.output)", size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(workshop.ready) \(workshop.ready == 1 ? made.name : made.plural) ready!")
                            .font(Theme.label(16, weight: .bold))
                        Text("Worth about \(made.value.lowerBound)–\(made.value.upperBound) coins each · +\(game.workshopRules.xp(forCollecting: workshop)) XP")
                            .font(Theme.label(12))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Spacer(minLength: 4)
                    ActionCapsule(title: "Collect", enabled: true, tint: Theme.gold) { game.collectWorkshop() }
                }
            }
            if let recipe, workshop.queued > 0 {
                let full = definition.isAutomatic && workshop.ready >= definition.holds * recipe.amount
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(full ? "Full: collect to keep it going." : working(recipe, workshop, definition))
                            .font(Theme.label(14, weight: .semibold))
                        Spacer()
                        if !full, let left = game.timeUntilDone(workshop) {
                            Text(Format.duration(left))
                                .font(Theme.number(14))
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }
                    HUDBar(fraction: full ? 1 : min(1, workshop.progress / max(1, recipe.seconds)), color: full ? HUD.gold : HUD.xp)
                        .frame(height: 12)
                }
            } else if workshop.ready == 0 {
                Text("Idle. Pick a recipe below: the goods come out of storage.")
                    .font(Theme.label(14))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .foregroundStyle(Theme.ink)
        .card()
    }

    private func working(_ recipe: Recipe, _ workshop: Workshop, _ definition: WorkshopDefinition) -> String {
        if definition.isAutomatic { return "Making \(recipe.name.lowercased())…" }
        let batches = workshop.queued == 1 ? "" : " · \(workshop.queued) batches"
        return "Making \(recipe.plural.lowercased())\(batches)"
    }

    // MARK: Recipes

    private func recipeRow(_ recipe: Recipe, workshop: Workshop) -> some View {
        let affordable = game.affordableBatches(recipe)
        let busy = !(workshop.recipe == recipe.id || (workshop.queued == 0 && workshop.ready == 0))
        let many = min(5, affordable)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ItemIcon(name: "item_\(recipe.output)", size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(recipe.amount == 1 ? recipe.name : "\(recipe.amount) \(recipe.plural)")
                        .font(Theme.label(15, weight: .semibold))
                    Text("\(Format.duration(recipe.seconds)) · sells for about \(recipe.value.lowerBound)–\(recipe.value.upperBound) · +\(recipe.xp) XP")
                        .font(Theme.label(12))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer(minLength: 4)
            }
            HStack(spacing: 6) {
                ForEach(recipe.inputs.sorted(by: { $0.key < $1.key }), id: \.key) { item, count in
                    ingredient(item, count)
                }
                Spacer(minLength: 4)
                ActionCapsule(title: "Make", enabled: affordable > 0 && !busy) { game.startRecipe(recipe, batches: 1) }
                if many > 1 {
                    ActionCapsule(title: "×\(many)", enabled: !busy, tint: Theme.gold) { game.startRecipe(recipe, batches: many) }
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .card()
    }

    private func ingredient(_ item: String, _ count: Int) -> some View {
        let have = game.inventoryItems[item] ?? 0
        return HStack(spacing: 3) {
            ItemIcon(name: "item_\(item)", size: 22)
            Text("\(count)")
                .font(Theme.number(13))
            Text("(\(have))")
                .font(Theme.label(11))
                .foregroundStyle(have >= count ? Theme.leafDark : Theme.danger)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(InsetPanel())
    }

    // MARK: Pick up

    @ViewBuilder
    private func pickUp(_ workshop: Workshop, _ definition: WorkshopDefinition) -> some View {
        let empty = workshop.ready == 0 && (definition.isAutomatic || workshop.queued == 0)
        if empty {
            Button {
                game.pickUpWorkshop()
            } label: {
                IconLabel("Pick it up (to move it)", symbol: "arrow.up.bin")
                    .font(Theme.display(14))
            }
            .buttonStyle(CandyButtonStyle(tint: .wood))
            .padding(.top, 4)
        }
    }
}
