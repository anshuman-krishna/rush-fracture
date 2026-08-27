class_name GameSettings
extends RefCounted

# persistent game settings. volume, sensitivity, display, accessibility.
# saved to user://game_settings.cfg.

const SAVE_PATH := "user://game_settings.cfg"

# audio
var master_volume: float = 0.8  # 0.0 to 1.0

# input
var mouse_sensitivity: float = 0.002
var invert_mouse_y: bool = false

# display
var fullscreen: bool = false

# onboarding
var has_seen_onboarding: bool = false

# key rebinding — action name -> physical keycode override. actions not
# present here use whatever project.godot's default input map has.
const REBINDABLE_ACTIONS: PackedStringArray = [
	"move_forward", "move_backward", "move_left", "move_right",
	"jump", "dash", "weapon_1", "weapon_2", "weapon_3",
]
var key_bindings: Dictionary = {}


static func load_settings() -> GameSettings:
	var settings: GameSettings = GameSettings.new()
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load(SAVE_PATH)
	if err != OK:
		return settings

	var vol: Variant = config.get_value("audio", "master_volume", 0.8)
	settings.master_volume = clampf(float(vol) if (vol is float or vol is int) else 0.8, 0.0, 1.0)

	var sens: Variant = config.get_value("input", "mouse_sensitivity", 0.002)
	settings.mouse_sensitivity = clampf(float(sens) if (sens is float or sens is int) else 0.002, 0.0005, 0.01)

	var inv: Variant = config.get_value("input", "invert_mouse_y", false)
	settings.invert_mouse_y = inv == true

	var fs: Variant = config.get_value("display", "fullscreen", false)
	settings.fullscreen = fs == true

	var seen: Variant = config.get_value("flags", "has_seen_onboarding", false)
	settings.has_seen_onboarding = seen == true

	var kb_keys: Variant = config.get_value("keybinds", "keys", PackedStringArray())
	if kb_keys is PackedStringArray:
		for action: String in kb_keys:
			var code: Variant = config.get_value("keybinds", "key_%s" % action, 0)
			if code is int and code != 0:
				settings.key_bindings[action] = code

	return settings


func save() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("input", "invert_mouse_y", invert_mouse_y)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("flags", "has_seen_onboarding", has_seen_onboarding)

	var kb_keys: PackedStringArray = PackedStringArray()
	for action: String in key_bindings:
		kb_keys.append(action)
		config.set_value("keybinds", "key_%s" % action, key_bindings[action])
	config.set_value("keybinds", "keys", kb_keys)

	config.set_value("save", "version", SaveUtil.SAVE_FORMAT_VERSION)
	SaveUtil.save_atomic(config, SAVE_PATH)


func apply() -> void:
	_apply_volume()
	_apply_fullscreen()
	_apply_key_bindings()


func _apply_key_bindings() -> void:
	for action: String in key_bindings:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		var ev: InputEventKey = InputEventKey.new()
		ev.physical_keycode = key_bindings[action]
		InputMap.action_add_event(action, ev)


## current physical keycode for a rebindable action — the saved override if
## one exists, otherwise whatever's live in the input map right now.
func get_key_for_action(action: String) -> int:
	if key_bindings.has(action):
		return key_bindings[action]
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return ev.physical_keycode
	return KEY_NONE


func set_key_for_action(action: String, physical_keycode: int) -> void:
	key_bindings[action] = physical_keycode
	InputMap.action_erase_events(action)
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = physical_keycode
	InputMap.action_add_event(action, ev)
	save()


func _apply_volume() -> void:
	var bus_idx: int = AudioServer.get_bus_index("Master")
	if bus_idx < 0:
		return
	if master_volume <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(master_volume))


func _apply_fullscreen() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
