class_name UpgradeDefinitions
extends RefCounted

# every in-run upgrade, as data.
#
#   mods     [[stat, "mul" | "add", value], ...] applied to the player's stats
#   special  an effect id handled by UpgradeManager
#   flag     [weapon_id, flag, value] set on a weapon in the loadout
#   weapon   only offered when this weapon is in the loadout
#   max      how many times it can be taken (default 1)
#
# anything listed here does what its description says: each entry is checked
# by tests/unit so a description can't quietly outlive its effect again.

const RARITY_COMMON: StringName = &"common"
const RARITY_RARE: StringName = &"rare"
const RARITY_EPIC: StringName = &"epic"
const RARITY_CURSED: StringName = &"cursed"

const RARITY_WEIGHT: Dictionary = {
	RARITY_COMMON: 60.0,
	RARITY_RARE: 30.0,
	RARITY_EPIC: 8.0,
	RARITY_CURSED: 11.0,
}

const RARITY_COLOR: Dictionary = {
	RARITY_COMMON: Color(0.85, 0.88, 0.85),
	RARITY_RARE: Color(0.35, 0.75, 1.0),
	RARITY_EPIC: Color(1.0, 0.75, 0.25),
	RARITY_CURSED: Color(0.95, 0.3, 0.8),
}

const CATALOG: Array[Dictionary] = [
	# --- common, stackable ------------------------------------------------
	{"id": &"brutal_rounds", "name": "brutal rounds", "rarity": RARITY_COMMON, "max": 5,
		"description": "+20% weapon damage", "mods": [[&"damage", "mul", 1.2]]},
	{"id": &"rapid_chamber", "name": "rapid chamber", "rarity": RARITY_COMMON, "max": 5,
		"description": "+15% fire rate", "mods": [[&"fire_rate", "mul", 1.15]]},
	{"id": &"reinforced_core", "name": "reinforced core", "rarity": RARITY_COMMON, "max": 5,
		"description": "+25 max health, and heal that much", "mods": [[&"max_health", "add", 25.0]], "special": &"heal_25"},
	{"id": &"reflex_bypass", "name": "reflex bypass", "rarity": RARITY_COMMON, "max": 4,
		"description": "-18% dash cooldown", "mods": [[&"dash_cooldown", "mul", 0.82]]},
	{"id": &"nerve_accelerant", "name": "nerve accelerant", "rarity": RARITY_COMMON, "max": 4,
		"description": "+10% movement speed", "mods": [[&"move_speed", "mul", 1.1]]},
	{"id": &"blood_siphon", "name": "blood siphon", "rarity": RARITY_COMMON, "max": 4,
		"description": "heal 3 on every kill", "special": &"kill_heal"},
	{"id": &"keen_eye", "name": "keen eye", "rarity": RARITY_COMMON, "max": 4,
		"description": "+8% critical hit chance", "mods": [[&"crit_chance", "add", 0.08]]},
	{"id": &"anatomy", "name": "anatomy lesson", "rarity": RARITY_COMMON, "max": 3,
		"description": "+25% weak-point damage", "mods": [[&"weak_damage", "mul", 1.25]]},
	{"id": &"thick_hide", "name": "thick hide", "rarity": RARITY_COMMON, "max": 4,
		"description": "take 10% less damage", "mods": [[&"damage_taken", "mul", 0.9]]},
	{"id": &"spring_tendons", "name": "spring tendons", "rarity": RARITY_COMMON, "max": 2,
		"description": "+15% jump height", "mods": [[&"jump_force", "mul", 1.15]]},
	{"id": &"cooling_fins", "name": "cooling fins", "rarity": RARITY_COMMON, "max": 3,
		"description": "beam heat and coil drain build 20% slower", "mods": [[&"heat_gain", "mul", 0.8]]},
	{"id": &"volatile_mix", "name": "volatile mix", "rarity": RARITY_COMMON, "max": 3,
		"description": "+25% explosion damage, +10% explosion radius",
		"mods": [[&"blast_damage", "mul", 1.25], [&"blast_radius", "mul", 1.1]]},
	{"id": &"lodestone", "name": "lodestone", "rarity": RARITY_COMMON, "max": 2,
		"description": "pickups fly to you from further away, +20% essence",
		"mods": [[&"pickup_radius", "mul", 1.7], [&"essence_gain", "mul", 1.2]]},
	{"id": &"quick_hands", "name": "quick hands", "rarity": RARITY_COMMON, "max": 2,
		"description": "switch weapons 40% faster, -25% recoil",
		"mods": [[&"swap_speed", "mul", 1.4], [&"recoil", "mul", 0.75]]},

	# --- rare -------------------------------------------------------------
	{"id": &"twin_dash", "name": "twin dash", "rarity": RARITY_RARE, "max": 2,
		"description": "+1 dash charge", "mods": [[&"dash_charges", "add", 1.0]]},
	{"id": &"air_step", "name": "air step", "rarity": RARITY_RARE, "max": 2,
		"description": "+1 jump in mid-air", "mods": [[&"air_jumps", "add", 1.0]]},
	{"id": &"brutal_crits", "name": "savage instinct", "rarity": RARITY_RARE, "max": 3,
		"description": "critical hits deal +50% more", "mods": [[&"crit_mult", "add", 0.5]]},
	{"id": &"overdrive", "name": "overdrive", "rarity": RARITY_RARE,
		"description": "+35% fire rate, +30% recoil", "mods": [[&"fire_rate", "mul", 1.35], [&"recoil", "mul", 1.3]]},
	{"id": &"momentum_rounds", "name": "momentum rounds", "rarity": RARITY_RARE,
		"description": "deal more damage the faster you are moving, up to +35%", "special": &"momentum_rounds"},
	{"id": &"kinetic_plating", "name": "kinetic plating", "rarity": RARITY_RARE,
		"description": "take 30% less damage while moving faster than a run", "special": &"kinetic_plating"},
	{"id": &"adrenaline_surge", "name": "adrenaline surge", "rarity": RARITY_RARE,
		"description": "each combo tier adds +6% movement speed", "special": &"adrenaline_surge"},
	{"id": &"chain_reaction", "name": "chain reaction", "rarity": RARITY_RARE,
		"description": "enemies you kill explode", "special": &"chain_reaction"},
	{"id": &"explosive_dash", "name": "explosive dash", "rarity": RARITY_RARE,
		"description": "dashing blasts everything next to you", "special": &"explosive_dash"},
	{"id": &"null_field", "name": "null field", "rarity": RARITY_RARE,
		"description": "enemies within 8 m move 25% slower", "special": &"null_field"},
	{"id": &"unstable_rounds", "name": "unstable rounds", "rarity": RARITY_RARE,
		"description": "hits have a 20% chance to burst, damaging nearby enemies", "special": &"unstable_rounds"},
	{"id": &"temporal_break", "name": "temporal break", "rarity": RARITY_RARE,
		"description": "kills briefly slow time", "special": &"temporal_break"},
	{"id": &"impact_slam", "name": "impact slam", "rarity": RARITY_RARE,
		"description": "your ground slam hits like a grenade and stuns", "special": &"impact_slam"},
	{"id": &"razor_slide", "name": "razor slide", "rarity": RARITY_RARE,
		"description": "sliding into enemies cuts them, and slides lose less speed",
		"mods": [[&"slide_friction", "mul", 0.5]], "special": &"razor_slide"},
	{"id": &"second_wind", "name": "second wind", "rarity": RARITY_RARE,
		"description": "survive one killing blow per run", "special": &"second_wind"},
	{"id": &"leech", "name": "leech", "rarity": RARITY_RARE, "max": 2,
		"description": "critical hits heal 2", "special": &"leech"},
	{"id": &"executioner", "name": "executioner", "rarity": RARITY_RARE,
		"description": "+40% damage to enemies below 30% health", "special": &"executioner"},
	{"id": &"phase_dash", "name": "phase dash", "rarity": RARITY_RARE,
		"description": "stay untouchable for longer after a dash", "special": &"phase_dash"},

	# --- weapon-specific --------------------------------------------------
	{"id": &"burst_protocol", "name": "burst protocol", "rarity": RARITY_RARE, "weapon": &"pulse_rifle",
		"description": "carbine fires three-round bursts", "flag": [&"pulse_rifle", &"burst", true]},
	{"id": &"penetrator", "name": "penetrator rounds", "rarity": RARITY_RARE, "weapon": &"pulse_rifle",
		"description": "carbine: +25% damage and shots pass through one enemy", "flag": [&"pulse_rifle", &"piercing", true]},
	{"id": &"ricochet_rounds", "name": "ricochet rounds", "rarity": RARITY_RARE, "weapon": &"pulse_rifle",
		"description": "carbine shots bounce to a second enemy", "flag": [&"pulse_rifle", &"ricochet", true]},
	{"id": &"choke_bore", "name": "choke bore", "rarity": RARITY_RARE, "weapon": &"scatter_cannon",
		"description": "sporecaster spread halved", "flag": [&"scatter_cannon", &"tight", true]},
	{"id": &"double_tap", "name": "double tap", "rarity": RARITY_RARE, "weapon": &"scatter_cannon",
		"description": "sporecaster fires a second, weaker blast", "flag": [&"scatter_cannon", &"double_blast", true]},
	{"id": &"incendiary_spores", "name": "incendiary spores", "rarity": RARITY_RARE, "weapon": &"scatter_cannon",
		"description": "sporecaster pellets set enemies alight", "flag": [&"scatter_cannon", &"incendiary", true]},
	{"id": &"arc_conductor", "name": "arc conductor", "rarity": RARITY_RARE, "weapon": &"beam_emitter",
		"description": "stinger beam arcs to a second enemy", "flag": [&"beam_emitter", &"chain", true]},
	{"id": &"piercing_beam", "name": "piercing beam", "rarity": RARITY_RARE, "weapon": &"beam_emitter",
		"description": "stinger beam passes through enemies", "flag": [&"beam_emitter", &"piercing", true]},
	{"id": &"thermal_sink", "name": "thermal sink", "rarity": RARITY_RARE, "weapon": &"beam_emitter",
		"description": "+50% stinger heat capacity", "flag": [&"beam_emitter", &"capacity", true]},
	{"id": &"hair_trigger", "name": "hair trigger", "rarity": RARITY_RARE, "weapon": &"needler",
		"description": "needle hive detonates with two fewer quills", "flag": [&"needler", &"hair_trigger", true]},
	{"id": &"cluster_spores", "name": "cluster spores", "rarity": RARITY_RARE, "weapon": &"spore_launcher",
		"description": "mortar blasts scatter three bomblets", "flag": [&"spore_launcher", &"cluster", true]},
	{"id": &"insulated", "name": "insulated", "rarity": RARITY_RARE, "weapon": &"spore_launcher",
		"description": "your own mortar blasts no longer hurt you", "flag": [&"spore_launcher", &"insulated", true]},
	{"id": &"overpenetrate", "name": "overpenetration", "rarity": RARITY_RARE, "weapon": &"rail_lance",
		"description": "a fully charged lance detonates in every enemy it passes through", "flag": [&"rail_lance", &"overpenetrate", true]},
	{"id": &"long_chain", "name": "long chain", "rarity": RARITY_RARE, "weapon": &"arc_caster",
		"description": "synapse coil jumps to two more enemies", "flag": [&"arc_caster", &"extra_jumps", 2]},
	{"id": &"hard_bounce", "name": "hard bounce", "rarity": RARITY_RARE, "weapon": &"ripper",
		"description": "ripper discs bounce two more times", "flag": [&"ripper", &"extra_bounces", 2]},
	{"id": &"serrated", "name": "serrated discs", "rarity": RARITY_RARE, "weapon": &"ripper",
		"description": "ripper discs leave enemies bleeding", "flag": [&"ripper", &"serrated", true]},

	# --- epic ---------------------------------------------------------------
	{"id": &"glass_engine", "name": "glass engine", "rarity": RARITY_EPIC,
		"description": "+50% damage and +20% fire rate", "mods": [[&"damage", "mul", 1.5], [&"fire_rate", "mul", 1.2]]},
	{"id": &"fracture_heart", "name": "fracture heart", "rarity": RARITY_EPIC,
		"description": "+50 max health and a full heal", "mods": [[&"max_health", "add", 50.0]], "special": &"heal_full"},
	{"id": &"apex_predator", "name": "apex predator", "rarity": RARITY_EPIC,
		"description": "+15% critical chance, criticals deal double again",
		"mods": [[&"crit_chance", "add", 0.15], [&"crit_mult", "add", 1.0]]},
	{"id": &"perpetual_motion", "name": "perpetual motion", "rarity": RARITY_EPIC,
		"description": "dash recharges twice as fast, +10% movement speed",
		"mods": [[&"dash_cooldown", "mul", 0.5], [&"move_speed", "mul", 1.1]]},

	# --- cursed: real power, real cost ---------------------------------------
	{"id": &"power_surge", "name": "power surge", "rarity": RARITY_CURSED,
		"description": "+40% damage, but every enemy moves 20% faster",
		"mods": [[&"damage", "mul", 1.4]], "special": &"power_surge"},
	{"id": &"fragile_speed", "name": "fragile speed", "rarity": RARITY_CURSED,
		"description": "+30% movement speed, but take 25% more damage",
		"mods": [[&"move_speed", "mul", 1.3], [&"damage_taken", "mul", 1.25]]},
	{"id": &"berserker_pact", "name": "berserker pact", "rarity": RARITY_CURSED,
		"description": "+35% damage while below 40% health, but -20 max health",
		"mods": [[&"max_health", "add", -20.0]], "special": &"berserker_pact"},
	{"id": &"blood_price", "name": "blood price", "rarity": RARITY_CURSED,
		"description": "+60% damage, but -30% max health",
		"mods": [[&"damage", "mul", 1.6], [&"max_health", "mul", 0.7]]},
	{"id": &"tunnel_vision", "name": "tunnel vision", "rarity": RARITY_CURSED,
		"description": "+25% critical chance, but your view narrows",
		"mods": [[&"crit_chance", "add", 0.25], [&"fov_bias", "add", -22.0]]},
]


static func find(id: StringName) -> Dictionary:
	for u: Dictionary in CATALOG:
		if u.id == id:
			return u
	return {}


static func max_stacks(upgrade: Dictionary) -> int:
	return int(upgrade.get("max", 1))


static func rarity_color(upgrade: Dictionary) -> Color:
	return RARITY_COLOR.get(upgrade.get("rarity", RARITY_COMMON), Color.WHITE)


## picks `count` distinct upgrades the player can still take.
##
## owned     id -> stacks already taken
## loadout   weapon ids equipped, so weapon upgrades only show for held weapons
## rare_only true for rare rewards: no commons in the pool
static func pick_choices(count: int, owned: Dictionary = {}, loadout: Array = [], rare_only: bool = false,
		rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	var weights: Array[float] = []
	for u: Dictionary in CATALOG:
		if int(owned.get(u.id, 0)) >= max_stacks(u):
			continue
		var weapon: StringName = u.get("weapon", &"")
		if weapon != &"" and not loadout.has(weapon):
			continue
		var rarity: StringName = u.get("rarity", RARITY_COMMON)
		if rare_only and rarity == RARITY_COMMON:
			continue
		var w: float = RARITY_WEIGHT.get(rarity, 10.0)
		if rare_only and rarity == RARITY_EPIC:
			w *= 2.5
		# weapon upgrades are split three ways; nudge them so they still show up
		if weapon != &"":
			w *= 1.3
		pool.append(u)
		weights.append(w)

	var result: Array[Dictionary] = []
	while result.size() < count and not pool.is_empty():
		var total: float = 0.0
		for w: float in weights:
			total += w
		var roll: float = (rng.randf() if rng else randf()) * total
		var idx: int = pool.size() - 1
		for i: int in pool.size():
			roll -= weights[i]
			if roll <= 0.0:
				idx = i
				break
		result.append(pool[idx])
		pool.remove_at(idx)
		weights.remove_at(idx)
	return result
