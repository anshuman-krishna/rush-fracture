class_name GameModeManager
extends Node

# tracks the active game mode and provides mode-specific rules.
# created by main menu, persists as root-level node alongside NetworkManager.

signal mode_changed(mode: GameMode)
signal pvp_encounter_started
signal pvp_encounter_ended(winner_peer_id: int)
signal race_finished(winner_peer_id: int)

enum GameMode {
	COOP,
	RACE,
	PVP_ENCOUNTER,
}

var current_mode: GameMode = GameMode.COOP
var pvp_active: bool = false

# race mode state
var race_rooms_before_encounter: int = 4
var race_progress: Dictionary = {}  # peer_id -> rooms_cleared

# pvp state
var pvp_damage_scale: float = 0.3  # scale down player-vs-player damage
var pvp_kills: Dictionary = {}  # peer_id -> kills in pvp
var _pvp_winner: int = -1

# score tracking
var scores: Dictionary = {}  # peer_id -> MatchScore


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


func get_mode_name() -> String:
	match current_mode:
		GameMode.COOP:
			return "co-op"
		GameMode.RACE:
			return "race"
		GameMode.PVP_ENCOUNTER:
			return "pvp encounter"
	return "unknown"


# --- race mode ---

func register_race_peer(peer_id: int) -> void:
	race_progress[peer_id] = 0
	_ensure_score(peer_id)


func on_race_room_cleared(peer_id: int) -> void:
	race_progress[peer_id] = race_progress.get(peer_id, 0) + 1
	scores[peer_id].rooms_cleared += 1


func should_start_encounter() -> bool:
	if not is_race():
		return false
	for peer_id: int in race_progress:
		if race_progress[peer_id] >= race_rooms_before_encounter:
			return true
	return false


func get_race_leader() -> int:
	var best_peer: int = -1
	var best_rooms: int = -1
	for peer_id: int in race_progress:
		if race_progress[peer_id] > best_rooms:
			best_rooms = race_progress[peer_id]
			best_peer = peer_id
	return best_peer


# --- pvp ---

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
	if killer_peer_id in scores:
		scores[killer_peer_id].pvp_kills += 1


# --- scoring ---

func _ensure_score(peer_id: int) -> void:
	if peer_id not in scores:
		scores[peer_id] = MatchScore.new()
		scores[peer_id].peer_id = peer_id


func register_kill(peer_id: int) -> void:
	_ensure_score(peer_id)
	scores[peer_id].enemy_kills += 1


func register_damage_dealt(peer_id: int, amount: int) -> void:
	_ensure_score(peer_id)
	scores[peer_id].damage_dealt += amount


func register_upgrade(peer_id: int) -> void:
	_ensure_score(peer_id)
	scores[peer_id].upgrades_collected += 1


func get_winner() -> int:
	if _pvp_winner >= 0:
		return _pvp_winner

	# fallback: highest score
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


# --- match score data ---

class MatchScore extends RefCounted:
	var peer_id: int = 0
	var enemy_kills: int = 0
	var damage_dealt: int = 0
	var upgrades_collected: int = 0
	var rooms_cleared: int = 0
	var pvp_kills: int = 0
	var pvp_wins: int = 0

	func total_score() -> int:
		return enemy_kills * 10 + damage_dealt + upgrades_collected * 50 + rooms_cleared * 100 + pvp_kills * 200 + pvp_wins * 500

	func to_dict() -> Dictionary:
		return {
			"peer_id": peer_id,
			"enemy_kills": enemy_kills,
			"damage_dealt": damage_dealt,
			"upgrades_collected": upgrades_collected,
			"rooms_cleared": rooms_cleared,
			"pvp_kills": pvp_kills,
			"pvp_wins": pvp_wins,
			"total": total_score(),
		}
