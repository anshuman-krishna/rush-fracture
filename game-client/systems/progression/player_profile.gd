class_name PlayerProfile
extends RefCounted

# persistent player profile: lifetime stats, currency, unlocks, loadout and
# cosmetics. saved to user://player_profile.cfg.
#
# the save path can be redirected (tests point it at a scratch file), and
# loading is tolerant: any missing or wrongly-typed value falls back to its
# default, so an old or hand-edited save still loads.

const DEFAULT_SAVE_PATH: String = "user://player_profile.cfg"

static var save_path: String = DEFAULT_SAVE_PATH

# lifetime stats
var total_runs: int = 0
var total_kills: int = 0
var total_time_played: float = 0.0
var best_combo: int = 0
var best_kills_single_run: int = 0
var best_time: float = 0.0
var runs_completed: int = 0
var pvp_wins: int = 0
var bosses_defeated: int = 0
var elites_killed: int = 0
var total_essence: int = 0
var endless_best_depth: int = 0
var sprint_wins: int = 0
var boss_rush_wins: int = 0
var daily_best_kills: int = 0
var daily_last_played: String = ""

# currency
var fracture_shards: int = 0

# meta upgrades purchased (id -> level)
var meta_upgrades: Dictionary = {}

# unlocked items (id -> true): weapons, skins ("skin:<id>"), perks, cosmetics
var unlocks: Dictionary = {}

# equipped
var loadout: Array[StringName] = []
var skin: StringName = &"default"

# difficulty tiers: highest unlocked, and the one currently selected
var ascension_unlocked: int = 0
var ascension_selected: int = 0

# achievements earned (id -> true)
var achievements: Dictionary = {}


static func load_profile() -> PlayerProfile:
	var profile: PlayerProfile = PlayerProfile.new()
	var config: ConfigFile = ConfigFile.new()
	if config.load(save_path) != OK:
		profile.loadout = WeaponDefs.sanitize_loadout([])
		return profile

	profile.total_runs = _safe_int(config, "stats", "total_runs", 0)
	profile.total_kills = _safe_int(config, "stats", "total_kills", 0)
	profile.total_time_played = _safe_float(config, "stats", "total_time_played", 0.0)
	profile.best_combo = _safe_int(config, "stats", "best_combo", 0)
	profile.best_kills_single_run = _safe_int(config, "stats", "best_kills_single_run", 0)
	profile.best_time = _safe_float(config, "stats", "best_time", 0.0)
	profile.runs_completed = _safe_int(config, "stats", "runs_completed", 0)
	profile.pvp_wins = _safe_int(config, "stats", "pvp_wins", 0)
	profile.bosses_defeated = _safe_int(config, "stats", "bosses_defeated", 0)
	profile.elites_killed = _safe_int(config, "stats", "elites_killed", 0)
	profile.total_essence = _safe_int(config, "stats", "total_essence", 0)
	profile.endless_best_depth = _safe_int(config, "stats", "endless_best_depth", 0)
	profile.sprint_wins = _safe_int(config, "stats", "sprint_wins", 0)
	profile.boss_rush_wins = _safe_int(config, "stats", "boss_rush_wins", 0)
	profile.daily_best_kills = _safe_int(config, "stats", "daily_best_kills", 0)
	profile.daily_last_played = _safe_string(config, "stats", "daily_last_played", "")
	profile.fracture_shards = maxi(0, _safe_int(config, "currency", "fracture_shards", 0))
	profile.ascension_unlocked = clampi(_safe_int(config, "ascension", "unlocked", 0), 0, MetaProgression.MAX_ASCENSION)
	profile.ascension_selected = clampi(_safe_int(config, "ascension", "selected", 0), 0, profile.ascension_unlocked)

	for key: String in _safe_strings(config, "meta", "upgrade_keys"):
		profile.meta_upgrades[key] = maxi(0, _safe_int(config, "meta", "upgrade_%s" % key, 0))
	for key: String in _safe_strings(config, "unlocks", "keys"):
		profile.unlocks[key] = true
	for key: String in _safe_strings(config, "achievements", "keys"):
		profile.achievements[key] = true

	var saved_skin: StringName = StringName(_safe_string(config, "cosmetics", "skin", "default"))
	profile.skin = saved_skin if profile.owns_skin(saved_skin) else &"default"

	var saved_loadout: Array = []
	for id: String in _safe_strings(config, "loadout", "weapons"):
		saved_loadout.append(id)
	profile.loadout = WeaponDefs.sanitize_loadout(saved_loadout, profile.owns_weapon)
	return profile


static func _safe_int(config: ConfigFile, section: String, key: String, fallback: int) -> int:
	var val: Variant = config.get_value(section, key, fallback)
	if val is int:
		return val
	if val is float:
		return int(val)
	return fallback


static func _safe_float(config: ConfigFile, section: String, key: String, fallback: float) -> float:
	var val: Variant = config.get_value(section, key, fallback)
	if val is float:
		return val
	if val is int:
		return float(val)
	return fallback


static func _safe_string(config: ConfigFile, section: String, key: String, fallback: String) -> String:
	var val: Variant = config.get_value(section, key, fallback)
	if val is String or val is StringName:
		return String(val)
	return fallback


static func _safe_strings(config: ConfigFile, section: String, key: String) -> PackedStringArray:
	var val: Variant = config.get_value(section, key, PackedStringArray())
	if val is PackedStringArray:
		return val
	var out: PackedStringArray = PackedStringArray()
	if val is Array:
		for item: Variant in val:
			if item is String or item is StringName:
				out.append(String(item))
	return out


func save() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("stats", "total_runs", total_runs)
	config.set_value("stats", "total_kills", total_kills)
	config.set_value("stats", "total_time_played", total_time_played)
	config.set_value("stats", "best_combo", best_combo)
	config.set_value("stats", "best_kills_single_run", best_kills_single_run)
	config.set_value("stats", "best_time", best_time)
	config.set_value("stats", "runs_completed", runs_completed)
	config.set_value("stats", "pvp_wins", pvp_wins)
	config.set_value("stats", "bosses_defeated", bosses_defeated)
	config.set_value("stats", "elites_killed", elites_killed)
	config.set_value("stats", "total_essence", total_essence)
	config.set_value("stats", "endless_best_depth", endless_best_depth)
	config.set_value("stats", "sprint_wins", sprint_wins)
	config.set_value("stats", "boss_rush_wins", boss_rush_wins)
	config.set_value("stats", "daily_best_kills", daily_best_kills)
	config.set_value("stats", "daily_last_played", daily_last_played)
	config.set_value("currency", "fracture_shards", fracture_shards)
	config.set_value("ascension", "unlocked", ascension_unlocked)
	config.set_value("ascension", "selected", ascension_selected)

	var upgrade_keys: PackedStringArray = PackedStringArray()
	for key: String in meta_upgrades:
		upgrade_keys.append(key)
		config.set_value("meta", "upgrade_%s" % key, meta_upgrades[key])
	config.set_value("meta", "upgrade_keys", upgrade_keys)

	config.set_value("unlocks", "keys", PackedStringArray(unlocks.keys()))
	config.set_value("achievements", "keys", PackedStringArray(achievements.keys()))
	config.set_value("cosmetics", "skin", String(skin))

	var weapons: PackedStringArray = PackedStringArray()
	for id: StringName in loadout:
		weapons.append(String(id))
	config.set_value("loadout", "weapons", weapons)
	config.set_value("save", "version", SaveUtil.SAVE_FORMAT_VERSION)

	SaveUtil.save_atomic(config, save_path)


## folds a finished run into the lifetime totals.
func update_from_run(data: RunData, combo_best: int, pvp_won: bool) -> void:
	total_runs += 1
	total_kills += data.total_enemies_killed
	total_time_played += data.elapsed_time
	bosses_defeated += data.bosses_defeated
	elites_killed += data.elites_killed
	total_essence += data.essence_earned
	if pvp_won:
		pvp_wins += 1
	best_kills_single_run = maxi(best_kills_single_run, data.total_enemies_killed)
	best_combo = maxi(best_combo, combo_best)

	if data.mode == RunData.MODE_ENDLESS:
		endless_best_depth = maxi(endless_best_depth, data.rooms_cleared)
	if data.mode == RunData.MODE_DAILY:
		daily_best_kills = maxi(daily_best_kills, data.total_enemies_killed)

	if data.status != RunData.RunStatus.COMPLETED:
		return
	runs_completed += 1
	match data.mode:
		RunData.MODE_SPRINT:
			sprint_wins += 1
		RunData.MODE_BOSS_RUSH:
			boss_rush_wins += 1
		RunData.MODE_STANDARD, RunData.MODE_DAILY:
			if best_time <= 0.0 or data.elapsed_time < best_time:
				best_time = data.elapsed_time
			# beating a full run on your highest tier opens the next one
			if data.ascension >= ascension_unlocked and ascension_unlocked < MetaProgression.MAX_ASCENSION:
				ascension_unlocked += 1


func get_meta_level(upgrade_id: String) -> int:
	return int(meta_upgrades.get(upgrade_id, 0))


func has_unlock(unlock_id: String) -> bool:
	return unlocks.has(unlock_id)


func owns_weapon(id: StringName) -> bool:
	return WeaponDefs.is_free(id) or unlocks.has(String(id))


func owns_skin(id: StringName) -> bool:
	return id == &"default" or unlocks.has("skin:%s" % String(id))


## puts a weapon in a loadout slot, swapping if it is already in another one.
func set_loadout_slot(slot: int, id: StringName) -> void:
	if slot < 0 or slot >= WeaponDefs.LOADOUT_SIZE or not owns_weapon(id):
		return
	loadout = WeaponDefs.sanitize_loadout(loadout, owns_weapon)
	var existing: int = loadout.find(id)
	if existing == slot:
		return
	if existing >= 0:
		loadout[existing] = loadout[slot]
	loadout[slot] = id


func get_stat_summary() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("runs: %d (%d completed)" % [total_runs, runs_completed])
	lines.append("total kills: %d" % total_kills)
	if best_combo > 0:
		lines.append("best combo: %d" % best_combo)
	if best_time > 0:
		lines.append("best time: %d:%02d" % [int(best_time) / 60, int(best_time) % 60])
	if bosses_defeated > 0:
		lines.append("bosses defeated: %d" % bosses_defeated)
	if elites_killed > 0:
		lines.append("elites killed: %d" % elites_killed)
	if endless_best_depth > 0:
		lines.append("endless depth: %d" % endless_best_depth)
	if pvp_wins > 0:
		lines.append("pvp wins: %d" % pvp_wins)
	if ascension_unlocked > 0:
		lines.append("ascension: %d" % ascension_unlocked)
	return lines
