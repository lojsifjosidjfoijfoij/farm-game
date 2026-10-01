import SpriteKit

/// A light breeze in trees and plants, the pixel-art way: the trunk stays put
/// and the crown leans by whole texels, more towards the top, so every pixel
/// stays a crisp square. (Rotating the whole sprite smeared the pixels and was
/// too small to notice.)
enum WindSway {
    struct Style {
        /// How far the very top leans at most, in tiles (whatever the art's pixel size).
        let lean: CGFloat
        /// The share of the sprite, from the bottom, that stays still (the trunk).
        let root: Float
        /// How quickly it sways (radians per second).
        let speed: Float
    }

    static let tree = Style(lean: 0.1, root: 0.3, speed: 1.3)
    static let sapling = Style(lean: 0.08, root: 0.15, speed: 1.9)
    static let bush = Style(lean: 0.06, root: 0.25, speed: 1.6)
    static let plant = Style(lean: 0.06, root: 0.0, speed: 2.4)

    /// One shader for every swaying sprite; each sprite brings its own numbers.
    @MainActor private static let shader: SKShader = {
        let shader = SKShader(source: source)
        shader.attributes = [
            SKAttribute(name: "a_sway", type: .vectorFloat4),
            SKAttribute(name: "a_texel", type: .float),
        ]
        return shader
    }()

    /// Starts the breeze on a sprite, once its texture and size are set (call
    /// it again when they change).
    /// `seed` (e.g. the position) puts neighbours out of step, so gusts seem
    /// to move through them rather than everything swaying as one.
    @MainActor static func apply(_ style: Style, to sprite: SKSpriteNode, seed: CGPoint) {
        guard let texture = sprite.texture, sprite.size.width > 0 else { return }
        let width = max(1, texture.size().width)
        let texels = Float(style.lean * World.tileSize * width / sprite.size.width)
        let phase = Float(seed.x) * 0.031 + Float(seed.y) * 0.017
        sprite.shader = shader
        sprite.setValue(SKAttributeValue(vectorFloat4: SIMD4<Float>(texels, style.root, style.speed, phase)),
                        forAttribute: "a_sway")
        sprite.setValue(SKAttributeValue(float: Float(1 / width)), forAttribute: "a_texel")
    }

    @MainActor static func stop(_ sprite: SKSpriteNode) {
        sprite.shader = nil
    }

    /// Texture coordinates start at the bottom left. Each row is pushed
    /// sideways by a whole number of texels, growing with the height above
    /// the trunk; a slow sway plus a quicker flutter on top.
    private static let source = """
    void main() {
        vec2 uv = v_tex_coord;
        float h = clamp((uv.y - a_sway.y) / max(0.001, 1.0 - a_sway.y), 0.0, 1.0);
        float wind = sin(u_time * a_sway.z + a_sway.w) * 0.75
                   + sin(u_time * a_sway.z * 2.3 + a_sway.w * 1.7) * 0.25;
        uv.x -= floor(wind * a_sway.x * pow(h, 1.5) + 0.5) * a_texel;
        if (uv.x < 0.0 || uv.x > 1.0) {
            gl_FragColor = vec4(0.0);
        } else {
            gl_FragColor = texture2D(u_texture, uv) * v_color_mix.a;
        }
    }
    """
}
