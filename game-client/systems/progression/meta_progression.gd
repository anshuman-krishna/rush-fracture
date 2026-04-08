class_name MetaProgression
extends RefCounted

# defines all permanent upgrades, unlockables, and shard rewards.
# meta upgrades are small incremental bonuses purchased with fracture shards.
# unlocks gate weapon variants and starting perks.


# --- shard rewards (reduced to slow progression) ---

const SHARDS_PER_KILL: int = 1
const SHARDS_PER_ROOM: int = 5
const SHARDS_RUN_COMPLETE: int = 25
const SHARDS_BOSS_KILL: int = 15
const SHARDS_PVP_WIN: int = 20
const SHARDS_COMBO_BONUS_THRESHOLD: int = 10
const SHARDS_COMBO_BONUS: int = 10


static func calculate_shards(data: RunData, combo_best: int, pvp_won: bool) -> Dictionary:
	var breakdown: Dictionary = {}
	var total: int = 0

	var kill_shards: int = data.total_enemies_killed * SHARDS_PER_KILL
	breakdown["kills"] = kill_shards
	total += kill_shards

	var room_shards: int = data.rooms_cleared * SHARDS_PER_ROOM
	breakdown["rooms"] = room_shards
	total += room_shards

	if data.status == RunData.RunStatus.COMPLETED:
		breakdown["completed"] = SHARDS_RUN_COMPLETE
		total += SHARDS_RUN_COMPLETE

	# boss kills
	var boss_count: int = 0
	for room in data.room_sequence:
		if room.type == RoomDefinitions.RoomType.BOSS and room.status == RoomDefinitions.RoomStatus.CLEARED:
			boss_count += 1
	if boss_count > 0:
		var boss_shards: int = boss_count * SHARDS_BOSS_KILL
		breakdown["bosses"] = boss_shards
		total += boss_shards

	if pvp_won:
		breakdown["pvp_win"] = SHARDS_PVP_WIN
		total += SHARDS_PVP_WIN

	if combo_best >= SHARDS_COMBO_BONUS_THRESHOLD:
		breakdown["combo_bonus"] = SHARDS_COMBO_BONUS
		total += SHARDS_COMBO_BONUS

	breakdown["total"] = total
	return breakdown


# --- meta upgrades ---

enum MetaUpgradeId {
	DAMAGE_BOOST,
	SPEED_BOOST,
	HEALTH_BOOST,
	DASH_BOOST,
	SHARD_MAGNET,
	FIRE_RATE_BOOST,
	ARMOR_PLATING,
	KILL_RECOVERY,
	JUMP_BOOST,
	WEAPON_SWAP_SPEED,
}

static var meta_catalog: Array[Dictionary] = [
	{
		"id": "damage_boost",
		"name": "hardened rounds",
		"description": "+3% weapon damage per level",
		"max_level": 10,
		"cost_base": 75,
		"cost_per_level": 60,
		"stat": "damage",
		"bonus_per_level": 0.03,
	},
	{
		"id": "speed_boost",
		"name": "nerve wire",
		"description": "+2% movement speed per level",
		"max_level": 8,
		"cost_base": 60,
		"cost_per_level": 50,
		"stat": "move_speed",
		"bonus_per_level": 0.02,
	},
	{
		"id": "health_boost",
		"name": "plated core",
		"description": "+8 max health per level",
		"max_level": 10,
		"cost_base": 60,
		"cost_per_level": 45,
		"stat": "max_health",
		"bonus_per_level": 8,
	},
	{
		"id": "dash_boost",
		"name": "reflex chip",
		"description": "-3% dash cooldown per level",
		"max_level": 5,
		"cost_base": 100,
		"cost_per_level": 75,
		"stat": "dash_cooldown",
		"bonus_per_level": 0.03,
	},
	{
		"id": "shard_magnet",
		"name": "shard magnet",
		"description": "+8% shard earnings per level",
		"max_level": 5,
		"cost_base": 120,
		"cost_per_level": 90,
		"stat": "shard_bonus",
		"bonus_per_level": 0.08,
	},
	{
		"id": "fire_rate_boost",
		"name": "overclock chamber",
		"description": "+2% fire rate per level",
		"max_level": 8,
		"cost_base": 80,
		"cost_per_level": 55,
		"stat": "fire_rate",
		"bonus_per_level": 0.02,
	},
	{
		"id": "armor_plating",
		"name": "fracture plating",
		"description": "-2% damage taken per level",
		"max_level": 8,
		"cost_base": 90,
		"cost_per_level": 65,
		"stat": "damage_resist",
		"bonus_per_level": 0.02,
	},
	{
		"id": "kill_recovery",
		"name": "parasitic link",
		"description": "heal 1 hp per kill per level",
		"max_level": 5,
		"cost_base": 150,
		"cost_per_level": 100,
		"stat": "kill_heal",
		"bonus_per_level": 1,
	},
	{
		"id": "jump_boost",
		"name": "hydraulic legs",
		"description": "+3% jump height per level",
		"max_level": 5,
		"cost_base": 70,
		"cost_per_level": 50,
		"stat": "jump_force",
		"bonus_per_level": 0.03,
	},
	{
		"id": "weapon_swap_speed",
		"name": "quick hands",
		"description": "faster weapon switching per level",
		"max_level": 3,
		"cost_base": 200,
		"cost_per_level": 150,
		"stat": "swap_speed",
		"bonus_per_level": 1,
	},
]


static func get_upgrade_cost(upgrade_id: String, current_level: int) -> int:
	for entry in meta_catalog:
		if entry.get("id") == upgrade_id:
			return entry.get("cost_base", 0) + entry.get("cost_per_level", 0) * current_level
	return 999999


static func get_upgrade_max_level(upgrade_id: String) -> int:
	for entry in meta_catalog:
		if entry.get("id") == upgrade_id:
			return entry.get("max_level", 0)
	return 0


static func can_purchase(profile: PlayerProfile, upgrade_id: String) -> bool:
	var current: int = profile.get_meta_level(upgrade_id)
	var max_level: int = get_upgrade_max_level(upgrade_id)
	if current >= max_level:
		return false
	var cost: int = get_upgrade_cost(upgrade_id, current)
	return profile.fracture_shards >= cost


static func purchase(profile: PlayerProfile, upgrade_id: String) -> bool:
	if not can_purchase(profile, upgrade_id):
		return false
	var current: int = profile.get_meta_level(upgrade_id)
	var cost: int = get_upgrade_cost(upgrade_id, current)
	profile.fracture_shards -= cost
	profile.meta_upgrades[upgrade_id] = current + 1
	profile.save()
	return true


# --- unlockables ---

static var unlock_catalog: Array[Dictionary] = [
	# weapon variants
	{
		"id": "rapid_beam",
		"name": "rapid beam",
		"description": "beam emitter fires 20% faster, 10% less damage",
		"category": "weapon_variant",
		"cost": 120,
		"requirement": "total_kills >= 200",
	},
	{
		"id": "wide_scatter",
		"name": "wide scatter",
		"description": "scatter cannon: +3 pellets, wider spread",
		"category": "weapon_variant",
		"cost": 120,
		"requirement": "total_kills >= 300",
	},
	{
		"id": "marksman_rifle",
		"name": "marksman rifle",
		"description": "pulse rifle: +50% damage, -30% fire rate",
		"category": "weapon_variant",
		"cost": 150,
		"requirement": "runs_completed >= 5",
	},
	# starting perks
	{
		"id": "head_start",
		"name": "head start",
		"description": "start runs with +15% move speed for 30s",
		"category": "starting_perk",
		"cost": 80,
		"requirement": "total_runs >= 10",
	},
	{
		"id": "scavenger",
		"name": "scavenger",
		"description": "first kill each room heals 10 hp",
		"category": "starting_perk",
		"cost": 100,
		"requirement": "runs_completed >= 3",
	},
	{
		"id": "glass_cannon",
		"name": "glass cannon",
		"description": "start with +20% damage, -20 max health",
		"category": "starting_perk",
		"cost": 100,
		"requirement": "bosses_defeated >= 1",
	},
	# weapon variants (higher tier)
	{
		"id": "incendiary_scatter",
		"name": "incendiary scatter",
		"description": "scatter cannon pellets ignite enemies for 3s dot",
		"category": "weapon_variant",
		"cost": 250,
		"requirement": "total_kills >= 500",
	},
	{
		"id": "charged_beam",
		"name": "charged beam",
		"description": "beam emitter: hold to charge, release for 2x burst",
		"category": "weapon_variant",
		"cost": 300,
		"requirement": "runs_completed >= 10",
	},
	{
		"id": "ricochet_rifle",
		"name": "ricochet rifle",
		"description": "pulse rifle shots bounce once off walls",
		"category": "weapon_variant",
		"cost": 350,
		"requirement": "total_kills >= 1000",
	},
	# starting perks (higher tier)
	{
		"id": "adrenaline_junkie",
		"name": "adrenaline junkie",
		"description": "start at 50% adrenaline, decays 2x faster",
		"category": "starting_perk",
		"cost": 200,
		"requirement": "runs_completed >= 8",
	},
	{
		"id": "shard_hunger",
		"name": "shard hunger",
		"description": "+15% shard drops, -10 max health",
		"category": "starting_perk",
		"cost": 180,
		"requirement": "total_runs >= 20",
	},
	{
		"id": "last_stand",
		"name": "last stand",
		"description": "below 20% hp: +40% damage, +20% speed",
		"category": "starting_perk",
		"cost": 250,
		"requirement": "bosses_defeated >= 3",
	},
	{
		"id": "momentum_start",
		"name": "momentum start",
		"description": "first dash each room grants 3s invulnerability",
		"category": "starting_perk",
		"cost": 300,
		"requirement": "pvp_wins >= 5",
	},
	# cosmetic unlocks (pure shard sinks)
	{
		"id": "trail_fracture",
		"name": "fracture trail",
		"description": "dash leaves a glowing fracture trail",
		"category": "cosmetic",
		"cost": 500,
		"requirement": "total_kills >= 2000",
	},
	{
		"id": "kill_pulse",
		"name": "kill pulse",
		"description": "enemies explode with a visual pulse on death",
		"category": "cosmetic",
		"cost": 400,
		"requirement": "best_combo >= 15",
	},
]


static func can_unlock(profile: PlayerProfile, unlock_id: String) -> bool:
	if profile.has_unlock(unlock_id):
		return false

	for entry in unlock_catalog:
		if entry.get("id") == unlock_id:
			if profile.fracture_shards < entry.get("cost", 0):
				return false
			return _check_requirement(profile, entry.get("requirement", ""))
	return false


static func purchase_unlock(profile: PlayerProfile, unlock_id: String) -> bool:
	if not can_unlock(profile, unlock_id):
		return false

	for entry in unlock_catalog:
		if entry.get("id") == unlock_id:
			profile.fracture_shards -= entry.get("cost", 0)
			profile.unlocks[unlock_id] = true
			profile.save()
			return true
	return false


static func is_requirement_met(profile: PlayerProfile, unlock_id: String) -> bool:
	for entry in unlock_catalog:
		if entry.get("id") == unlock_id:
			return _check_requirement(profile, entry.get("requirement", ""))
	return false


static func _check_requirement(profile: PlayerProfile, req: String) -> bool:
	if req.is_empty():
		return true

	var parts: PackedStringArray = req.split(" ")
	if parts.size() != 3:
		return true

	var field: String = parts[0]
	var op: String = parts[1]
	var threshold: int = parts[2].to_int()

	var value: int = 0
	match field:
		"total_kills": value = profile.total_kills
		"total_runs": value = profile.total_runs
		"runs_completed": value = profile.runs_completed
		"pvp_wins": value = profile.pvp_wins
		"bosses_defeated": value = profile.bosses_defeated
		"best_combo": value = profile.best_combo

	if op == ">=":
		return value >= threshold
	return false


# --- apply meta bonuses to player at run start ---

static func get_damage_multiplier(profile: PlayerProfile) -> float:
	var level: int = profile.get_meta_level("damage_boost")
	return 1.0 + level * 0.03


static func get_speed_multiplier(profile: PlayerProfile) -> float:
	var level: int = profile.get_meta_level("speed_boost")
	return 1.0 + level * 0.02


static func get_health_bonus(profile: PlayerProfile) -> int:
	var level: int = profile.get_meta_level("health_boost")
	return level * 8


static func get_dash_multiplier(profile: PlayerProfile) -> float:
	var level: int = profile.get_meta_level("dash_boost")
	return 1.0 - level * 0.03


static func get_shard_multiplier(profile: PlayerProfile) -> float:
	var level: int = profile.get_meta_level("shard_magnet")
	return 1.0 + level * 0.08


static func get_fire_rate_multiplier(profile: PlayerProfile) -> float:
	var level: int = profile.get_meta_level("fire_rate_boost")
	return 1.0 + level * 0.02


static func get_damage_resist_multiplier(profile: PlayerProfile) -> float:
	var level: int = profile.get_meta_level("armor_plating")
	return 1.0 - level * 0.02


static func get_kill_heal_bonus(profile: PlayerProfile) -> int:
	var level: int = profile.get_meta_level("kill_recovery")
	return level * 1


static func get_jump_multiplier(profile: PlayerProfile) -> float:
	var level: int = profile.get_meta_level("jump_boost")
	return 1.0 + level * 0.03


static func get_swap_speed_level(profile: PlayerProfile) -> int:
	return profile.get_meta_level("weapon_swap_speed")
