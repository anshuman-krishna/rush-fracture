class_name InputProvider
extends RefCounted

# abstraction for player input.
# default implementation reads from godot Input singleton, blended with
# direct gamepad polling (added without touching project.godot's input map
# — see REMAINING.md for why: a malformed hand-edit to that file's
# serialized InputEvent resources risks breaking the whole project in a
# way that isn't verifiable without a godot install).
# override for AI, network, or replay input sources.

const GAMEPAD_DEVICE: int = 0
const STICK_DEADZONE: float = 0.2
const TRIGGER_THRESHOLD: float = 0.3

var _prev_jump: bool = false
var _prev_dash: bool = false
var _prev_weapon_1: bool = false
var _prev_weapon_2: bool = false
var _prev_weapon_3: bool = false


func get_move_vector() -> Vector2:
	var pad: Vector2 = _gamepad_stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	if pad != Vector2.ZERO:
		return pad
	return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")


## right-stick camera look. mouse look is separate (event-driven, handled
## in player_controller.gd's _input()) — this only covers gamepad.
func get_look_vector() -> Vector2:
	return _gamepad_stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)


func _gamepad_stick(axis_x: int, axis_y: int) -> Vector2:
	var v: Vector2 = Vector2(
		Input.get_joy_axis(GAMEPAD_DEVICE, axis_x),
		Input.get_joy_axis(GAMEPAD_DEVICE, axis_y)
	)
	return v if v.length() > STICK_DEADZONE else Vector2.ZERO


func is_jump_pressed() -> bool:
	var pad_held: bool = Input.is_joy_button_pressed(GAMEPAD_DEVICE, JOY_BUTTON_A)
	var edge: bool = pad_held and not _prev_jump
	_prev_jump = pad_held
	return Input.is_action_just_pressed("jump") or edge


func is_dash_pressed() -> bool:
	var pad_held: bool = Input.is_joy_button_pressed(GAMEPAD_DEVICE, JOY_BUTTON_B)
	var edge: bool = pad_held and not _prev_dash
	_prev_dash = pad_held
	return Input.is_action_just_pressed("dash") or edge


func is_shoot_held() -> bool:
	var trigger: float = Input.get_joy_axis(GAMEPAD_DEVICE, JOY_AXIS_TRIGGER_RIGHT)
	return Input.is_action_pressed("shoot") or trigger > TRIGGER_THRESHOLD


func get_mouse_motion() -> Vector2:
	# mouse motion is handled via _unhandled_input, not polled
	return Vector2.ZERO


func is_weapon_1_pressed() -> bool:
	var pad_held: bool = Input.is_joy_button_pressed(GAMEPAD_DEVICE, JOY_BUTTON_DPAD_LEFT)
	var edge: bool = pad_held and not _prev_weapon_1
	_prev_weapon_1 = pad_held
	return Input.is_action_just_pressed("weapon_1") or edge


func is_weapon_2_pressed() -> bool:
	var pad_held: bool = Input.is_joy_button_pressed(GAMEPAD_DEVICE, JOY_BUTTON_DPAD_UP)
	var edge: bool = pad_held and not _prev_weapon_2
	_prev_weapon_2 = pad_held
	return Input.is_action_just_pressed("weapon_2") or edge


func is_weapon_3_pressed() -> bool:
	var pad_held: bool = Input.is_joy_button_pressed(GAMEPAD_DEVICE, JOY_BUTTON_DPAD_RIGHT)
	var edge: bool = pad_held and not _prev_weapon_3
	_prev_weapon_3 = pad_held
	return Input.is_action_just_pressed("weapon_3") or edge
