class_name DifficultyTracker
extends Node

# nudges room pressure toward how the player is actually doing: slightly
# more when rooms are being cleared fast and clean, slightly less when they
# are slow and costly. solo only (in co-op every peer must build the same room).

var performance_score: float = 0.0
var rooms_tracked: int = 0

var _room_damage_taken: int = 0
var _room_time: float = 0.0
var _room_active: bool = false


func _process(delta: float) -> void:
	if _room_active:
		_room_time += delta


func on_room_entered() -> void:
	_room_damage_taken = 0
	_room_time = 0.0
	_room_active = true


func on_player_damaged(amount: int) -> void:
	_room_damage_taken += amount


func on_room_cleared() -> void:
	if not _room_active:
		return
	_room_active = false
	rooms_tracked += 1
	_evaluate_room()


## multiplier for the next room's spawn budget, between 0.85 and 1.15.
func get_difficulty_modifier() -> float:
	return clampf(1.0 + performance_score * 0.05, 0.85, 1.15)


func reset() -> void:
	performance_score = 0.0
	rooms_tracked = 0
	_room_damage_taken = 0
	_room_time = 0.0
	_room_active = false


func _evaluate_room() -> void:
	var delta_score: float = 0.0
	if _room_time < 14.0:
		delta_score += 0.5
	elif _room_time < 24.0:
		delta_score += 0.2
	elif _room_time > 45.0:
		delta_score -= 0.3

	if _room_damage_taken == 0:
		delta_score += 0.4
	elif _room_damage_taken < 20:
		delta_score += 0.1
	elif _room_damage_taken > 50:
		delta_score -= 0.4

	performance_score = performance_score * 0.7 + delta_score * 3.0 * 0.3
