class_name MutationDefinitions
extends RefCounted

# run-altering modifiers. each one is a strong upside welded to a real cost,
# and you may always refuse.

enum MutationType {
	GLASS_CANNON,
	OVERCLOCK,
	BLOOD_PACT,
	UNSTABLE_CORE,
	VELOCITY_ADDICT,
	TEMPORAL_DISTORTION,
	MOMENTUM_SHIELD,
	FRACTURE_ECHO,
	HOLLOW_BONES,
	PREDATOR,
	HOARDER,
	VOLATILE_BLOOD,
}

const CATALOG: Array[Dictionary] = [
	{"type": MutationType.GLASS_CANNON, "name": "glass cannon",
		"upside": "+50% damage", "downside": "-40% max health",
		"mods": [[&"damage", "mul", 1.5], [&"max_health", "mul", 0.6]]},
	{"type": MutationType.OVERCLOCK, "name": "overclock",
		"upside": "+40% fire rate", "downside": "heat and coil drain build twice as fast",
		"mods": [[&"fire_rate", "mul", 1.4], [&"heat_gain", "mul", 2.0]]},
	{"type": MutationType.BLOOD_PACT, "name": "blood pact",
		"upside": "heal 8 on every kill", "downside": "lose 2 health every second (never the last point)",
		"mods": []},
	{"type": MutationType.UNSTABLE_CORE, "name": "unstable core",
		"upside": "hits have a 20% chance to explode", "downside": "and a 10% chance to hurt you",
		"mods": []},
	{"type": MutationType.VELOCITY_ADDICT, "name": "velocity addict",
		"upside": "+40% movement speed", "downside": "far less grip: you slide and drift",
		"mods": [[&"move_speed", "mul", 1.4], [&"friction", "mul", 0.5], [&"acceleration", "mul", 0.7]]},
	{"type": MutationType.TEMPORAL_DISTORTION, "name": "temporal distortion",
		"upside": "kills slow time for half a second", "downside": "-20% movement speed",
		"mods": [[&"move_speed", "mul", 0.8]]},
	{"type": MutationType.MOMENTUM_SHIELD, "name": "momentum shield",
		"upside": "take 40% less damage while moving fast", "downside": "take 40% more while nearly still",
		"mods": []},
	{"type": MutationType.FRACTURE_ECHO, "name": "fracture echo",
		"upside": "+35% damage during fracture events", "downside": "-20% damage the rest of the time",
		"mods": []},
	{"type": MutationType.HOLLOW_BONES, "name": "hollow bones",
		"upside": "+1 air jump, +30% jump height", "downside": "-25% max health",
		"mods": [[&"air_jumps", "add", 1.0], [&"jump_force", "mul", 1.3], [&"max_health", "mul", 0.75]]},
	{"type": MutationType.PREDATOR, "name": "predator",
		"upside": "+20% critical chance", "downside": "take 20% more damage",
		"mods": [[&"crit_chance", "add", 0.2], [&"damage_taken", "mul", 1.2]]},
	{"type": MutationType.HOARDER, "name": "hoarder",
		"upside": "double essence from everything", "downside": "-15% damage",
		"mods": [[&"essence_gain", "mul", 2.0], [&"damage", "mul", 0.85]]},
	{"type": MutationType.VOLATILE_BLOOD, "name": "volatile blood",
		"upside": "being hit detonates you, damaging everything nearby", "downside": "-15% max health",
		"mods": [[&"max_health", "mul", 0.85]]},
]


static func find(type: MutationType) -> Dictionary:
	for m: Dictionary in CATALOG:
		if m.type == type:
			return m
	return {}


static func get_name(type: MutationType) -> String:
	return find(type).get("name", "")


static func description(mutation: Dictionary) -> String:
	return "%s, but %s" % [mutation.get("upside", ""), mutation.get("downside", "")]


static func pick_choices(count: int, exclude: Array = [], rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for m: Dictionary in CATALOG:
		if m.type not in exclude:
			available.append(m)
	var result: Array[Dictionary] = []
	while result.size() < count and not available.is_empty():
		var idx: int = (rng.randi() if rng else randi()) % available.size()
		result.append(available[idx])
		available.remove_at(idx)
	return result
