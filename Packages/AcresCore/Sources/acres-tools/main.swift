// Developer tools for Acres.
//
//   swift run acres-tools assets > ../../docs/ASSETS.md
//
// Keep generated docs in sync with the manifest (a unit test checks this).

import AcresCore
import Foundation

let arguments = CommandLine.arguments.dropFirst()

switch arguments.first {
case "assets":
    print(AssetDocs.markdown(), terminator: "")
case "map-dump":
    // Debug: terrain rows (north first) followed by object lines, for previews.
    let map = HomeValleyMap.map
    let symbols: [Terrain: Character] = [.grass: ".", .dirt: "d", .gravel: "g", .asphalt: "a"]
    for y in stride(from: map.height - 1, through: 0, by: -1) {
        print(String((0..<map.width).map { symbols[map.terrain(at: TileCoord($0, y))]! }))
    }
    for object in map.objects {
        print("OBJ \(object.kind) \(object.position.x) \(object.position.y)")
    }
default:
    let message = "usage: acres-tools assets | map-dump\n"
    FileHandle.standardError.write(message.data(using: .utf8)!)
    exit(1)
}
