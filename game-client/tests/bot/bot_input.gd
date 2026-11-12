extends InputProvider

# scripted input source used by the automated playtest bot. the driver sets
# these fields every physics frame; the player and weapon code read them
# through the same InputProvider interface a human's keyboard goes through.

var move: Vector2 = Vector2.ZERO
var shoot: bool = false
var alt_fire: bool = false

var _jump_queued: bool = false
var _dash_queued: bool = false
var _slide_held: bool = false
var _weapon_queued: int = -1


func queue_jump() -> void:
	_jump_queued = true


func queue_dash() -> void:
	_dash_queued = true


func queue_weapon(slot: int) -> void:
	_weapon_queued = slot


func set_slide(held: bool) -> void:
	_slide_held = held


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


func is_shoot_held() -> bool:
	return shoot


func is_weapon_1_pressed() -> bool:
	return _take_weapon(0)


func is_weapon_2_pressed() -> bool:
	return _take_weapon(1)


func is_weapon_3_pressed() -> bool:
	return _take_weapon(2)


func _take_weapon(slot: int) -> bool:
	if _weapon_queued == slot:
		_weapon_queued = -1
		return true
	return false
