"""Renders Acres art from the Blender models into the app's asset catalog.

    python3 art/blender/render.py               # everything
    python3 art/blender/render.py building_barn_old   # just these (asset names or prefixes)

Previews (the bare sprites) also go to art/blender/.renders/preview/.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

import acres_art as art  # noqa: E402
from frames import frame  # noqa: E402,F401  (live.py uses render.frame too)
import models  # noqa: E402
import models_farm as farm  # noqa: E402
import models_people as people  # noqa: E402
import models_animals as animals  # noqa: E402
import models_village as village  # noqa: E402

PREVIEW = os.environ.get("ACRES_ART_PREVIEW") or os.path.join(os.path.dirname(__file__), ".renders", "preview")


FLAT = {"outline": False, "top_down": True}
GLOW = {"outline": False, "soft": True}

# name → (builder, render options).
ASSETS = {
    "building_farmhouse_t0": (models.farmhouse_t0, {}),
    "building_farmhouse_t0_lights": (lambda: models.farmhouse_t0(night=True), GLOW),
    "building_barn_old": (models.barn_old, {}),
    **{f"tree_oak_{season}": ((lambda s=season: models.oak(s)), {}) for season in ("spring", "summer", "autumn", "winter")},
    **{f"tree_pine_{season}": ((lambda s=season: models.pine(s)), {}) for season in ("spring", "summer", "autumn", "winter")},
    "tree_oak_young": (lambda: models.young_tree("oak"), {}),
    "tree_birch_young": (lambda: models.young_tree("birch"), {}),
    "nature_bush_a": (lambda: models.bush(wide=False), {}),
    "nature_bush_b": (lambda: models.bush(wide=True), {}),
    "nature_rock_small": (lambda: models.rock(large=False), {}),
    "nature_rock_large": (lambda: models.rock(large=True), {}),
    "tree_stump": (models.stump, {}),
    "nature_grass_tuft_a": (lambda: models.grass_tuft(False), {"outline": False}),
    "nature_grass_tuft_b": (lambda: models.grass_tuft(True), {"outline": False}),
    **{f"crop_wheat_stage{k}": ((lambda k=k: models.wheat(k)), {} if k else {"outline": False}) for k in range(5)},
    "prop_well": (models.well, {}),
    "prop_hay_bale": (models.hay_bale, {}),
    "prop_crate": (models.crate, {}),
    "prop_log_pile": (models.log_pile, {}),
    "prop_mailbox": (models.mailbox, {}),
    "prop_lamp_post": (models.lamp_post, {}),
    "prop_lamp_post_lights": (lambda: models.lamp_post(night=True), GLOW),
    "prop_fence_wood_h": (lambda: models.fence("h"), {}),
    "prop_fence_wood_h_broken": (lambda: models.fence("broken"), {}),
    "prop_fence_wood_v": (lambda: models.fence("v"), {}),
    "prop_fence_wood_post": (lambda: models.fence("post"), {}),
    **{f"crop_{c}_stage{k}": ((lambda c=c, k=k: farm.crop(c, k)), {} if k else {"outline": False})
       for c in farm.CROPS for k in range(5)},
    **{f"tree_birch_{s}": ((lambda s=s: farm.birch(s)), {}) for s in farm.SEASONS},
    **{f"tree_maple_{s}": ((lambda s=s: farm.maple(s)), {}) for s in farm.SEASONS},
    **{f"tree_{k}_{s}": ((lambda k=k, s=s: farm.fruit_tree(k, s)), {}) for k in ("apple", "cherry") for s in farm.SEASONS},
    **{f"tree_{k}_fruit": ((lambda k=k: farm.fruit_tree(k, overlay=True)), {}) for k in ("apple", "cherry")},
    "tree_pine_young": (farm.young_pine, {}),
    "tree_maple_young": (lambda: farm.maple(young=True), {}),
    "tree_apple_young": (lambda: farm.fruit_tree("apple", young=True), {}),
    "tree_cherry_young": (lambda: farm.fruit_tree("cherry", young=True), {}),
    **{f"tree_{k}_sapling": ((lambda k=k: farm.sapling(k)), {}) for k in ("oak", "birch", "pine", "maple", "apple", "cherry")},
    "tree_felled": (farm.felled, {}),
    **{f"building_farmhouse_t{t}": ((lambda t=t: farm.farmhouse(t)), {}) for t in (1, 2, 3)},
    **{f"building_farmhouse_t{t}_lights": ((lambda t=t: farm.farmhouse(t, night=True)), GLOW) for t in (1, 2, 3)},
    "building_coop": (farm.coop, {}),
    "building_storage_shed": (farm.storage_shed, {}),
    "building_silo": (farm.silo, {}),
    **{f"building_{k}": ((lambda k=k: farm._shelter(k)), {}) for k in ("pigsty", "sheep_shelter", "goat_shed")},
    "prop_sign_for_sale": (lambda: farm.sign("for_sale"), {}),
    "prop_sign_repair": (lambda: farm.sign("repair"), {}),
    "prop_sprinkler": (farm.sprinkler, {}),
    "prop_sprinkler_pro": (lambda: farm.sprinkler(pro=True), {}),
    "prop_water_trough": (farm.water_trough, {}),
    "prop_water_trough_empty": (lambda: farm.water_trough(full=False), {}),
    "prop_feeder": (farm.feeder, {}),
    "prop_bench": (farm.bench, {}),
    "prop_signpost": (farm.signpost, {}),
    **{f"nature_flowers_{c}": ((lambda c=c: farm.flowers(c)), {}) for c in ("yellow", "white", "purple")},
    **{f"character_farmer_{f}_{p}": ((lambda f=f, p=p: people.person("farmer", f, p)), {})
       for f in ("down", "up", "side") for p in people.FARMER_POSES},
    **{f"character_worker{n}_{f}_{p}": ((lambda n=n, f=f, p=p: people.person(f"worker{n}", f, p)), {})
       for n in (1, 2, 3) for f in ("down", "up", "side") for p in people.WORKER_POSES},
    **{f"character_villager{n}_{f}_{p}": ((lambda n=n, f=f, p=p: people.person(f"villager{n}", f, p)), {})
       for n in (1, 2, 3) for f in ("down", "up", "side") for p in people.VILLAGER_POSES},
    **{f"animal_{a}_{p}": ((lambda a=a, p=p: animals.animal(a, p)), {}) for a in animals.ANIMALS for p in animals.POSES},
    **{f"building_house_village_{s}": ((lambda s=s: village.village_house(s)), {}) for s in "abc"},
    **{f"building_house_village_{s}_lights": ((lambda s=s: village.village_house(s, night=True)), GLOW) for s in "abc"},
    **{f"building_{n}": (f, {}) for n, f in (("seed_shop", village.seed_shop), ("gas_station", village.gas_station),
                                             ("restaurant", village.restaurant), ("bakery", village.bakery), ("bank", village.bank),
                                             ("town_shop", village.town_shop), ("deli", village.deli),
                                             ("livestock_market", village.livestock_market), ("lumber_yard", village.lumber_yard),
                                             ("farmers_market_stall", village.market_stall))},
    **{f"building_{n}_lights": ((lambda f=f: f(night=True)), GLOW)
       for n, f in (("seed_shop", village.seed_shop), ("gas_station", village.gas_station), ("restaurant", village.restaurant),
                    ("bakery", village.bakery), ("bank", village.bank), ("town_shop", village.town_shop), ("deli", village.deli))},
    "prop_for_rent_sign": (village.for_rent_sign, {}),
    "prop_open_sign": (village.open_sign, {}),
    "prop_gas_pump": (village.gas_pump, {}),
    "prop_market_goods": (village.market_goods, {}),
    "nature_reeds": (village.reeds, {}),
    **{f"prop_workshop_{w}": ((lambda w=w: village.workshop(w)), {}) for w in village.WORKSHOPS},
    # Village projects.
    **{f"building_{n}": (f, {}) for n, f in (("post_office", village.post_office), ("market_hall", village.market_hall),
                                             ("bandstand", village.bandstand), ("boathouse", village.boathouse),
                                             ("windmill", village.windmill), ("windmill_ruin", village.windmill_ruin))},
    **{f"building_{n}_lights": ((lambda f=f: f(night=True)), GLOW)
       for n, f in (("post_office", village.post_office), ("market_hall", village.market_hall), ("bandstand", village.bandstand),
                    ("boathouse", village.boathouse), ("windmill", village.windmill))},
    **{f"building_windmill_sails_{n}": ((lambda n=n: village.windmill(sails=n)), {}) for n in range(6)},
    "prop_flower_planter": (village.flower_planter, {}),
    "prop_fair_lantern": (village.fair_lantern, {}),
    "prop_fair_lantern_lights": (lambda: village.fair_lantern(night=True), GLOW),
    "prop_bunting": (village.bunting, {}),
    "prop_prize_table": (village.prize_table, {}),
    "prop_rowboat": (village.rowboat, {}),
    "prop_project_sign": (village.project_sign, {}),
    **{f"vehicle_truck_old_dir{d:02d}": ((lambda d=d: models.truck(d)), {}) for d in range(16)},
    **{f"vehicle_truck_old_load{n}_dir{d:02d}": ((lambda d=d, n=n: models.truck(d, load=n, overlay=True)), {})
       for n in (1, 2) for d in range(16)},
}


def main(selected):
    names = [n for n in ASSETS if not selected or any(n == s or n.startswith(s) for s in selected)]
    for name in names:
        build, options = ASSETS[name]
        art.reset()
        build()
        art.render(name, frame(name), preview_dir=PREVIEW, **options)
        print("rendered", name)


if __name__ == "__main__":
    main(sys.argv[1:])
