class_name DifficultyTracker
extends Node

# subtly adjusts room pressure based on player performance.
# never punishing, never obvious. just keeps the game in the sweet spot.

var performance_score: float = 0.0
var rooms_tracked: int = 0

# tracked per room
var _room_kills: int = 0
var _room_damage_taken: int = 0
var _room_time: float = 0.0
var _room_active: bool = false


func _process(delta: float) -> void:
	if _room_active:
		_room_time += delta


func on_room_entered() -> void:
	_room_kills = 0
	_room_damage_taken = 0
	_room_time = 0.0
	_room_active = true


func on_enemy_killed() -> void:
	_room_kills += 1


func on_player_damaged(amount: int) -> void:
	_room_damage_taken += amount


func on_room_cleared() -> void:
	_room_active = false
	rooms_tracked += 1
	_evaluate_room()


func get_difficulty_modifier() -> float:
	# returns a subtle modifier between 0.85 and 1.15
	return clampf(1.0 + performance_score * 0.05, 0.85, 1.15)


func reset() -> void:
	performance_score = 0.0
	rooms_tracked = 0
	_room_kills = 0
	_room_damage_taken = 0
	_room_time = 0.0
	_room_active = false


func _evaluate_room() -> void:
	var score_delta: float = 0.0

	# fast clear = doing well
	if _room_time < 12.0:
		score_delta += 0.5
	elif _room_time < 20.0:
		score_delta += 0.2
	elif _room_time > 35.0:
		score_delta -= 0.3

	# low damage taken = doing well
	if _room_damage_taken == 0:
		score_delta += 0.4
	elif _room_damage_taken < 20:
		score_delta += 0.1
	elif _room_damage_taken > 50:
		score_delta -= 0.4

	# blend toward the new signal, keeping history
	performance_score = performance_score * 0.7 + score_delta * 0.3
