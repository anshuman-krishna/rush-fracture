extends InputProvider

# scripted input source used by the automated playtest bot. the driver sets
# these fields every physics frame; the player and weapon code read them
# through the same InputProvider interface a human's keyboard goes through.
# nothing here touches the real Input singleton.

var move: Vector2 = Vector2.ZERO
var shoot: bool = false
var slide: bool = false

var _jump_queued: bool = false
var _dash_queued: bool = false
var _slide_queued: bool = false
var _weapon_queued: int = -1
var _cycle_queued: int = 0


func queue_jump() -> void:
	_jump_queued = true


func queue_dash() -> void:
	_dash_queued = true


func queue_slide_press() -> void:
	_slide_queued = true


func queue_weapon(slot: int) -> void:
	_weapon_queued = slot


func queue_cycle(step: int) -> void:
	_cycle_queued = step


func get_move_vector() -> Vector2:
	return move


func get_look_vector() -> Vector2:
	return Vector2.ZERO


func is_jump_pressed() -> bool:
	var v: bool = _jump_queued
	_jump_queued = false
	return v


func is_dash_pressed() -> bool:
	var v: bool = _dash_queued
	_dash_queued = false
	return v


func is_slide_held() -> bool:
	return slide


func is_slide_pressed() -> bool:
	var v: bool = _slide_queued
	_slide_queued = false
	return v


func is_shoot_held() -> bool:
	return shoot


func is_ability_pressed() -> bool:
	return false


func is_interact_pressed() -> bool:
	return false


func is_weapon_1_pressed() -> bool:
	return _take_weapon(0)


func is_weapon_2_pressed() -> bool:
	return _take_weapon(1)


func is_weapon_3_pressed() -> bool:
	return _take_weapon(2)


func get_weapon_cycle() -> int:
	var v: int = _cycle_queued
	_cycle_queued = 0
	return v


func _take_weapon(slot: int) -> bool:
	if _weapon_queued == slot:
		_weapon_queued = -1
		return true
	return false
