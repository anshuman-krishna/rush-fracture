class_name MetaProgression
extends RefCounted

# everything that persists between runs: shard rewards, permanent upgrades,
# unlocks (weapons, skins, perks, cosmetics), ascension tiers and
# achievements.
#
# every unlock listed here has an implementation somewhere in the game; the
# old catalogue sold nine items that nothing ever read.

const MAX_ASCENSION: int = 10

# --- shard rewards --------------------------------------------------------------

const SHARDS_PER_KILL: int = 1
const SHARDS_PER_ROOM: int = 5
const SHARDS_PER_BOSS: int = 20
const SHARDS_PER_ELITE: int = 3
const SHARDS_PVP_WIN: int = 20
const SHARDS_COMBO_BONUS_THRESHOLD: int = 10
const SHARDS_COMBO_BONUS: int = 10
const SHARDS_PER_ASCENSION: float = 0.2

const COMPLETION_BONUS: Dictionary = {
	RunData.MODE_STANDARD: 60,
	RunData.MODE_DAILY: 60,
	RunData.MODE_SPRINT: 25,
	RunData.MODE_BOSS_RUSH: 50,
	RunData.MODE_ENDLESS: 0,
	RunData.MODE_VERSUS: 15,
}


static func calculate_shards(data: RunData, combo_best: int, pvp_won: bool) -> Dictionary:
	var breakdown: Dictionary = {}
	var total: int = 0

	breakdown["kills"] = data.total_enemies_killed * SHARDS_PER_KILL
	breakdown["rooms"] = data.rooms_cleared * SHARDS_PER_ROOM
	total += breakdown.kills + breakdown.rooms

	if data.bosses_defeated > 0:
		breakdown["bosses"] = data.bosses_defeated * SHARDS_PER_BOSS
		total += breakdown.bosses
	if data.elites_killed > 0:
		breakdown["elites"] = data.elites_killed * SHARDS_PER_ELITE
		total += breakdown.elites
	if data.status == RunData.RunStatus.COMPLETED:
		var bonus: int = COMPLETION_BONUS.get(data.mode, 25)
		if bonus > 0:
			breakdown["completed"] = bonus
			total += bonus
	if pvp_won:
		breakdown["pvp_win"] = SHARDS_PVP_WIN
		total += SHARDS_PVP_WIN
	if combo_best >= SHARDS_COMBO_BONUS_THRESHOLD:
		breakdown["combo_bonus"] = SHARDS_COMBO_BONUS
		total += SHARDS_COMBO_BONUS
	# unspent essence converts at ten to one
	var leftover: int = data.essence / 10
	if leftover > 0:
		breakdown["essence"] = leftover
		total += leftover
	if data.ascension > 0:
		var extra: int = int(total * SHARDS_PER_ASCENSION * data.ascension)
		breakdown["ascension"] = extra
		total += extra

	breakdown["total"] = total
	return breakdown


# --- permanent upgrades -----------------------------------------------------------

# `stat` + `mode` + `per_level` describe the modifier applied at run start.
const META_CATALOG: Array[Dictionary] = [
	{"id": "damage_boost", "name": "hardened rounds", "description": "+3% weapon damage per level",
		"max_level": 10, "cost_base": 75, "cost_per_level": 60, "stat": &"damage", "mode": "mul", "per_level": 0.03},
	{"id": "speed_boost", "name": "nerve wire", "description": "+2% movement speed per level",
		"max_level": 8, "cost_base": 60, "cost_per_level": 50, "stat": &"move_speed", "mode": "mul", "per_level": 0.02},
	{"id": "health_boost", "name": "plated core", "description": "+8 max health per level",
		"max_level": 10, "cost_base": 60, "cost_per_level": 45, "stat": &"max_health", "mode": "add", "per_level": 8.0},
	{"id": "dash_boost", "name": "reflex chip", "description": "-3% dash cooldown per level",
		"max_level": 5, "cost_base": 100, "cost_per_level": 75, "stat": &"dash_cooldown", "mode": "mul", "per_level": -0.03},
	{"id": "shard_magnet", "name": "shard magnet", "description": "+8% shard earnings per level",
		"max_level": 5, "cost_base": 120, "cost_per_level": 90, "stat": &"", "mode": "", "per_level": 0.08},
	{"id": "fire_rate_boost", "name": "overclock chamber", "description": "+2% fire rate per level",
		"max_level": 8, "cost_base": 80, "cost_per_level": 55, "stat": &"fire_rate", "mode": "mul", "per_level": 0.02},
	{"id": "armor_plating", "name": "fracture plating", "description": "-2% damage taken per level",
		"max_level": 8, "cost_base": 90, "cost_per_level": 65, "stat": &"damage_taken", "mode": "mul", "per_level": -0.02},
	{"id": "kill_recovery", "name": "parasitic link", "description": "heal 1 on every kill per level",
		"max_level": 5, "cost_base": 150, "cost_per_level": 100, "stat": &"", "mode": "", "per_level": 1.0},
	{"id": "jump_boost", "name": "hydraulic legs", "description": "+3% jump height per level",
		"max_level": 5, "cost_base": 70, "cost_per_level": 50, "stat": &"jump_force", "mode": "mul", "per_level": 0.03},
	{"id": "weapon_swap_speed", "name": "quick hands", "description": "+25% weapon switch speed per level",
		"max_level": 3, "cost_base": 120, "cost_per_level": 90, "stat": &"swap_speed", "mode": "mul", "per_level": 0.25},
	{"id": "crit_boost", "name": "predator's eye", "description": "+1.5% critical chance per level",
		"max_level": 6, "cost_base": 110, "cost_per_level": 80, "stat": &"crit_chance", "mode": "add", "per_level": 0.015},
	{"id": "essence_boost", "name": "deep pockets", "description": "+6% essence per level",
		"max_level": 5, "cost_base": 90, "cost_per_level": 70, "stat": &"essence_gain", "mode": "mul", "per_level": 0.06},
]

## kept under the old name for anything that still reads it
static var meta_catalog: Array[Dictionary]:
	get:
		return META_CATALOG


static func meta_entry(upgrade_id: String) -> Dictionary:
	for entry: Dictionary in META_CATALOG:
		if entry.id == upgrade_id:
			return entry
	return {}


static func get_upgrade_cost(upgrade_id: String, current_level: int) -> int:
	var entry: Dictionary = meta_entry(upgrade_id)
	if entry.is_empty():
		return 999999
	return int(entry.cost_base) + int(entry.cost_per_level) * current_level


static func get_upgrade_max_level(upgrade_id: String) -> int:
	return int(meta_entry(upgrade_id).get("max_level", 0))


static func can_purchase(profile: PlayerProfile, upgrade_id: String) -> bool:
	var current: int = profile.get_meta_level(upgrade_id)
	if current >= get_upgrade_max_level(upgrade_id):
		return false
	return profile.fracture_shards >= get_upgrade_cost(upgrade_id, current)


static func purchase(profile: PlayerProfile, upgrade_id: String) -> bool:
	if not can_purchase(profile, upgrade_id):
		return false
	var current: int = profile.get_meta_level(upgrade_id)
	profile.fracture_shards -= get_upgrade_cost(upgrade_id, current)
	profile.meta_upgrades[upgrade_id] = current + 1
	profile.save()
	return true


## writes every purchased permanent upgrade into a stat block under "meta:" keys.
static func apply_to_stats(profile: PlayerProfile, stats: StatBlock) -> void:
	for entry: Dictionary in META_CATALOG:
		var level: int = profile.get_meta_level(entry.id)
		var stat: StringName = entry.stat
		if level <= 0 or stat == &"":
			continue
		var key: StringName = StringName("meta:%s" % entry.id)
		if entry.mode == "mul":
			stats.set_mul(stat, key, maxf(0.1, 1.0 + float(entry.per_level) * level))
		else:
			stats.set_add(stat, key, float(entry.per_level) * level)


static func get_shard_multiplier(profile: PlayerProfile) -> float:
	var mult: float = 1.0 + profile.get_meta_level("shard_magnet") * 0.08
	if profile.has_unlock("shard_hunger"):
		mult += 0.15
	return mult


static func get_kill_heal_bonus(profile: PlayerProfile) -> int:
	return profile.get_meta_level("kill_recovery")


# --- unlocks ----------------------------------------------------------------------

# categories: weapon (generated from WeaponDefs), skin, weapon_variant, starting_perk, cosmetic
const UNLOCK_CATALOG: Array[Dictionary] = [
	# weapon variants: change how a weapon you own behaves
	{"id": "rapid_beam", "name": "rapid beam", "category": "weapon_variant", "cost": 120, "requirement": "total_kills >= 200",
		"description": "stinger ticks 20% faster for 10% less damage per tick"},
	{"id": "wide_scatter", "name": "wide scatter", "category": "weapon_variant", "cost": 120, "requirement": "total_kills >= 300",
		"description": "sporecaster: +3 pellets, wider spread"},
	{"id": "marksman_rifle", "name": "marksman carbine", "category": "weapon_variant", "cost": 150, "requirement": "runs_completed >= 1",
		"description": "carbine: +50% damage, 30% slower fire"},
	{"id": "incendiary_scatter", "name": "incendiary scatter", "category": "weapon_variant", "cost": 250, "requirement": "total_kills >= 500",
		"description": "sporecaster pellets always set enemies alight"},
	{"id": "charged_beam", "name": "deep reservoir", "category": "weapon_variant", "cost": 300, "requirement": "runs_completed >= 3",
		"description": "stinger starts every run with +50% heat capacity"},
	{"id": "ricochet_rifle", "name": "ricochet carbine", "category": "weapon_variant", "cost": 350, "requirement": "total_kills >= 1000",
		"description": "carbine shots always bounce to a second enemy"},

	# starting perks: always on once owned
	{"id": "head_start", "name": "head start", "category": "starting_perk", "cost": 80, "requirement": "total_runs >= 5",
		"description": "+15% movement speed for the first 30 seconds of a run"},
	{"id": "scavenger", "name": "scavenger", "category": "starting_perk", "cost": 100, "requirement": "runs_completed >= 1",
		"description": "the first kill in each room heals 10"},
	{"id": "glass_cannon", "name": "sharpened", "category": "starting_perk", "cost": 100, "requirement": "bosses_defeated >= 1",
		"description": "start with +20% damage and -20 max health"},
	{"id": "adrenaline_junkie", "name": "adrenaline junkie", "category": "starting_perk", "cost": 200, "requirement": "best_combo >= 10",
		"description": "combos last a full second longer before dropping"},
	{"id": "shard_hunger", "name": "shard hunger", "category": "starting_perk", "cost": 180, "requirement": "total_runs >= 15",
		"description": "+15% shards from every run, -10 max health"},
	{"id": "last_stand", "name": "last stand", "category": "starting_perk", "cost": 250, "requirement": "bosses_defeated >= 3",
		"description": "below 20% health: +40% damage and +20% speed"},
	{"id": "momentum_start", "name": "momentum start", "category": "starting_perk", "cost": 300, "requirement": "runs_completed >= 3",
		"description": "your first dash in each room makes you untouchable for 3 seconds"},

	# cosmetics
	{"id": "trail_fracture", "name": "fracture trail", "category": "cosmetic", "cost": 400, "requirement": "total_kills >= 1500",
		"description": "dashing leaves a trail of light"},
	{"id": "kill_pulse", "name": "kill pulse", "category": "cosmetic", "cost": 350, "requirement": "best_combo >= 15",
		"description": "every kill sends out a ring of light"},

	# skins
	{"id": "skin:ember", "name": "skin: ember", "category": "skin", "cost": 150, "requirement": "total_kills >= 100",
		"description": "charcoal shell, orange glow"},
	{"id": "skin:toxin", "name": "skin: toxin", "category": "skin", "cost": 150, "requirement": "runs_completed >= 1",
		"description": "olive shell, acid glow"},
	{"id": "skin:abyss", "name": "skin: abyss", "category": "skin", "cost": 200, "requirement": "total_runs >= 10",
		"description": "deep blue shell, cyan glow"},
	{"id": "skin:void", "name": "skin: void", "category": "skin", "cost": 300, "requirement": "bosses_defeated >= 3",
		"description": "black shell, violet glow"},
	{"id": "skin:bloodline", "name": "skin: bloodline", "category": "skin", "cost": 300, "requirement": "best_combo >= 15",
		"description": "red shell, red glow"},
	{"id": "skin:ivory", "name": "skin: ivory", "category": "skin", "cost": 400, "requirement": "runs_completed >= 5",
		"description": "white shell, gold glow"},
	{"id": "skin:gilded", "name": "skin: gilded", "category": "skin", "cost": 800, "requirement": "ascension >= 3",
		"description": "gold on gold. you earned it."},
]

static var _full_catalog: Array[Dictionary] = []

## every unlock, weapons first. built once from WeaponDefs + UNLOCK_CATALOG.
static var unlock_catalog: Array[Dictionary]:
	get:
		if _full_catalog.is_empty():
			for id: StringName in WeaponDefs.ORDER:
				var def: Dictionary = WeaponDefs.CATALOG[id]
				if int(def.cost) <= 0:
					continue
				_full_catalog.append({
					"id": String(id), "name": def.name, "category": "weapon", "cost": def.cost,
					"requirement": def.requirement, "description": def.description,
				})
			_full_catalog.append_array(UNLOCK_CATALOG)
		return _full_catalog


static func unlock_entry(unlock_id: String) -> Dictionary:
	for entry: Dictionary in unlock_catalog:
		if entry.id == unlock_id:
			return entry
	return {}


static func can_unlock(profile: PlayerProfile, unlock_id: String) -> bool:
	if profile.has_unlock(unlock_id):
		return false
	var entry: Dictionary = unlock_entry(unlock_id)
	if entry.is_empty() or profile.fracture_shards < int(entry.get("cost", 0)):
		return false
	return _check_requirement(profile, entry.get("requirement", ""))


static func purchase_unlock(profile: PlayerProfile, unlock_id: String) -> bool:
	if not can_unlock(profile, unlock_id):
		return false
	profile.fracture_shards -= int(unlock_entry(unlock_id).get("cost", 0))
	profile.unlocks[unlock_id] = true
	profile.save()
	return true


static func is_requirement_met(profile: PlayerProfile, unlock_id: String) -> bool:
	return _check_requirement(profile, unlock_entry(unlock_id).get("requirement", ""))


## turns "total_kills >= 200" into "200 total kills".
static func requirement_text(req: String) -> String:
	var parts: PackedStringArray = req.split(" ")
	if parts.size() != 3:
		return ""
	return "%s %s" % [parts[2], parts[0].replace("_", " ")]


static func _check_requirement(profile: PlayerProfile, req: String) -> bool:
	if req.is_empty():
		return true
	var parts: PackedStringArray = req.split(" ")
	if parts.size() != 3 or parts[1] != ">=":
		# a requirement nobody can parse must not hand the item out for free
		return false
	var value: int = 0
	match parts[0]:
		"total_kills": value = profile.total_kills
		"total_runs": value = profile.total_runs
		"runs_completed": value = profile.runs_completed
		"pvp_wins": value = profile.pvp_wins
		"bosses_defeated": value = profile.bosses_defeated
		"best_combo": value = profile.best_combo
		"elites_killed": value = profile.elites_killed
		"ascension": value = profile.ascension_unlocked
		"endless_depth": value = profile.endless_best_depth
		_: return false
	return value >= parts[2].to_int()


# --- ascension ----------------------------------------------------------------------

## what a given ascension tier changes, for the menu.
static func ascension_description(level: int) -> String:
	if level <= 0:
		return "standard difficulty."
	var lines: PackedStringArray = PackedStringArray()
	lines.append("enemies +%d%% tougher" % int(round(level * RoomGenerator.ASCENSION_STEP * 90.0)))
	lines.append("+%d%% shards" % int(round(level * SHARDS_PER_ASCENSION * 100.0)))
	if level >= 2:
		lines.append("the fracture core waits after the titan")
	if level >= 4:
		lines.append("more elites")
	return ", ".join(lines) + "."


# --- achievements ---------------------------------------------------------------------

const ACHIEVEMENTS: Array[Dictionary] = [
	{"id": "first_blood", "name": "first blood", "description": "finish a run", "reward": 50},
	{"id": "gatekeeper", "name": "gatekeeper", "description": "defeat the brood warden", "reward": 40},
	{"id": "regicide", "name": "regicide", "description": "defeat the hive matriarch", "reward": 60},
	{"id": "titanfall", "name": "titanfall", "description": "defeat the fracture titan", "reward": 80},
	{"id": "heart_of_it", "name": "the heart of it", "description": "destroy the fracture core", "reward": 150},
	{"id": "untouchable", "name": "untouchable", "description": "clear a boss room without taking damage", "reward": 100},
	{"id": "chain_25", "name": "unbroken", "description": "reach a 25 kill combo", "reward": 60},
	{"id": "speed_demon", "name": "speed demon", "description": "finish a standard run in under 12 minutes", "reward": 100},
	{"id": "deep_diver", "name": "deep diver", "description": "clear 30 rooms in endless", "reward": 120},
	{"id": "rush_hour", "name": "rush hour", "description": "finish boss rush", "reward": 120},
	{"id": "mutant", "name": "mutant", "description": "finish a run with three mutations", "reward": 60},
	{"id": "ascendant", "name": "ascendant", "description": "finish a run on ascension 5", "reward": 200},
]


## checks a finished run against every achievement, grants new ones (and
## their shards) on the profile, and returns the entries just earned.
static func check_achievements(profile: PlayerProfile, data: RunData, combo_best: int, flags: Dictionary = {}) -> Array[Dictionary]:
	var earned: Array[Dictionary] = []
	var won: bool = data.status == RunData.RunStatus.COMPLETED
	var bosses: Array = flags.get("bosses_killed", [])
	for a: Dictionary in ACHIEVEMENTS:
		if profile.achievements.has(a.id):
			continue
		var ok: bool = false
		match a.id:
			"first_blood": ok = won
			"gatekeeper": ok = bosses.has(&"warden")
			"regicide": ok = bosses.has(&"matriarch")
			"titanfall": ok = bosses.has(&"titan")
			"heart_of_it": ok = bosses.has(&"core")
			"untouchable": ok = flags.get("flawless_boss", false)
			"chain_25": ok = combo_best >= 25
			"speed_demon": ok = won and data.mode == RunData.MODE_STANDARD and data.elapsed_time < 720.0
			"deep_diver": ok = data.mode == RunData.MODE_ENDLESS and data.rooms_cleared >= 30
			"rush_hour": ok = won and data.mode == RunData.MODE_BOSS_RUSH
			"mutant": ok = won and data.chosen_mutations.size() >= 3
			"ascendant": ok = won and data.ascension >= 5
		if ok:
			profile.achievements[a.id] = true
			profile.fracture_shards += int(a.reward)
			earned.append(a)
	return earned
