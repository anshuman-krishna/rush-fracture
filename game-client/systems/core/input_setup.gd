class_name InputSetup
extends RefCounted

# registers the input actions the game needs on top of the ones stored in
# project.godot. done in code so the action list lives next to the systems
# that read it, and so adding one never means hand-editing serialized
# InputEvent resources.

const EXTRA_ACTIONS: Dictionary = {
	"slide": [KEY_CTRL, KEY_C],
	"ability": [KEY_Q],
	"interact": [KEY_E],
	"scoreboard": [KEY_TAB],
}

static var _done: bool = false


static func ensure() -> void:
	if _done:
		return
	_done = true

	for action: String in EXTRA_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.5)
		for code: int in EXTRA_ACTIONS[action]:
			var ev: InputEventKey = InputEventKey.new()
			ev.physical_keycode = code as Key
			InputMap.action_add_event(action, ev)

	_add_mouse_action("alt_fire", MOUSE_BUTTON_RIGHT)
	_add_mouse_action("weapon_next", MOUSE_BUTTON_WHEEL_DOWN)
	_add_mouse_action("weapon_prev", MOUSE_BUTTON_WHEEL_UP)


static func _add_mouse_action(action: String, button: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.5)
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


## first keyboard key bound to an action, as display text ("Ctrl", "Q").
static func key_label(action: String) -> String:
	if not InputMap.has_action(action):
		return "?"
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var k: InputEventKey = ev as InputEventKey
			var code: int = k.physical_keycode if k.physical_keycode != 0 else k.keycode
			return OS.get_keycode_string(code)
		if ev is InputEventMouseButton:
			match (ev as InputEventMouseButton).button_index:
				MOUSE_BUTTON_LEFT: return "LMB"
				MOUSE_BUTTON_RIGHT: return "RMB"
				MOUSE_BUTTON_MIDDLE: return "MMB"
				MOUSE_BUTTON_WHEEL_UP: return "Wheel Up"
				MOUSE_BUTTON_WHEEL_DOWN: return "Wheel Down"
	return "?"
