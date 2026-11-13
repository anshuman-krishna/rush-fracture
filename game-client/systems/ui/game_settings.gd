class_name GameSettings
extends RefCounted

# persistent game settings: audio, input, display, feel, accessibility.
# saved to user://game_settings.cfg.

const DEFAULT_SAVE_PATH: String = "user://game_settings.cfg"

static var save_path: String = DEFAULT_SAVE_PATH

# audio (0.0 to 1.0)
var master_volume: float = 0.8
var sfx_volume: float = 1.0
var music_volume: float = 0.6

# input
var mouse_sensitivity: float = 0.002
var invert_mouse_y: bool = false

# display
var fullscreen: bool = false
var vsync: bool = true
## 0 low, 1 medium, 2 high
var quality: int = 2
var fov: float = 90.0

# feel and accessibility
## 0 turns camera shake off, 1 is full
var screen_shake: float = 1.0
## 0 turns hit-stop off, 1 is full
var hit_stop: float = 1.0
var damage_numbers: bool = true
var hud_scale: float = 1.0

# onboarding
var has_seen_onboarding: bool = false

# key rebinding — action name -> physical keycode override. actions not
# present here use whatever the input map has by default.
const REBINDABLE_ACTIONS: PackedStringArray = [
	"move_forward", "move_backward", "move_left", "move_right",
	"jump", "dash", "slide", "ability", "weapon_1", "weapon_2", "weapon_3",
]
var key_bindings: Dictionary = {}


static func load_settings() -> GameSettings:
	var s: GameSettings = GameSettings.new()
	var config: ConfigFile = ConfigFile.new()
	if config.load(save_path) != OK:
		return s

	s.master_volume = _num(config, "audio", "master_volume", 0.8, 0.0, 1.0)
	s.sfx_volume = _num(config, "audio", "sfx_volume", 1.0, 0.0, 1.0)
	s.music_volume = _num(config, "audio", "music_volume", 0.6, 0.0, 1.0)
	s.mouse_sensitivity = _num(config, "input", "mouse_sensitivity", 0.002, 0.0005, 0.01)
	s.invert_mouse_y = config.get_value("input", "invert_mouse_y", false) == true
	s.fullscreen = config.get_value("display", "fullscreen", false) == true
	s.vsync = config.get_value("display", "vsync", true) != false
	s.quality = int(_num(config, "display", "quality", 2.0, 0.0, 2.0))
	s.fov = _num(config, "display", "fov", 90.0, 70.0, 120.0)
	s.screen_shake = _num(config, "feel", "screen_shake", 1.0, 0.0, 1.0)
	s.hit_stop = _num(config, "feel", "hit_stop", 1.0, 0.0, 1.0)
	s.damage_numbers = config.get_value("feel", "damage_numbers", true) != false
	s.hud_scale = _num(config, "feel", "hud_scale", 1.0, 0.75, 1.5)
	s.has_seen_onboarding = config.get_value("flags", "has_seen_onboarding", false) == true

	var kb_keys: Variant = config.get_value("keybinds", "keys", PackedStringArray())
	if kb_keys is PackedStringArray:
		for action: String in kb_keys:
			var code: Variant = config.get_value("keybinds", "key_%s" % action, 0)
			if code is int and code != 0:
				s.key_bindings[action] = code
	return s


static func _num(config: ConfigFile, section: String, key: String, fallback: float, lo: float, hi: float) -> float:
	var v: Variant = config.get_value(section, key, fallback)
	if v is float or v is int:
		return clampf(float(v), lo, hi)
	return fallback


func save() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("input", "invert_mouse_y", invert_mouse_y)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "vsync", vsync)
	config.set_value("display", "quality", quality)
	config.set_value("display", "fov", fov)
	config.set_value("feel", "screen_shake", screen_shake)
	config.set_value("feel", "hit_stop", hit_stop)
	config.set_value("feel", "damage_numbers", damage_numbers)
	config.set_value("feel", "hud_scale", hud_scale)
	config.set_value("flags", "has_seen_onboarding", has_seen_onboarding)

	var kb_keys: PackedStringArray = PackedStringArray()
	for action: String in key_bindings:
		kb_keys.append(action)
		config.set_value("keybinds", "key_%s" % action, key_bindings[action])
	config.set_value("keybinds", "keys", kb_keys)
	config.set_value("save", "version", SaveUtil.SAVE_FORMAT_VERSION)
	SaveUtil.save_atomic(config, save_path)


## applies everything that is global (audio buses, window, key bindings).
## per-scene things (fov, shake) are read by the nodes that use them.
func apply() -> void:
	InputSetup.ensure()
	_apply_volume()
	_apply_display()
	_apply_key_bindings()


func _apply_key_bindings() -> void:
	for action: String in key_bindings:
		if not InputMap.has_action(action):
			continue
		_bind(action, key_bindings[action])


func _bind(action: String, physical_keycode: int) -> void:
	# replace only the keyboard events, so a gamepad or mouse binding on the
	# same action survives a rebind
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = physical_keycode as Key
	InputMap.action_add_event(action, key)


## current physical keycode for a rebindable action.
func get_key_for_action(action: String) -> int:
	if key_bindings.has(action):
		return key_bindings[action]
	if not InputMap.has_action(action):
		return KEY_NONE
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return (ev as InputEventKey).physical_keycode
	return KEY_NONE


func set_key_for_action(action: String, physical_keycode: int) -> void:
	key_bindings[action] = physical_keycode
	if InputMap.has_action(action):
		_bind(action, physical_keycode)
	save()


## the binding an action ships with: project.godot for the original actions,
## InputSetup's table for the ones registered at runtime.
func _default_keycode(action: String) -> int:
	var setting: Variant = ProjectSettings.get_setting("input/%s" % action, {})
	if setting is Dictionary and setting.has("events"):
		for ev: InputEvent in setting["events"]:
			if ev is InputEventKey:
				return (ev as InputEventKey).physical_keycode
	var extra: Array = InputSetup.EXTRA_ACTIONS.get(action, [])
	if not extra.is_empty():
		return int(extra[0])
	return KEY_NONE


func _reset_key_no_save(action: String) -> void:
	key_bindings.erase(action)
	var default_code: int = _default_keycode(action)
	if default_code != KEY_NONE and InputMap.has_action(action):
		_bind(action, default_code)


func reset_key_for_action(action: String) -> void:
	_reset_key_no_save(action)
	save()


func reset_all_key_bindings() -> void:
	for action: String in REBINDABLE_ACTIONS:
		_reset_key_no_save(action)
	save()


func _apply_volume() -> void:
	_set_bus("Master", master_volume)
	_set_bus("SFX", sfx_volume)
	_set_bus("Music", music_volume)


func _set_bus(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.0)
	if linear > 0.0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))


func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var want: int = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
