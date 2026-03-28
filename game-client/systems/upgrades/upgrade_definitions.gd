class_name UpgradeDefinitions
extends RefCounted


enum UpgradeType {
	WEAPON_DAMAGE,
	FIRE_RATE,
	MAX_HEALTH,
	DASH_COOLDOWN,
	MOVE_SPEED,
	MOMENTUM_RETAIN,
	KILL_HEAL,
	OVERDRIVE,
	LIFESTEAL_CORE,
	UNSTABLE_ROUNDS,
}


static var catalog: Array[Dictionary] = [
	{
		"type": UpgradeType.WEAPON_DAMAGE,
		"name": "brutal rounds",
		"description": "+30% weapon damage",
		"stat": "damage",
		"modifier": 1.3,
		"apply_mode": "multiply",
	},
	{
		"type": UpgradeType.FIRE_RATE,
		"name": "rapid chamber",
		"description": "+25% fire rate",
		"stat": "fire_rate",
		"modifier": 0.75,
		"apply_mode": "multiply",
	},
	{
		"type": UpgradeType.MAX_HEALTH,
		"name": "reinforced core",
		"description": "+25 max health",
		"stat": "max_health",
		"modifier": 25,
		"apply_mode": "add",
	},
	{
		"type": UpgradeType.DASH_COOLDOWN,
		"name": "reflex bypass",
		"description": "-20% dash cooldown",
		"stat": "dash_cooldown",
		"modifier": 0.8,
		"apply_mode": "multiply",
	},
	{
		"type": UpgradeType.MOVE_SPEED,
		"name": "nerve accelerant",
		"description": "+15% movement speed",
		"stat": "move_speed",
		"modifier": 1.15,
		"apply_mode": "multiply",
	},
	{
		"type": UpgradeType.MOMENTUM_RETAIN,
		"name": "friction burn",
		"description": "-30% air friction",
		"stat": "air_friction",
		"modifier": 0.7,
		"apply_mode": "multiply",
	},
	{
		"type": UpgradeType.KILL_HEAL,
		"name": "blood siphon",
		"description": "heal 5 hp per kill",
		"stat": "kill_heal",
		"modifier": 5,
		"apply_mode": "set",
	},
	{
		"type": UpgradeType.OVERDRIVE,
		"name": "overdrive",
		"description": "+60% fire rate, +20% weapon shake",
		"stat": "overdrive",
		"modifier": 1.0,
		"apply_mode": "special",
	},
	{
		"type": UpgradeType.LIFESTEAL_CORE,
		"name": "lifesteal core",
		"description": "heal 12 hp per kill",
		"stat": "kill_heal",
		"modifier": 12,
		"apply_mode": "set",
	},
	{
		"type": UpgradeType.UNSTABLE_ROUNDS,
		"name": "unstable rounds",
		"description": "hits deal 50% bonus as aoe",
		"stat": "unstable_rounds",
		"modifier": 1.0,
		"apply_mode": "special",
	},
]


static func pick_choices(count: int, exclude: Array = []) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for upgrade in catalog:
		if upgrade.type not in exclude:
			available.append(upgrade)

	available.shuffle()
	var result: Array[Dictionary] = []
	for i in mini(count, available.size()):
		result.append(available[i])
	return result
