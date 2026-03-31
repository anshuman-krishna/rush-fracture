class_name ComboTracker
extends Node

# tracks kill timing to build a combo multiplier.
# higher combos grant temporary speed and damage buffs.

signal combo_changed(multiplier: int, kill_count: int)
signal combo_reset

var combo_count: int = 0
var combo_multiplier: int = 1
var combo_timer: float = 0.0
var combo_window: float = 3.5
var best_combo: int = 0

# combo buffs applied to player
var speed_buff: float = 0.0
var damage_buff: float = 0.0
var _player: CharacterBody3D

# multiplier thresholds
const THRESHOLDS := [
	[3, 2],
	[6, 3],
	[10, 4],
	[15, 5],
]

# buff amounts per multiplier tier
const SPEED_BUFFS := { 2: 0.08, 3: 0.15, 4: 0.22, 5: 0.30 }
const DAMAGE_BUFFS := { 2: 0.05, 3: 0.10, 4: 0.18, 5: 0.25 }


func bind(player: CharacterBody3D) -> void:
	_player = player


func _process(delta: float) -> void:
	if combo_count <= 0:
		return

	combo_timer -= delta
	if combo_timer <= 0:
		_reset()


func register_kill() -> void:
	combo_count += 1
	combo_timer = combo_window

	var new_mult: int = 1
	for threshold in THRESHOLDS:
		if combo_count >= threshold[0]:
			new_mult = threshold[1]

	if new_mult != combo_multiplier:
		_revert_buffs()
		combo_multiplier = new_mult
		_apply_buffs()

	if combo_count > best_combo:
		best_combo = combo_count

	combo_changed.emit(combo_multiplier, combo_count)


func get_time_remaining() -> float:
	return max(0, combo_timer)


func get_damage_multiplier() -> float:
	return 1.0 + damage_buff


func reset() -> void:
	_reset()


func _apply_buffs() -> void:
	if not _player:
		return

	speed_buff = SPEED_BUFFS.get(combo_multiplier, 0.0)
	damage_buff = DAMAGE_BUFFS.get(combo_multiplier, 0.0)

	if speed_buff > 0:
		_player.move_speed *= (1.0 + speed_buff)


func _revert_buffs() -> void:
	if not _player:
		return

	if speed_buff > 0:
		_player.move_speed /= (1.0 + speed_buff)

	speed_buff = 0.0
	damage_buff = 0.0


func _reset() -> void:
	_revert_buffs()
	if combo_count > 0:
		combo_reset.emit()
	combo_count = 0
	combo_multiplier = 1
	combo_timer = 0.0
