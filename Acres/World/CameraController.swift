import SpriteKit

/// Smooth top-down camera: drag to pan (with inertia), pinch to zoom around the
/// fingers, and gliding focus on a point (e.g. the truck). Clamped to the world.
///
/// `zoom` is world points per screen point: bigger = further away.
@MainActor
final class CameraController {
    let camera: SKCameraNode
    var worldBounds: CGRect {
        didSet { clampCenter(); apply() }
    }
    var viewSize: CGSize = CGSize(width: 844, height: 390) {
        didSet {
            // SpriteKit can briefly report a zero size before layout; ignore it,
            // or the zoom limits would collapse.
            guard viewSize.width > 1, viewSize.height > 1 else {
                viewSize = oldValue
                return
            }
            zoom = clamp(zoom, minZoom, maxZoom)
            clampCenter()
            apply()
        }
    }
    private(set) var center: CGPoint
    private(set) var zoom: CGFloat

    // How many tiles fit across the screen's short side (its height, held
    // sideways) at the zoom limits.
    static let closestTilesAcross: CGFloat = 5.5
    static let farthestTilesAcross: CGFloat = 14
    static let defaultTilesAcross: CGFloat = 9

    private var velocity = CGVector.zero      // inertia, world points / s
    private var isDragging = false
    private var focusTarget: CGPoint?
    private var focusVelocity = CGVector.zero
    /// While set (driving), the camera trails this point every frame.
    private var followTarget: CGPoint?
    /// Friction for inertia (per second). Higher = stops sooner.
    private let friction: CGFloat = 4.5

    init(camera: SKCameraNode, worldBounds: CGRect, center: CGPoint) {
        self.camera = camera
        self.worldBounds = worldBounds
        self.center = center
        self.zoom = Self.defaultTilesAcross * World.tileSize / 390
        apply()
    }

    private var shortSide: CGFloat { max(min(viewSize.width, viewSize.height), 1) }
    var minZoom: CGFloat { Self.closestTilesAcross * World.tileSize / shortSide }
    var maxZoom: CGFloat { Self.farthestTilesAcross * World.tileSize / shortSide }

    /// The part of the world currently on screen.
    var visibleRect: CGRect {
        let w = viewSize.width * zoom, h = viewSize.height * zoom
        return CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)
    }

    // MARK: Input

    func beginDrag() {
        guard followTarget == nil else { return }
        isDragging = true
        velocity = .zero
        focusTarget = nil
    }

    /// `delta` is the finger movement in screen points (UIKit: y down).
    func drag(byScreenDelta delta: CGPoint) {
        guard followTarget == nil else { return }
        center.x -= delta.x * zoom
        center.y += delta.y * zoom
        clampCenter()
        apply()
    }

    func endDrag(screenVelocity: CGPoint) {
        isDragging = false
        velocity = CGVector(dx: -screenVelocity.x * zoom, dy: screenVelocity.y * zoom)
        // Cap the fling so a flick doesn't throw the camera across the valley.
        let maxSpeed = viewSize.width * zoom * 3
        let speed = hypot(velocity.dx, velocity.dy)
        if speed > maxSpeed {
            velocity.dx *= maxSpeed / speed
            velocity.dy *= maxSpeed / speed
        }
    }

    /// Multiplies the zoom, keeping the world point under `screenPoint` fixed.
    func zoom(by factor: CGFloat, around screenPoint: CGPoint) {
        focusTarget = nil
        let before = worldPoint(fromScreen: screenPoint)
        zoom = clamp(zoom * factor, minZoom, maxZoom)
        let after = worldPoint(fromScreen: screenPoint)
        center.x += before.x - after.x
        center.y += before.y - after.y
        clampCenter()
        apply()
    }

    func setZoom(_ value: CGFloat) {
        zoom = clamp(value, minZoom, maxZoom)
        clampCenter()
        apply()
    }

    /// Glides to a point (or jumps there when not animated).
    func focus(on point: CGPoint, animated: Bool) {
        velocity = .zero
        if animated {
            focusTarget = point
        } else {
            focusTarget = nil
            center = point
            clampCenter()
            apply()
        }
    }

    func worldPoint(fromScreen p: CGPoint) -> CGPoint {
        CGPoint(x: center.x + (p.x - viewSize.width / 2) * zoom,
                y: center.y - (p.y - viewSize.height / 2) * zoom)
    }

    /// Keeps the camera on a moving point (the truck); nil stops following.
    func follow(_ point: CGPoint?) {
        followTarget = point
        if point != nil {
            focusTarget = nil
            velocity = .zero
            isDragging = false
        }
    }

    var isFollowing: Bool { followTarget != nil }

    // MARK: Per frame

    func update(dt: TimeInterval) {
        let t = CGFloat(dt)
        guard t > 0 else { return }
        if let target = followTarget {
            center.x = Self.smoothDamp(center.x, target.x, &focusVelocity.dx, smoothTime: 0.22, dt: t)
            center.y = Self.smoothDamp(center.y, target.y, &focusVelocity.dy, smoothTime: 0.22, dt: t)
            clampCenter()
            apply()
        } else if let target = focusTarget {
            center.x = Self.smoothDamp(center.x, target.x, &focusVelocity.dx, smoothTime: 0.35, dt: t)
            center.y = Self.smoothDamp(center.y, target.y, &focusVelocity.dy, smoothTime: 0.35, dt: t)
            if hypot(center.x - target.x, center.y - target.y) < 0.5 {
                center = target
                focusTarget = nil
                focusVelocity = .zero
            }
            clampCenter()
            apply()
        } else if !isDragging, velocity != .zero {
            center.x += velocity.dx * t
            center.y += velocity.dy * t
            let decay = exp(-friction * t)
            velocity.dx *= decay
            velocity.dy *= decay
            if hypot(velocity.dx, velocity.dy) < 4 { velocity = .zero }
            let before = center
            clampCenter()
            // Stop sliding along an axis that hit the edge.
            if before.x != center.x { velocity.dx = 0 }
            if before.y != center.y { velocity.dy = 0 }
            apply()
        }
    }

    // MARK: Helpers

    private func clampCenter() {
        let halfW = viewSize.width * zoom / 2, halfH = viewSize.height * zoom / 2
        if worldBounds.width <= halfW * 2 {
            center.x = worldBounds.midX
        } else {
            center.x = clamp(center.x, worldBounds.minX + halfW, worldBounds.maxX - halfW)
        }
        if worldBounds.height <= halfH * 2 {
            center.y = worldBounds.midY
        } else {
            center.y = clamp(center.y, worldBounds.minY + halfH, worldBounds.maxY - halfH)
        }
    }

    private func apply() {
        camera.position = center
        camera.setScale(zoom)
    }

    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { min(max(v, lo), hi) }

    /// Critically damped spring toward `target` (Game Programming Gems 4).
    static func smoothDamp(_ current: CGFloat, _ target: CGFloat, _ velocity: inout CGFloat, smoothTime: CGFloat, dt: CGFloat) -> CGFloat {
        let omega = 2 / max(smoothTime, 0.0001)
        let x = omega * dt
        let decay = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)
        let change = current - target
        let temp = (velocity + omega * change) * dt
        velocity = (velocity - omega * temp) * decay
        return target + (change + temp) * decay
    }
}
