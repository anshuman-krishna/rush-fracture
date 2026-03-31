class_name PlayerProfile
extends RefCounted

# persistent player profile. tracks lifetime stats, currency, and unlocks.
# saved to user://player_profile.cfg.

const SAVE_PATH := "user://player_profile.cfg"

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

# currency
var fracture_shards: int = 0

# meta upgrades purchased (id -> level)
var meta_upgrades: Dictionary = {}

# unlocked items (id -> true)
var unlocks: Dictionary = {}


static func load_profile() -> PlayerProfile:
	var profile: PlayerProfile = PlayerProfile.new()
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return profile

	profile.total_runs = config.get_value("stats", "total_runs", 0)
	profile.total_kills = config.get_value("stats", "total_kills", 0)
	profile.total_time_played = config.get_value("stats", "total_time_played", 0.0)
	profile.best_combo = config.get_value("stats", "best_combo", 0)
	profile.best_kills_single_run = config.get_value("stats", "best_kills_single_run", 0)
	profile.best_time = config.get_value("stats", "best_time", 0.0)
	profile.runs_completed = config.get_value("stats", "runs_completed", 0)
	profile.pvp_wins = config.get_value("stats", "pvp_wins", 0)
	profile.bosses_defeated = config.get_value("stats", "bosses_defeated", 0)
	profile.fracture_shards = config.get_value("currency", "fracture_shards", 0)

	# load meta upgrades
	var upgrade_keys: PackedStringArray = config.get_value("meta", "upgrade_keys", PackedStringArray())
	for key in upgrade_keys:
		profile.meta_upgrades[key] = config.get_value("meta", "upgrade_%s" % key, 0)

	# load unlocks
	var unlock_keys: PackedStringArray = config.get_value("unlocks", "keys", PackedStringArray())
	for key in unlock_keys:
		profile.unlocks[key] = true

	return profile


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
	config.set_value("currency", "fracture_shards", fracture_shards)

	# save meta upgrades
	var upgrade_keys: PackedStringArray = PackedStringArray()
	for key: String in meta_upgrades:
		upgrade_keys.append(key)
		config.set_value("meta", "upgrade_%s" % key, meta_upgrades[key])
	config.set_value("meta", "upgrade_keys", upgrade_keys)

	# save unlocks
	var unlock_keys: PackedStringArray = PackedStringArray()
	for key: String in unlocks:
		unlock_keys.append(key)
	config.set_value("unlocks", "keys", unlock_keys)

	config.save(SAVE_PATH)


func update_from_run(data: RunData, combo_best: int, pvp_won: bool) -> void:
	total_runs += 1
	total_kills += data.total_enemies_killed
	total_time_played += data.elapsed_time

	if data.status == RunData.RunStatus.COMPLETED:
		runs_completed += 1

	if pvp_won:
		pvp_wins += 1

	if data.total_enemies_killed > best_kills_single_run:
		best_kills_single_run = data.total_enemies_killed
	if combo_best > best_combo:
		best_combo = combo_best
	if data.status == RunData.RunStatus.COMPLETED:
		if best_time <= 0 or data.elapsed_time < best_time:
			best_time = data.elapsed_time

	# check for boss defeats
	for room in data.room_sequence:
		if room.type == RoomDefinitions.RoomType.BOSS and room.status == RoomDefinitions.RoomStatus.CLEARED:
			bosses_defeated += 1


func get_meta_level(upgrade_id: String) -> int:
	return meta_upgrades.get(upgrade_id, 0)


func has_unlock(unlock_id: String) -> bool:
	return unlock_id in unlocks


func get_stat_summary() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("runs: %d (%d completed)" % [total_runs, runs_completed])
	lines.append("total kills: %d" % total_kills)
	if best_combo > 0:
		lines.append("best combo: %d" % best_combo)
	if best_time > 0:
		lines.append("best time: %d:%02d" % [int(best_time) / 60, int(best_time) % 60])
	if pvp_wins > 0:
		lines.append("pvp wins: %d" % pvp_wins)
	if bosses_defeated > 0:
		lines.append("bosses defeated: %d" % bosses_defeated)
	return lines
