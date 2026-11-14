class_name Biome
extends RefCounted

# the look of an act: sky, fog, light, floor and wall colours, the enemy
# strain's palette, and which set dressing grows there. one act, one biome.
#
# each act of a run draws its biome from that act's pool, so two runs do not
# walk through the same three places.

## the original three, in order. fixed-order modes (boss rush) still use this.
const ACT_ORDER: Array[StringName] = [&"hatchery", &"marrow", &"fracture"]
## what each act of a run may look like
const ACT_POOLS: Array = [[&"hatchery", &"bloom"], [&"marrow", &"deep"], [&"fracture", &"ashfall"]]

const DEFS: Dictionary = {
	&"hatchery": {
		"name": "the hatchery",
		"tagline": "warm, wet, and waking up",
		"strain": &"default",
		"obstacle_skin": &"default",
		"sky_top": Color(0.02, 0.05, 0.05), "sky_horizon": Color(0.1, 0.22, 0.12), "ground": Color(0.02, 0.04, 0.03),
		"fog": Color(0.07, 0.16, 0.09), "fog_density": 0.012,
		"ambient": Color(0.34, 0.46, 0.34), "ambient_energy": 0.85,
		"sun": Color(1.0, 0.9, 0.7), "sun_energy": 1.6, "sun_pitch": -52.0, "sun_yaw": 35.0,
		"floor": Color(0.085, 0.1, 0.085), "floor_line": Color(0.45, 0.9, 0.3),
		"wall": Color(0.1, 0.12, 0.1), "glow": Color(0.62, 1.0, 0.36),
		"hazard": Color(0.65, 1.0, 0.2),
		"props": ["egg_cluster", "lamp_stalk", "spawn_pod"],
	},
	&"bloom": {
		"name": "the bloom",
		"tagline": "soft, pale, and all of it alive",
		"strain": &"strain_bloom",
		"obstacle_skin": &"strain_bloom",
		"sky_top": Color(0.07, 0.04, 0.06), "sky_horizon": Color(0.36, 0.22, 0.26), "ground": Color(0.05, 0.03, 0.04),
		"fog": Color(0.24, 0.15, 0.18), "fog_density": 0.013,
		"ambient": Color(0.6, 0.48, 0.5), "ambient_energy": 0.95,
		"sun": Color(1.0, 0.86, 0.82), "sun_energy": 1.7, "sun_pitch": -58.0, "sun_yaw": 70.0,
		"floor": Color(0.13, 0.1, 0.11), "floor_line": Color(1.0, 0.62, 0.72),
		"wall": Color(0.17, 0.12, 0.14), "glow": Color(1.0, 0.7, 0.78),
		"hazard": Color(1.0, 0.5, 0.6),
		"props": ["egg_cluster", "spawn_pod", "lamp_stalk"],
	},
	&"marrow": {
		"name": "marrow works",
		"tagline": "where the hive builds itself",
		"strain": &"strain_marrow",
		"obstacle_skin": &"strain_marrow",
		"sky_top": Color(0.03, 0.04, 0.07), "sky_horizon": Color(0.2, 0.26, 0.34), "ground": Color(0.03, 0.04, 0.05),
		"fog": Color(0.13, 0.17, 0.23), "fog_density": 0.01,
		"ambient": Color(0.42, 0.48, 0.58), "ambient_energy": 0.9,
		"sun": Color(0.8, 0.9, 1.0), "sun_energy": 1.7, "sun_pitch": -62.0, "sun_yaw": -50.0,
		"floor": Color(0.1, 0.11, 0.13), "floor_line": Color(0.35, 0.8, 1.0),
		"wall": Color(0.14, 0.15, 0.18), "glow": Color(0.4, 0.85, 1.0),
		"hazard": Color(0.3, 0.7, 1.0),
		"props": ["vent_stack", "lamp_stalk", "totem"],
	},
	&"deep": {
		"name": "the drowned vault",
		"tagline": "cold, quiet, and a long way down",
		"strain": &"strain_deep",
		"obstacle_skin": &"strain_deep",
		"sky_top": Color(0.0, 0.02, 0.04), "sky_horizon": Color(0.03, 0.17, 0.2), "ground": Color(0.0, 0.02, 0.03),
		"fog": Color(0.02, 0.12, 0.14), "fog_density": 0.017,
		"ambient": Color(0.24, 0.46, 0.5), "ambient_energy": 0.8,
		"sun": Color(0.6, 1.0, 0.95), "sun_energy": 1.35, "sun_pitch": -72.0, "sun_yaw": 10.0,
		"floor": Color(0.05, 0.09, 0.1), "floor_line": Color(0.2, 1.0, 0.85),
		"wall": Color(0.06, 0.12, 0.13), "glow": Color(0.25, 1.0, 0.85),
		"hazard": Color(0.2, 1.0, 0.7),
		"props": ["vent_stack", "totem", "spawn_pod"],
	},
	&"fracture": {
		"name": "the fracture",
		"tagline": "the place it all leaks from",
		"strain": &"strain_fracture",
		"obstacle_skin": &"strain_fracture",
		"sky_top": Color(0.03, 0.015, 0.06), "sky_horizon": Color(0.22, 0.1, 0.26), "ground": Color(0.03, 0.015, 0.04),
		"fog": Color(0.1, 0.06, 0.14), "fog_density": 0.011,
		"ambient": Color(0.46, 0.36, 0.56), "ambient_energy": 0.85,
		"sun": Color(1.0, 0.8, 0.95), "sun_energy": 1.6, "sun_pitch": -40.0, "sun_yaw": 120.0,
		"floor": Color(0.1, 0.075, 0.125), "floor_line": Color(0.85, 0.3, 0.8),
		"wall": Color(0.15, 0.1, 0.19), "glow": Color(0.95, 0.35, 0.85),
		"hazard": Color(1.0, 0.25, 0.7),
		"props": ["rift_shard", "totem", "lamp_stalk"],
	},
	&"ashfall": {
		"name": "ashfall",
		"tagline": "what is left when a hive burns",
		"strain": &"strain_ash",
		"obstacle_skin": &"strain_ash",
		"sky_top": Color(0.05, 0.02, 0.015), "sky_horizon": Color(0.36, 0.14, 0.05), "ground": Color(0.04, 0.02, 0.015),
		"fog": Color(0.2, 0.09, 0.05), "fog_density": 0.014,
		"ambient": Color(0.56, 0.4, 0.32), "ambient_energy": 0.85,
		"sun": Color(1.0, 0.62, 0.36), "sun_energy": 1.8, "sun_pitch": -28.0, "sun_yaw": -110.0,
		"floor": Color(0.11, 0.085, 0.075), "floor_line": Color(1.0, 0.45, 0.12),
		"wall": Color(0.16, 0.11, 0.09), "glow": Color(1.0, 0.5, 0.15),
		"hazard": Color(1.0, 0.35, 0.1),
		"props": ["rift_shard", "vent_stack", "totem"],
	},
}


static func exists(id: StringName) -> bool:
	return DEFS.has(id)


static func get_def(id: StringName) -> Dictionary:
	return DEFS.get(id, DEFS[&"hatchery"])


## the fixed biome for an act number: always the same place.
static func for_act(act_index: int) -> StringName:
	return ACT_ORDER[posmod(act_index, ACT_ORDER.size())]


## a biome for an act number, drawn from that act's pool.
static func pick(rng: RandomNumberGenerator, act_index: int) -> StringName:
	var pool: Array = ACT_POOLS[posmod(act_index, ACT_POOLS.size())]
	return pool[rng.randi() % pool.size()]


static func display_name(id: StringName) -> String:
	return get_def(id).name


static func glow(id: StringName) -> Color:
	return get_def(id).glow


static func strain(id: StringName) -> StringName:
	return get_def(id).strain
