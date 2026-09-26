import Foundation

/// A sound or music file the game needs. Like visual assets, audio is looked
/// up by name; missing files simply stay silent until they are added.
public struct AudioSpec: Hashable, Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        case music, ambience, sfx

        public var title: String {
            switch self {
            case .music: "Music"
            case .ambience: "Ambience loops"
            case .sfx: "Sound effects"
            }
        }
    }

    public let name: String
    public let kind: Kind
    /// Must loop seamlessly.
    public let loops: Bool
    /// Rough target length.
    public let duration: String
    public let phase: Int
    public let notes: String
}

/// Every audio file the game needs (implemented in Phase 8; listed now so
/// music can be sourced early). Format: AAC `.m4a`, 44.1 kHz, stereo for
/// music/ambience, mono for effects, normalized to about -16 LUFS.
public enum AudioManifest {
    public static let all: [AudioSpec] = music + ambience + effects

    static func music(_ name: String, _ duration: String, _ notes: String) -> AudioSpec {
        AudioSpec(name: name, kind: .music, loops: true, duration: duration, phase: 8, notes: notes)
    }

    static func ambience(_ name: String, _ notes: String) -> AudioSpec {
        AudioSpec(name: name, kind: .ambience, loops: true, duration: "0:30–1:00", phase: 8, notes: notes)
    }

    static func sfx(_ name: String, loops: Bool = false, _ notes: String) -> AudioSpec {
        AudioSpec(name: name, kind: .sfx, loops: loops, duration: loops ? "2–5 s loop" : "< 2 s", phase: 8, notes: notes)
    }

    static let music: [AudioSpec] = [
        music("music_title", "1:30", "Title theme: warm acoustic guitar and soft piano, hopeful."),
        music("music_spring_day", "3:00", "Light fingerpicked guitar, flute, birdsong feel."),
        music("music_spring_evening", "3:00", "Gentle, slower variant of the spring theme."),
        music("music_summer_day", "3:00", "Sunny, lazy: ukulele or mandolin, light percussion."),
        music("music_summer_evening", "3:00", "Warm golden-hour guitar, cicadas feel."),
        music("music_autumn_day", "3:00", "Cozy, slightly melancholic: cello and guitar."),
        music("music_autumn_evening", "3:00", "Quiet piano and cello."),
        music("music_winter_day", "3:00", "Sparse piano, glockenspiel, crisp and calm."),
        music("music_winter_evening", "3:00", "Very soft piano by the fireplace."),
        music("music_night", "3:00", "Minimal, sleepy: soft pads and occasional piano notes (all seasons)."),
        music("music_rain", "3:00", "Mellow rainy-day piece, Rhodes piano."),
        music("music_town", "2:30", "Livelier market-day tune: accordion, guitar."),
        music("music_harvest_fair", "2:30", "Festive folk tune for the yearly harvest fair: fiddle, claps."),
    ]

    static let ambience: [AudioSpec] = [
        ambience("amb_birds_morning", "Morning birdsong chorus."),
        ambience("amb_meadow_day", "Light breeze, distant birds, insects."),
        ambience("amb_night_crickets", "Crickets and an occasional owl."),
        ambience("amb_wind_soft", "Soft wind through grass and leaves."),
        ambience("amb_wind_winter", "Colder, hollow wind."),
        ambience("amb_rain_light", "Light rain on leaves."),
        ambience("amb_rain_heavy", "Steady rain, distant thunder."),
        ambience("amb_forest", "Rustling forest canopy, woodpecker."),
        ambience("amb_lake", "Water lapping, ducks."),
        ambience("amb_town", "Distant chatter, footsteps, a bicycle bell."),
        ambience("amb_harbor", "Gulls, creaking ropes, water against piers."),
    ]

    static let effects: [AudioSpec] = [
        sfx("sfx_ui_tap", "Soft wooden click."),
        sfx("sfx_ui_open", "Paper unfold / panel open."),
        sfx("sfx_ui_close", "Paper fold / panel close."),
        sfx("sfx_plow", "Hoe into soil."),
        sfx("sfx_plant", "Seeds dropped, soft pat of soil."),
        sfx("sfx_water", "Short watering-can pour."),
        sfx("sfx_harvest_pop", "Satisfying pluck/pop."),
        sfx("sfx_coin", "Single bright coin."),
        sfx("sfx_coins_many", "Handful of coins (big sale)."),
        sfx("sfx_cash_register", "Old cash register ding."),
        sfx("sfx_level_up", "Short warm fanfare (guitar strum + chime)."),
        sfx("sfx_achievement", "Gentle chime."),
        sfx("sfx_axe_chop", "Axe into wood."),
        sfx("sfx_tree_fall", "Creak and soft thud of a falling tree."),
        sfx("sfx_saw", "Hand saw / sawmill blade."),
        sfx("sfx_chicken", "Hen cluck."),
        sfx("sfx_cow", "Soft moo."),
        sfx("sfx_sheep", "Baa."),
        sfx("sfx_pig", "Oink."),
        sfx("sfx_goat", "Bleat."),
        sfx("sfx_horse", "Nicker."),
        sfx("sfx_dog", "Friendly woof."),
        sfx("sfx_truck_door", "Old truck door slam."),
        sfx("sfx_engine_start", "Old engine cranking and starting."),
        sfx("sfx_engine_loop", loops: true, "Engine hum; pitch and volume follow speed."),
        sfx("sfx_tires_gravel", loops: true, "Tires crunching on gravel/dirt."),
        sfx("sfx_tires_asphalt", loops: true, "Tires rolling on asphalt."),
        sfx("sfx_horn", "Friendly old horn."),
        sfx("sfx_bump", "Suspension thump over a bump."),
        sfx("sfx_fuel_pump", "Fuel nozzle click and pour."),
        sfx("sfx_birds_flyoff", "Flutter of wings."),
        sfx("sfx_mill", loops: true, "Creaking windmill / millstone."),
        sfx("sfx_notification", "Soft bell for 'ready' notifications."),
    ]
}
