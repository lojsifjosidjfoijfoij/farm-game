import SpriteKit
import AcresCore

/// Draws the ground: one sprite per chunk, blended on the GPU from tileable
/// detail textures (grass, dirt, gravel, asphalt), on the pixel-art grid.
///
/// Each chunk sprite's own texture is a tiny "splat map" (4 texels per tile)
/// saying how much dirt / gravel / asphalt is where (red / green / blue).
/// The shader mixes the detail textures with those weights and pushes the
/// edges through noise, so borders look organic and painted instead of
/// tile-shaped. Cheap: one draw call and a 64×64 texture per chunk.
@MainActor
final class TerrainRenderer {
    static let texelsPerTile = 4
    /// Tiles covered by one repeat of a detail texture (see the manifest).
    static let detailTiles = 4

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
        // Snap to the pixel-art grid, so the ground (edges and all) is made of
        // the same crisp pixels as everything standing on it.
        vec2 uv = (floor(v_tex_coord * u_pixels) + 0.5) / u_pixels;
        vec2 d1 = fract(uv * u_detail_repeat);
        vec2 d2 = fract(uv * (u_detail_repeat - 1.0) + vec2(0.37, 0.61));

        vec3 splat = texture2D(u_texture, uv).rgb;
        float large = texture2D(u_variation, uv).r;
        float medium = texture2D(u_variation, d1).g;

        // Two scales of each texture, mixed by large-scale noise, hide repetition.
        vec3 grass = mix(texture2D(u_grass, d1).rgb, texture2D(u_grass, d2).rgb, large) * u_grass_tint;
        vec3 dirt = mix(texture2D(u_dirt, d1).rgb, texture2D(u_dirt, d2).rgb, large);
        vec3 gravel = texture2D(u_gravel, d1).rgb;
        vec3 asphalt = texture2D(u_asphalt, d1).rgb;

        // Noisy thresholds turn soft blurry weights into organic, painted edges.
        float edge = (large - 0.5) * 0.45 + (medium - 0.5) * 0.35;
        float wDirt = smoothstep(0.32, 0.68, splat.r + edge);
        float wGravel = smoothstep(0.36, 0.64, splat.g + edge * 0.6);
        float wAsphalt = smoothstep(0.44, 0.56, splat.b + edge * 0.15);

        vec3 color = grass;
        color = mix(color, dirt, wDirt);
        color = mix(color, gravel, wGravel);
        color = mix(color, asphalt, wAsphalt);
        // Gentle large-scale light variation, like cloud-dappled fields.
        color *= 0.93 + 0.14 * large;
        // Snow settles on grass and soil first, patchy at the edges.
        float snowy = clamp(u_snow * (0.7 + 0.6 * medium) - wAsphalt * 0.6 - wGravel * 0.3, 0.0, 1.0);
        color = mix(color, vec3(0.93, 0.95, 0.99), snowy);
        gl_FragColor = vec4(color, 1.0);
    }
    """
}
