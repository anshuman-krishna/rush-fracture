class_name InputProvider
extends RefCounted

# abstraction for player input.
# the default implementation reads the Input singleton and blends in direct
# gamepad polling. override it for bots, network puppets, or replays: the
# player and weapon code only ever talk to this interface.

const GAMEPAD_DEVICE: int = 0
const STICK_DEADZONE: float = 0.2
const TRIGGER_THRESHOLD: float = 0.3

var _prev: Dictionary = {}


func get_move_vector() -> Vector2:
	var pad: Vector2 = _gamepad_stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	if pad != Vector2.ZERO:
		return pad
	return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")


## right-stick camera look. mouse look is event-driven and handled in the
## player controller; this only covers gamepad.
func get_look_vector() -> Vector2:
	return _gamepad_stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)


func is_jump_pressed() -> bool:
	return Input.is_action_just_pressed("jump") or _pad_edge(JOY_BUTTON_A)


func is_dash_pressed() -> bool:
	return Input.is_action_just_pressed("dash") or _pad_edge(JOY_BUTTON_B)


func is_slide_held() -> bool:
	return _action_pressed("slide") or Input.is_joy_button_pressed(GAMEPAD_DEVICE, JOY_BUTTON_RIGHT_STICK)


func is_slide_pressed() -> bool:
	return _action_just_pressed("slide") or _pad_edge(JOY_BUTTON_RIGHT_STICK)


func is_shoot_held() -> bool:
	var trigger: float = Input.get_joy_axis(GAMEPAD_DEVICE, JOY_AXIS_TRIGGER_RIGHT)
	return Input.is_action_pressed("shoot") or trigger > TRIGGER_THRESHOLD


func is_ability_pressed() -> bool:
	return _action_just_pressed("ability") or _pad_edge(JOY_BUTTON_Y)


func is_interact_pressed() -> bool:
	return _action_just_pressed("interact") or _pad_edge(JOY_BUTTON_X)


func is_weapon_1_pressed() -> bool:
	return Input.is_action_just_pressed("weapon_1") or _pad_edge(JOY_BUTTON_DPAD_LEFT)


func is_weapon_2_pressed() -> bool:
	return Input.is_action_just_pressed("weapon_2") or _pad_edge(JOY_BUTTON_DPAD_UP)


func is_weapon_3_pressed() -> bool:
	return Input.is_action_just_pressed("weapon_3") or _pad_edge(JOY_BUTTON_DPAD_RIGHT)


## +1 for next weapon, -1 for previous, 0 for none. reads the mouse wheel and
## the gamepad bumpers.
func get_weapon_cycle() -> int:
	var step: int = 0
	if _action_just_pressed("weapon_next") or _pad_edge(JOY_BUTTON_RIGHT_SHOULDER):
		step += 1
	if _action_just_pressed("weapon_prev") or _pad_edge(JOY_BUTTON_LEFT_SHOULDER):
		step -= 1
	return clampi(step, -1, 1)


func _gamepad_stick(axis_x: int, axis_y: int) -> Vector2:
	var v: Vector2 = Vector2(
		Input.get_joy_axis(GAMEPAD_DEVICE, axis_x),
		Input.get_joy_axis(GAMEPAD_DEVICE, axis_y)
	)
	return v if v.length() > STICK_DEADZONE else Vector2.ZERO


func _pad_edge(button: JoyButton) -> bool:
	var held: bool = Input.is_joy_button_pressed(GAMEPAD_DEVICE, button)
	var was: bool = _prev.get(button, false)
	_prev[button] = held
	return held and not was


# the extra actions are registered at runtime (see InputSetup); guard so a
# scene that skipped that setup doesn't spam "action doesn't exist" errors.
func _action_pressed(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)


func _action_just_pressed(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_just_pressed(action)
