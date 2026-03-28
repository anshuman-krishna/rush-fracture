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
	# weapon-specific
	BURST_FIRE,
	ARMOR_PIERCING,
	TIGHT_SPREAD,
	DOUBLE_BLAST,
	BEAM_CHAIN,
	HEAT_CAPACITY,
	# high-impact
	CHAIN_REACTION,
	ADRENALINE_SURGE,
	TEMPORAL_BREAK,
	# cursed
	POWER_SURGE,
	FRAGILE_SPEED,
	BERSERKER_PACT,
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
	# weapon-specific: pulse rifle
	{
		"type": UpgradeType.BURST_FIRE,
		"name": "burst protocol",
		"description": "rifle fires 3-round bursts",
		"stat": "burst_fire",
		"modifier": 1.0,
		"apply_mode": "special",
		"weapon_type": "pulse_rifle",
	},
	{
		"type": UpgradeType.ARMOR_PIERCING,
		"name": "penetrator rounds",
		"description": "rifle deals +40% to each hit",
		"stat": "armor_piercing",
		"modifier": 1.0,
		"apply_mode": "special",
		"weapon_type": "pulse_rifle",
	},
	# weapon-specific: scatter cannon
	{
		"type": UpgradeType.TIGHT_SPREAD,
		"name": "choke bore",
		"description": "scatter spread halved",
		"stat": "tight_spread",
		"modifier": 1.0,
		"apply_mode": "special",
		"weapon_type": "scatter_cannon",
	},
	{
		"type": UpgradeType.DOUBLE_BLAST,
		"name": "double tap",
		"description": "scatter fires a second burst",
		"stat": "double_blast",
		"modifier": 1.0,
		"apply_mode": "special",
		"weapon_type": "scatter_cannon",
	},
	# weapon-specific: beam emitter
	{
		"type": UpgradeType.BEAM_CHAIN,
		"name": "arc conductor",
		"description": "beam chains to a nearby enemy",
		"stat": "beam_chain",
		"modifier": 1.0,
		"apply_mode": "special",
		"weapon_type": "beam_emitter",
	},
	{
		"type": UpgradeType.HEAT_CAPACITY,
		"name": "thermal sink",
		"description": "+50% beam heat capacity",
		"stat": "heat_capacity",
		"modifier": 1.0,
		"apply_mode": "special",
		"weapon_type": "beam_emitter",
	},
	# high-impact
	{
		"type": UpgradeType.CHAIN_REACTION,
		"name": "chain reaction",
		"description": "kills cause an explosion",
		"stat": "chain_reaction",
		"modifier": 1.0,
		"apply_mode": "special",
	},
	{
		"type": UpgradeType.ADRENALINE_SURGE,
		"name": "adrenaline surge",
		"description": "kill streaks boost speed",
		"stat": "adrenaline_surge",
		"modifier": 1.0,
		"apply_mode": "special",
	},
	{
		"type": UpgradeType.TEMPORAL_BREAK,
		"name": "temporal break",
		"description": "kills briefly slow time",
		"stat": "temporal_break",
		"modifier": 1.0,
		"apply_mode": "special",
	},
	# cursed upgrades — risk/reward
	{
		"type": UpgradeType.POWER_SURGE,
		"name": "power surge",
		"description": "+40% damage, enemies move 20% faster",
		"stat": "power_surge",
		"modifier": 1.0,
		"apply_mode": "special",
		"cursed": true,
	},
	{
		"type": UpgradeType.FRAGILE_SPEED,
		"name": "fragile speed",
		"description": "+30% speed, take 25% more damage",
		"stat": "fragile_speed",
		"modifier": 1.0,
		"apply_mode": "special",
		"cursed": true,
	},
	{
		"type": UpgradeType.BERSERKER_PACT,
		"name": "berserker pact",
		"description": "+25% damage at low hp, -30 max health",
		"stat": "berserker_pact",
		"modifier": 1.0,
		"apply_mode": "special",
		"cursed": true,
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
