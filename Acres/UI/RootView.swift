import SwiftUI

/// The whole screen: the SpriteKit world with the SwiftUI HUD on top.
struct RootView: View {
    @Bindable var game: GameController
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            GameView(game: game, showsStats: game.showsPerformanceStats, showsChunkBorders: game.showsChunkBorders)
                .ignoresSafeArea()

            HUDView(game: game)

            if let summary = game.welcome {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .transition(.opacity)
                WelcomeBackView(summary: summary) {
                    withAnimation(.easeOut(duration: 0.25)) { game.dismissWelcome() }
                }
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.3), value: game.welcome != nil)
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
        .alert(
            game.alert?.title ?? "",
            isPresented: Binding(get: { game.alert != nil }, set: { if !$0 { game.alert = nil } }),
            presenting: game.alert
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
    }
}
