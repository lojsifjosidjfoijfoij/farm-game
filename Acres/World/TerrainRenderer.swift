import SpriteKit
import AcresCore

/// Draws the ground: one sprite per chunk, blended on the GPU from tileable
/// detail textures (grass, dirt, gravel, asphalt).
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
        ]
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
        vec2 uv = v_tex_coord;
        vec2 d1 = fract(uv * u_detail_repeat);
        vec2 d2 = fract(uv * (u_detail_repeat - 1.0) + vec2(0.37, 0.61));

        vec3 splat = texture2D(u_texture, uv).rgb;
        float large = texture2D(u_variation, uv).r;
        float medium = texture2D(u_variation, d1).g;

        // Two scales of each texture, mixed by large-scale noise, hide repetition.
        vec3 grass = mix(texture2D(u_grass, d1).rgb, texture2D(u_grass, d2).rgb, large);
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
        gl_FragColor = vec4(color, 1.0);
    }
    """
}
