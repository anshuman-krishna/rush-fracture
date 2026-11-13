class_name Biome
extends RefCounted

# the look of an act: sky, fog, light, floor and wall colours, the enemy
# strain's palette, and which set dressing grows there. one act, one biome.

const ACT_ORDER: Array[StringName] = [&"hatchery", &"marrow", &"fracture"]

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
}


static func exists(id: StringName) -> bool:
	return DEFS.has(id)


static func get_def(id: StringName) -> Dictionary:
	return DEFS.get(id, DEFS[&"hatchery"])


static func for_act(act_index: int) -> StringName:
	return ACT_ORDER[posmod(act_index, ACT_ORDER.size())]


static func display_name(id: StringName) -> String:
	return get_def(id).name


static func glow(id: StringName) -> Color:
	return get_def(id).glow


static func strain(id: StringName) -> StringName:
	return get_def(id).strain
