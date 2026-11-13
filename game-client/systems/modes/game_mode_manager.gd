class_name GameModeManager
extends Node

# what kind of game is being played and the options chosen for it.
# created by the main menu and parented to the scene tree root so it survives
# the change into the run scene.

signal mode_changed(mode: GameMode)
signal pvp_encounter_started
signal pvp_encounter_ended(winner_peer_id: int)

## how players relate to each other
enum GameMode {
	COOP,
	RACE,
	PVP_ENCOUNTER,
}

var current_mode: GameMode = GameMode.COOP
## the shape of the run itself (RunData.MODE_*)
var run_mode: StringName = RunData.MODE_STANDARD
var ascension: int = 0
## 0 = pick a random seed
var custom_seed: int = 0
var pvp_active: bool = false

# race state
var race_rooms_before_encounter: int = 4
var race_progress: Dictionary = {}

# pvp state
var pvp_damage_scale: float = 0.3
var pvp_kills: Dictionary = {}
var _pvp_winner: int = -1

# per-peer match scores
var scores: Dictionary = {}


func set_mode(mode: GameMode) -> void:
	current_mode = mode
	pvp_active = false
	race_progress.clear()
	pvp_kills.clear()
	scores.clear()
	_pvp_winner = -1
	mode_changed.emit(mode)


func is_coop() -> bool:
	return current_mode == GameMode.COOP


func is_race() -> bool:
	return current_mode == GameMode.RACE


func is_pvp_mode() -> bool:
	return current_mode == GameMode.PVP_ENCOUNTER


## race and pvp use the short fixed versus map instead of a full run
func is_versus() -> bool:
	return current_mode != GameMode.COOP


func get_mode_name() -> String:
	match current_mode:
		GameMode.COOP: return "co-op"
		GameMode.RACE: return "race"
		GameMode.PVP_ENCOUNTER: return "pvp encounter"
	return "unknown"


static func run_mode_name(mode: StringName) -> String:
	match mode:
		RunData.MODE_STANDARD: return "standard run"
		RunData.MODE_SPRINT: return "sprint"
		RunData.MODE_ENDLESS: return "endless"
		RunData.MODE_BOSS_RUSH: return "boss rush"
		RunData.MODE_DAILY: return "daily run"
		RunData.MODE_VERSUS: return "versus"
	return String(mode)


static func run_mode_description(mode: StringName) -> String:
	match mode:
		RunData.MODE_STANDARD: return "three acts, three bosses. choose your path."
		RunData.MODE_SPRINT: return "one act, one boss. ten minutes."
		RunData.MODE_ENDLESS: return "acts never stop. how deep can you get?"
		RunData.MODE_BOSS_RUSH: return "every boss, back to back, with an armory stop between."
		RunData.MODE_DAILY: return "today's seed. the same run for everyone."
	return ""


## the seed every player gets for today's daily run.
static func daily_seed() -> int:
	var d: Dictionary = Time.get_date_dict_from_system(true)
	return int(d.year) * 10000 + int(d.month) * 100 + int(d.day)


static func daily_key() -> String:
	var d: Dictionary = Time.get_date_dict_from_system(true)
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


# --- race ------------------------------------------------------------------------

func register_race_peer(peer_id: int) -> void:
	race_progress[peer_id] = 0
	ensure_score(peer_id)


func on_race_room_cleared(peer_id: int) -> void:
	race_progress[peer_id] = race_progress.get(peer_id, 0) + 1
	ensure_score(peer_id)
	scores[peer_id].rooms_cleared += 1


func should_start_encounter() -> bool:
	if not is_race():
		return false
	for peer_id: int in race_progress:
		if race_progress[peer_id] >= race_rooms_before_encounter:
			return true
	return false


# --- pvp -------------------------------------------------------------------------

func start_pvp() -> void:
	pvp_active = true
	pvp_kills.clear()
	pvp_encounter_started.emit()


func end_pvp(winner_peer_id: int) -> void:
	pvp_active = false
	_pvp_winner = winner_peer_id
	if winner_peer_id in scores:
		scores[winner_peer_id].pvp_wins += 1
	pvp_encounter_ended.emit(winner_peer_id)


func get_pvp_damage(base_damage: int) -> int:
	return maxi(int(base_damage * pvp_damage_scale), 1)


func register_pvp_kill(killer_peer_id: int) -> void:
	pvp_kills[killer_peer_id] = pvp_kills.get(killer_peer_id, 0) + 1
	ensure_score(killer_peer_id)
	scores[killer_peer_id].pvp_kills += 1


# --- scoring -----------------------------------------------------------------------

func ensure_score(peer_id: int) -> void:
	if peer_id not in scores:
		scores[peer_id] = MatchScore.new()
		scores[peer_id].peer_id = peer_id


func register_kill(peer_id: int) -> void:
	ensure_score(peer_id)
	scores[peer_id].enemy_kills += 1


func register_damage_dealt(peer_id: int, amount: int) -> void:
	ensure_score(peer_id)
	scores[peer_id].damage_dealt += amount


func get_winner() -> int:
	if _pvp_winner >= 0:
		return _pvp_winner
	var best_peer: int = -1
	var best_score: int = -1
	for peer_id: int in scores:
		var s: int = scores[peer_id].total_score()
		if s > best_score:
			best_score = s
			best_peer = peer_id
	return best_peer


func get_score_summary() -> Dictionary:
	var result: Dictionary = {}
	for peer_id: int in scores:
		result[peer_id] = scores[peer_id].to_dict()
	return result


class MatchScore extends RefCounted:
	var peer_id: int = 0
	var enemy_kills: int = 0
	var damage_dealt: int = 0
	var rooms_cleared: int = 0
	var pvp_kills: int = 0
	var pvp_wins: int = 0

	func total_score() -> int:
		return enemy_kills * 10 + damage_dealt + rooms_cleared * 100 + pvp_kills * 200 + pvp_wins * 500

	func to_dict() -> Dictionary:
		return {
			"peer_id": peer_id,
			"enemy_kills": enemy_kills,
			"damage_dealt": damage_dealt,
			"rooms_cleared": rooms_cleared,
			"pvp_kills": pvp_kills,
			"pvp_wins": pvp_wins,
			"total": total_score(),
		}
