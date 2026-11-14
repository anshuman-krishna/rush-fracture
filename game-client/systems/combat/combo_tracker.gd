class_name ComboTracker
extends Node

# kills in quick succession build a combo. higher tiers make the player
# faster and hit harder for as long as the chain holds.
#
# both buffs are stat modifiers under the "combo" key, so they stack cleanly
# with everything else and vanish the instant the combo drops. (the damage
# half of this used to be computed and then never read by anything.)

signal combo_changed(multiplier: int, kill_count: int)
signal combo_reset

const COMBO_WINDOW: float = 3.5

# kills needed -> multiplier
const THRESHOLDS: Array = [[3, 2], [6, 3], [10, 4], [15, 5], [25, 6]]
const SPEED_BUFFS: Dictionary = {2: 0.06, 3: 0.11, 4: 0.16, 5: 0.22, 6: 0.28}
const DAMAGE_BUFFS: Dictionary = {2: 0.06, 3: 0.12, 4: 0.18, 5: 0.25, 6: 0.33}

var combo_count: int = 0
var combo_multiplier: int = 1
var combo_timer: float = 0.0
var combo_window: float = COMBO_WINDOW
var best_combo: int = 0

var _player: CharacterBody3D


func bind(player: CharacterBody3D) -> void:
	_player = player


func _process(delta: float) -> void:
	if combo_count <= 0:
		return
	combo_timer -= delta
	if combo_timer <= 0.0:
		_end()


func register_kill() -> void:
	combo_count += 1
	combo_timer = _window()
	var new_mult: int = 1
	for threshold: Array in THRESHOLDS:
		if combo_count >= threshold[0]:
			new_mult = threshold[1]
	if new_mult != combo_multiplier:
		combo_multiplier = new_mult
		_apply()
	best_combo = maxi(best_combo, combo_count)
	combo_changed.emit(combo_multiplier, combo_count)


## 0..1, how much of the window is left before the combo drops.
func time_ratio() -> float:
	if combo_count <= 0:
		return 0.0
	return clampf(combo_timer / _window(), 0.0, 1.0)


## how long a kill keeps the chain alive, with the player's upgrades.
func _window() -> float:
	if is_instance_valid(_player) and "stats" in _player:
		return combo_window * _player.stats.value(&"combo_time")
	return combo_window


func get_time_remaining() -> float:
	return maxf(0.0, combo_timer)


## ends the current chain. the best combo of the run is kept until reset_run().
func reset() -> void:
	_end()


func reset_run() -> void:
	_end()
	best_combo = 0


func _apply() -> void:
	if not is_instance_valid(_player) or not "stats" in _player:
		return
	_player.stats.set_mul(&"move_speed", &"combo", 1.0 + float(SPEED_BUFFS.get(combo_multiplier, 0.0)))
	_player.stats.set_mul(&"damage", &"combo", 1.0 + float(DAMAGE_BUFFS.get(combo_multiplier, 0.0)))


func _end() -> void:
	var had: bool = combo_count > 0
	combo_count = 0
	combo_multiplier = 1
	combo_timer = 0.0
	_apply()
	if had:
		combo_reset.emit()
