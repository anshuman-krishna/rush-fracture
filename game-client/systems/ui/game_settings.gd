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

	return settings


func save() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("input", "invert_mouse_y", invert_mouse_y)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("flags", "has_seen_onboarding", has_seen_onboarding)
	config.save(SAVE_PATH)


func apply() -> void:
	_apply_volume()
	_apply_fullscreen()


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
