import CoreGraphics
import Foundation
import AcresCore

/// How the player steers (Settings).
enum DriveControls: String, CaseIterable, Identifiable {
    case joystick
    case tapToDrive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .joystick: "Joystick"
        case .tapToDrive: "Tap to drive"
        }
    }

    var hint: String {
        switch self {
        case .joystick: "Drag anywhere to steer."
        case .tapToDrive: "Tap where you want to go."
        }
    }
}

/// The on-screen joystick, in screen points.
struct JoystickVisual: Equatable {
    var origin: CGPoint
    var knob: CGPoint
}

extension GameController {
    /// How far the knob can travel from where the thumb went down.
    static let joystickRadius: CGFloat = 60

    var physics: TruckPhysics { TruckPhysics(map: map, tuning: balance.driving, woodland: simulation.state.woodland) }
    var truckState: TruckState { simulation.state.truck }
    var truckSurface: Terrain { physics.surface(at: simulation.state.truck.position) }
    var cargoFraction: Double { Double(cargoCount) / Double(max(1, balance.truckCargoCapacity)) }

    // MARK: Getting in and out

    func startDriving() {
        guard !isDriving, welcome == nil else { return }
        endPaint()
        isDriving = true
        motion = TruckMotion()
        showsSeedPicker = false
        dismissInspection()
        Haptics.tap()
    }

    func park() {
        guard isDriving else { return }
        isDriving = false
        motion = TruckMotion()
        autopilot = nil
        joystickInput = nil
        joystick = nil
        destination = nil
        refreshTruck()
        save()
        Haptics.tap()
    }

    // MARK: Steering

    func joystickBegan(at point: CGPoint) {
        guard isDriving else { return }
        joystick = JoystickVisual(origin: point, knob: point)
        joystickInput = .idle
        autopilot = nil
        destination = nil
    }

    func joystickMoved(to point: CGPoint) {
        guard var visual = joystick else { return }
        let dx = point.x - visual.origin.x, dy = point.y - visual.origin.y
        let length = hypot(dx, dy)
        let radius = Self.joystickRadius
        visual.knob = length > radius
            ? CGPoint(x: visual.origin.x + dx / length * radius, y: visual.origin.y + dy / length * radius)
            : point
        joystick = visual
        // Screen y points down; the map's y points up.
        joystickInput = length < 6
            ? .idle
            : DriveInput(direction: Vec2(Double(dx), Double(-dy)), throttle: Double(min(1, length / radius)))
    }

    func joystickEnded() {
        joystick = nil
        joystickInput = nil
    }

    /// Tap-to-drive: plans a route and lets the autopilot take the wheel.
    func driveTo(_ target: Vec2) {
        guard isDriving else { return }
        guard let path = Pathfinder.path(on: map, woodland: simulation.state.woodland,
                                         from: simulation.state.truck.position, to: target) else {
            showMessage("Can't find a way there.")
            return
        }
        autopilot = Autopilot(path: path)
        destination = path.last
        Haptics.selection()
    }

    // MARK: Per frame

    func updateDriving(dt: TimeInterval) {
        guard isDriving else { return }
        var input = joystickInput ?? .idle
        if var pilot = autopilot {
            if let next = pilot.input(for: simulation.state.truck) {
                input = next
                autopilot = pilot
            } else {
                autopilot = nil
                destination = nil
            }
        }
        var truck = simulation.state.truck
        let events = physics.step(&truck, &motion, input: input, dt: dt)
        let moved = truck
        simulation.modify { $0.truck = moved }
        for event in events {
            switch event {
            case .bump(let speed):
                Haptics.bump(intensity: min(1, speed / balance.driving.maxSpeedAsphalt))
                autopilot = nil
                destination = nil
            case .ranOutOfFuel:
                showMessage("Out of fuel! The truck limps along. Fill up at the village gas station.")
            }
        }
        refreshTruck()
    }

    /// Copies truck values the HUD shows (only when they change).
    func refreshTruck() {
        let truck = simulation.state.truck
        let fraction = max(0, min(1, truck.fuel / balance.driving.fuelCapacity))
        if abs(fraction - fuelFraction) >= 0.005 || (fraction == 0 && fuelFraction != 0) { fuelFraction = fraction }
        if cargoItems != truck.cargo.items {
            cargoItems = truck.cargo.items
            cargoCount = truck.cargoCount
        }
        let stopped = !isDriving || motion.isStopped
        let shop = stopped ? ShopCatalog.shop(at: truck.position) : nil
        if shop != nearbyShop {
            nearbyShop = shop
            if shop?.kind == .market { advanceTutorial(.arrivedAtMarket) }
        }
        let atFarm = trading.truckIsAtFarm(simulation.state)
        if atFarm != truckAtFarm { truckAtFarm = atFarm }
    }

    func setDriveControls(_ controls: DriveControls) {
        driveControls = controls
        UserDefaults.standard.set(controls.rawValue, forKey: Settings.controlsKey)
        autopilot = nil
        destination = nil
        joystick = nil
        joystickInput = nil
    }
}
