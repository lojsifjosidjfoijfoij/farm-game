import SwiftUI
import AcresCore

/// The whole screen: the SpriteKit world with the SwiftUI HUD on top.
struct RootView: View {
    @Bindable var game: GameController
    @Environment(\.scenePhase) private var scenePhase
    /// The title screen, once per launch.
    @State private var showsTitle = true

    var body: some View {
        ZStack {
            GameView(game: game, showsStats: game.showsPerformanceStats, showsChunkBorders: game.showsChunkBorders)
                .ignoresSafeArea()

            HUDView(game: game)

            if let sleep = game.sleep {
                // Night falls, the clock spins, morning comes.
                Color(red: 0.05, green: 0.06, blue: 0.14)
                    .opacity(sleep.darkness * 0.92)
                    .ignoresSafeArea()
                    .allowsHitTesting(true)
                VStack(spacing: 6) {
                    HUDIcon(name: "ui_icon_time_night", size: 72)
                        .shadow(color: Theme.goldLight.opacity(0.6), radius: 16, x: 0, y: 0)
                    OutlinedTitle(text: "Zzz…", size: 38, outline: Color(red: 0.1, green: 0.12, blue: 0.3))
                }
                .opacity(sleep.darkness)
            }

            if let report = game.weeklyReport, game.welcome == nil, game.sleep == nil {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .transition(.opacity)
                FittedCard {
                    WeeklyReportCard(report: report) {
                        withAnimation(.easeOut(duration: 0.25)) { game.weeklyReport = nil }
                    }
                }
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }

            if let card = game.levelUpCard, game.welcome == nil, game.sleep == nil {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                FittedCard {
                    LevelUpCardView(card: card) {
                        withAnimation(.easeOut(duration: 0.25)) { game.dismissLevelUp() }
                    }
                }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }

            if let card = game.rankUpCard, game.levelUpCard == nil, game.welcome == nil, game.sleep == nil {
                Color.black.opacity(card.isFinale ? 0.45 : 0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                FittedCard {
                    if card.isFinale {
                        FinaleCardView(stats: game.farmStats) {
                            withAnimation(.easeOut(duration: 0.3)) { game.dismissRankUp() }
                        }
                    } else {
                        RankUpCardView(card: card, next: FarmRanks.next(after: card.rank.id)) {
                            withAnimation(.easeOut(duration: 0.25)) { game.dismissRankUp() }
                        }
                    }
                }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }

            if let project = game.openedProject, game.levelUpCard == nil, game.rankUpCard == nil, game.welcome == nil,
               game.sleep == nil {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                FittedCard {
                    ProjectOpenedCardView(project: project) { goSee in
                        withAnimation(.easeOut(duration: 0.25)) { game.dismissOpenedProject(goSee: goSee) }
                    }
                }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }

            if let summary = game.welcome {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .transition(.opacity)
                FittedCard {
                    WelcomeBackView(summary: summary) {
                        withAnimation(.easeOut(duration: 0.25)) { game.dismissWelcome() }
                    }
                }
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }

            if showsTitle {
                TitleScreenView {
                    withAnimation(.easeInOut(duration: 0.6)) { showsTitle = false }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.08)))
            }
        }
        .animation(.easeOut(duration: 0.3), value: game.welcome != nil)
        .animation(.easeOut(duration: 0.3), value: game.weeklyReport)
        .animation(.easeOut(duration: 0.3), value: game.levelUpCard)
        .animation(.easeOut(duration: 0.3), value: game.rankUpCard)
        .animation(.easeOut(duration: 0.3), value: game.openedProject)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onChange(of: scenePhase) { _, newPhase in
            game.scenePhaseChanged(to: newPhase)
        }
        .sheet(isPresented: $game.showsDebugPanel) {
            DebugPanelView(game: game)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $game.showsInventory) {
            InventoryView(game: game)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $game.showsGoals) {
            GoalsView(game: game)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $game.showsRoadmap) {
            LevelRoadmapView(game: game)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $game.showsBusiness) {
            BusinessView(game: game)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $game.showsStore) {
            StoreView(game: game)
                .presentationDetents([.large])
        }
        .sheet(item: $game.openWorkshop) { sheet in
            WorkshopView(game: game, sheet: sheet)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $game.openShop) { shop in
            ShopView(game: game, shop: shop)
                .presentationDetents([.medium, .large])
        }
        // Save trouble at launch, on a paper card over everything (the title screen too).
        .paperConfirm(game.alert?.title ?? "",
                      isPresented: Binding(get: { game.alert != nil }, set: { if !$0 { game.alert = nil } }),
                      message: game.alert?.message, confirmTitle: "OK", cancelTitle: nil) {}
    }
}
