class_name InputProvider
extends RefCounted

# abstraction for player input.
# default implementation reads from godot Input singleton.
# override for AI, network, or replay input sources.


func get_move_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")


func is_jump_pressed() -> bool:
	return Input.is_action_just_pressed("jump")


func is_dash_pressed() -> bool:
	return Input.is_action_just_pressed("dash")


func is_shoot_held() -> bool:
	return Input.is_action_pressed("shoot")


func get_mouse_motion() -> Vector2:
	# mouse motion is handled via _unhandled_input, not polled
	return Vector2.ZERO


func is_weapon_1_pressed() -> bool:
	return Input.is_action_just_pressed("weapon_1")


func is_weapon_2_pressed() -> bool:
	return Input.is_action_just_pressed("weapon_2")


func is_weapon_3_pressed() -> bool:
	return Input.is_action_just_pressed("weapon_3")
