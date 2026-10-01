import SpriteKit
import AcresCore

/// Draws the ground: one sprite per chunk, from tileable pixel-art textures
/// (grass, dirt, gravel, asphalt) on the pixel-art grid.
///
/// Each chunk sprite's own texture is a tiny "splat map" (4 texels per tile)
/// saying how much dirt / gravel / asphalt is where (red / green / blue).
/// The shader picks one texture per pixel, never a blend (blends are the
/// in-between colours that make pixel art look blurry), with ragged edges
/// pushed through noise, a darker rim on the path side and grass tufts
/// poking over it. Cheap: one draw call and a 64×64 texture per chunk.
@MainActor
final class TerrainRenderer {
    static let texelsPerTile = 4
    /// Tiles covered by one repeat of a detail texture (see the manifest): a
    /// whole chunk, so the pattern doesn't visibly repeat on screen.
    static let detailTiles = 16

    private let shader: SKShader
    private var splatCache: [ChunkCoord: SKTexture] = [:]
    private let grassTint = SKUniform(name: "u_grass_tint", vectorFloat3: SIMD3<Float>(1, 1, 1))
    private let snow = SKUniform(name: "u_snow", float: 0)
    private var shownSeason: (Season, Double)?

    init(assets: AssetCatalog) {
        shader = SKShader(source: Self.shaderSource)
        shader.uniforms = [
            SKUniform(name: "u_grass", texture: assets.texture("terrain_grass")),
            SKUniform(name: "u_dirt", texture: assets.texture("terrain_dirt")),
            SKUniform(name: "u_gravel", texture: assets.texture("terrain_gravel")),
            SKUniform(name: "u_asphalt", texture: assets.texture("terrain_asphalt")),
            SKUniform(name: "u_variation", texture: assets.texture("terrain_variation")),
            // Must be a whole number so the pattern continues across chunk edges.
            SKUniform(name: "u_detail_repeat", float: Float(WorldMap.chunkSize / Self.detailTiles)),
            // The pixel-art grid: art pixels across one chunk (32 per tile).
            SKUniform(name: "u_pixels", float: Float(Double(WorldMap.chunkSize) * PixelArt.pixelsPerTile)),
            grassTint,
            snow,
        ]
    }

    /// The season's colors: fresh spring green, golden autumn, frosty
    /// winter (and snow lying on snowy days).
    func setSeason(_ season: Season, snowCover: Double) {
        if let shown = shownSeason, shown.0 == season, shown.1 == snowCover { return }
        shownSeason = (season, snowCover)
        grassTint.vectorFloat3Value = switch season {
        case .spring: SIMD3<Float>(1.02, 1.08, 0.94)
        case .summer: SIMD3<Float>(1, 1, 1)
        case .autumn: SIMD3<Float>(1.16, 0.98, 0.7)
        case .winter: SIMD3<Float>(0.92, 0.96, 1.0)
        }
        snow.floatValue = Float(snowCover)
    }

    func makeGroundNode(for chunk: ChunkCoord, in map: WorldMap) -> SKSpriteNode {
        let node = SKSpriteNode(texture: splatTexture(for: chunk, in: map),
                                size: CGSize(width: World.chunkSize, height: World.chunkSize))
        node.anchorPoint = .zero
        node.position = CGPoint(x: CGFloat(chunk.x) * World.chunkSize, y: CGFloat(chunk.y) * World.chunkSize)
        node.shader = shader
        node.blendMode = .replace  // the ground is opaque: skip blending
        node.zPosition = ZLayer.ground
        return node
    }

    private func splatTexture(for chunk: ChunkCoord, in map: WorldMap) -> SKTexture {
        if let cached = splatCache[chunk] { return cached }
        let n = WorldMap.chunkSize * Self.texelsPerTile
        let rect = map.rect(of: chunk)
        var bytes = [UInt8](repeating: 255, count: n * n * 4)
        for row in 0..<n {
            for col in 0..<n {
                // Image rows run top (north) to bottom (south).
                let x = rect.minX + (Double(col) + 0.5) / Double(Self.texelsPerTile)
                let y = rect.maxY - (Double(row) + 0.5) / Double(Self.texelsPerTile)
                let c = map.coverage(at: Vec2(x, y), radius: 0.6, samples: 4)
                let i = (row * n + col) * 4
                bytes[i] = UInt8((c.dirt * 255).rounded())
                bytes[i + 1] = UInt8((c.gravel * 255).rounded())
                bytes[i + 2] = UInt8((c.asphalt * 255).rounded())
            }
        }
        let texture: SKTexture
        if let image = RawImage.cgImage(rgbx: bytes, width: n, height: n) {
            texture = SKTexture(cgImage: image)
        } else {
            texture = SKTexture()
        }
        texture.filteringMode = .linear
        splatCache[chunk] = texture
        return texture
    }

    /// SpriteKit fragment shader (GLSL-style; SpriteKit translates it to Metal).
    /// Built-ins: u_texture (the splat map), v_tex_coord (0…1 across the chunk).
    static let shaderSource = """
    void main() {
        // Snap to the pixel-art grid; the detail textures have exactly one
        // texel per art pixel, so every pixel is a texel, crisp.
        vec2 uv = (floor(v_tex_coord * u_pixels) + 0.5) / u_pixels;
        vec2 d = fract(uv * u_detail_repeat);
        vec3 splat = texture2D(u_texture, uv).rgb;
        float large = texture2D(u_variation, uv).r;
        float medium = texture2D(u_variation, fract(uv * 4.0)).g;

        // Half the meadow uses the grass texture shifted by half, to break up repeats.
        vec2 dg = large > 0.5 ? fract(d + vec2(0.5, 0.5)) : d;
        vec3 grass = texture2D(u_grass, dg).rgb;
        float tuft = dot(grass, vec3(0.299, 0.587, 0.114));
        grass *= u_grass_tint;
        // Sunny and shady patches, in flat steps rather than gradients.
        grass *= large > 0.66 ? 1.05 : (large < 0.3 ? 0.94 : 1.0);

        // Ragged edges: noise pushes each border in and out.
        float edge = (large - 0.5) * 0.45 + (medium - 0.5) * 0.35;
        float tDirt = splat.r + edge - 0.5;
        float tGravel = splat.g + edge * 0.6 - 0.5;
        float tAsphalt = splat.b + edge * 0.15 - 0.5;

        vec3 color = grass;
        if (tDirt > 0.0) {
            // A darker rim along the path, with bright grass tufts poking over it.
            bool poke = tDirt < 0.05 && tuft > 0.62;
            float rim = tDirt < 0.03 ? 0.72 : (tDirt < 0.065 ? 0.86 : 1.0);
            color = poke ? grass : texture2D(u_dirt, d).rgb * rim;
        } else if (tDirt > -0.03) {
            color = grass * 0.84;  // the grass just beside the path, a touch shaded
        }
        if (tGravel > 0.0) {
            color = texture2D(u_gravel, d).rgb * (tGravel < 0.04 ? 0.8 : 1.0);
        }
        if (tAsphalt > 0.0) {
            color = texture2D(u_asphalt, d).rgb * (tAsphalt < 0.03 ? 0.82 : 1.0);
        }
        // Snow settles on grass and soil first, in patches at the edges.
        float snowy = u_snow * (0.7 + 0.6 * medium) - (tAsphalt > 0.0 ? 0.6 : 0.0) - (tGravel > 0.0 ? 0.3 : 0.0);
        if (snowy > 0.5) {
            color = medium > 0.55 ? vec3(0.95, 0.96, 1.0) : vec3(0.86, 0.9, 0.97);
        }
        gl_FragColor = vec4(color, 1.0);
    }
    """
}
