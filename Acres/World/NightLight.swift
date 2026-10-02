import SpriteKit

/// The warm side of the night: pools of lamp and window light on the ground,
/// and fireflies over the meadow. Both sit above the day/night grade, so they
/// brighten the darkened world; both are pixel art (light in flat steps,
/// fireflies a few pixels big).
enum NightLight {
    /// A pool of light on the ground around something that glows at night.
    struct Pool {
        /// Radius in tiles.
        let radius: CGFloat
        /// How bright at the middle (0…1).
        let strength: CGFloat
        /// Where the middle sits, in tiles from the object's foot point.
        let offset: CGPoint
    }

    /// Lamps light the most; houses spill a little light from their windows.
    static func pool(for kind: String) -> Pool? {
        if kind == "prop_lamp_post" {
            return Pool(radius: 3.2, strength: 0.55, offset: CGPoint(x: 0, y: -0.2))
        }
        if kind == "prop_fair_lantern" {
            return Pool(radius: 2.2, strength: 0.45, offset: CGPoint(x: 0.2, y: -0.2))
        }
        if kind.hasPrefix("building_farmhouse") {
            return Pool(radius: 2.6, strength: 0.38, offset: CGPoint(x: 0.2, y: -0.4))
        }
        if kind.hasPrefix("building_") {
            return Pool(radius: 2.2, strength: 0.3, offset: CGPoint(x: 0, y: -0.3))
        }
        return nil
    }

    /// The pool as a node to hang under the glowing object. Its alpha is the
    /// night's light level (the chunk manager sets it, like the glows).
    @MainActor static func makePool(_ pool: Pool) -> SKNode {
        let holder = SKNode()
        holder.alpha = 0
        holder.position = CGPoint(x: pool.offset.x * World.tileSize, y: pool.offset.y * World.tileSize)
        holder.zPosition = ZLayer.nightLightOffset - 1
        let light = SKSpriteNode(texture: poolTexture)
        let width = pool.radius * 2 * World.tileSize
        light.size = CGSize(width: width, height: width * 0.78)  // the ground seen at an angle
        light.blendMode = .add
        light.alpha = pool.strength
        holder.addChild(light)
        return holder
    }

    /// Warm light fading out from the middle in flat rings.
    @MainActor private static let poolTexture: SKTexture = {
        let n = 96
        var bytes = [UInt8](repeating: 0, count: n * n * 4)
        for row in 0..<n {
            for col in 0..<n {
                let dx = (Double(col) + 0.5) / Double(n) * 2 - 1
                let dy = (Double(row) + 0.5) / Double(n) * 2 - 1
                let falloff = pow(max(0, 1 - (dx * dx + dy * dy).squareRoot()), 1.5)
                let stepped = (falloff * 7).rounded(.down) / 7
                let i = (row * n + col) * 4
                // Premultiplied: a warm lamplight orange.
                bytes[i] = UInt8(255 * stepped)
                bytes[i + 1] = UInt8(186 * stepped)
                bytes[i + 2] = UInt8(112 * stepped)
                bytes[i + 3] = UInt8(255 * stepped)
            }
        }
        let texture = RawImage.cgImage(rgba: bytes, width: n, height: n).map { SKTexture(cgImage: $0) } ?? SKTexture()
        texture.filteringMode = .nearest
        return texture
    }()

    /// Fireflies: tiny glowing specks drifting and blinking. Add it to the
    /// object layer (so they stay put in the world while the camera moves),
    /// then keep it over the visible area and set how many with `setFireflies`.
    @MainActor static func makeFireflies(in layer: SKNode) -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = fireflyTexture
        e.particleSize = CGSize(width: World.tileSize * 3 / 32, height: World.tileSize * 3 / 32)  // 3 art pixels
        e.particleBirthRate = 0
        e.particleLifetime = 5
        e.particleLifetimeRange = 2
        e.emissionAngleRange = .pi * 2
        e.particleSpeed = 7
        e.particleSpeedRange = 7
        e.particleAlpha = 1
        e.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 1, 0.25, 1, 0.4, 0],
                                                     times: [0, 0.15, 0.4, 0.6, 0.85, 1])
        e.particleBlendMode = .add
        e.zPosition = ZLayer.nightLightOffset + 150
        e.targetNode = layer
        layer.addChild(e)
        return e
    }

    /// Keeps the fireflies over what the camera sees; `amount` 0…1.
    @MainActor static func setFireflies(_ e: SKEmitterNode, amount: CGFloat, over visible: CGRect) {
        e.position = CGPoint(x: visible.midX, y: visible.midY)
        e.particlePositionRange = CGVector(dx: visible.width, dy: visible.height)
        e.particleBirthRate = 7 * amount
    }

    @MainActor private static let fireflyTexture: SKTexture = {
        // A bright yellow-green dot with a dimmer cross around it.
        let glow: [[UInt8]] = [[0, 90, 0], [90, 255, 90], [0, 90, 0]]
        var bytes = [UInt8](repeating: 0, count: 3 * 3 * 4)
        for row in 0..<3 {
            for col in 0..<3 {
                let a = Double(glow[row][col]) / 255
                let i = (row * 3 + col) * 4
                bytes[i] = UInt8(250 * a)
                bytes[i + 1] = UInt8(246 * a)
                bytes[i + 2] = UInt8(150 * a)
                bytes[i + 3] = glow[row][col]
            }
        }
        let texture = RawImage.cgImage(rgba: bytes, width: 3, height: 3).map { SKTexture(cgImage: $0) } ?? SKTexture()
        texture.filteringMode = .nearest
        return texture
    }()
}
