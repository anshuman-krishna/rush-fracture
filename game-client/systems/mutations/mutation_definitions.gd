class_name MutationDefinitions
extends RefCounted

# powerful run-altering modifiers with meaningful trade-offs.

enum MutationType {
	GLASS_CANNON,
	OVERCLOCK,
	BLOOD_PACT,
	UNSTABLE_CORE,
	VELOCITY_ADDICT,
	TEMPORAL_DISTORTION,
	MOMENTUM_SHIELD,
	FRACTURE_ECHO,
}


static var catalog: Array[Dictionary] = [
	{
		"type": MutationType.GLASS_CANNON,
		"name": "glass cannon",
		"description": "+50% damage, -40% max health",
		"upside": "+50% damage",
		"downside": "-40% max health",
	},
	{
		"type": MutationType.OVERCLOCK,
		"name": "overclock",
		"description": "+40% fire rate, heat builds 2x faster",
		"upside": "+40% fire rate",
		"downside": "2x heat buildup",
	},
	{
		"type": MutationType.BLOOD_PACT,
		"name": "blood pact",
		"description": "heal 8 per kill, lose 2 hp/sec",
		"upside": "heal 8 per kill",
		"downside": "constant hp drain",
	},
	{
		"type": MutationType.UNSTABLE_CORE,
		"name": "unstable core",
		"description": "20% chance to explode on hit, 10% to self-damage",
		"upside": "aoe on hit",
		"downside": "self-damage risk",
	},
	{
		"type": MutationType.VELOCITY_ADDICT,
		"name": "velocity addict",
		"description": "+40% speed, -25% friction (less control)",
		"upside": "+40% speed",
		"downside": "reduced control",
	},
	{
		"type": MutationType.TEMPORAL_DISTORTION,
		"name": "temporal distortion",
		"description": "kills slow time 0.5s, -20% base speed",
		"upside": "time slow on kill",
		"downside": "reduced speed",
	},
	{
		"type": MutationType.MOMENTUM_SHIELD,
		"name": "momentum shield",
		"description": "moving fast reduces damage taken, standing still takes 40% more",
		"upside": "damage reduction at speed",
		"downside": "vulnerable when slow",
	},
	{
		"type": MutationType.FRACTURE_ECHO,
		"name": "fracture echo",
		"description": "+35% damage during fracture events, -20% damage otherwise",
		"upside": "massive fracture boost",
		"downside": "weaker in normal rooms",
	},
]


static func pick_choices(count: int, exclude: Array = []) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for mutation in catalog:
		if mutation.get("type") not in exclude:
			available.append(mutation)

	available.shuffle()
	var result: Array[Dictionary] = []
	for i in mini(count, available.size()):
		result.append(available[i])
	return result


static func get_name(type: MutationType) -> String:
	for m in catalog:
		if m.get("type") == type:
			return m.get("name", "")
	return ""
