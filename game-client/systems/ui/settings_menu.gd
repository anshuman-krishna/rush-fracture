class_name SettingsMenu
extends Control

# settings overlay. volume, sensitivity, display, input options.

signal closed

var _settings: GameSettings

@onready var volume_slider: HSlider = $Panel/VolumeRow/VolumeSlider
@onready var volume_value: Label = $Panel/VolumeRow/VolumeValue
@onready var sens_slider: HSlider = $Panel/SensRow/SensSlider
@onready var sens_value: Label = $Panel/SensRow/SensValue
@onready var invert_check: CheckButton = $Panel/InvertRow/InvertCheck
@onready var fullscreen_check: CheckButton = $Panel/FullscreenRow/FullscreenCheck
@onready var keybind_list: VBoxContainer = $Panel/KeybindScroll/KeybindList
@onready var reset_keys_button: Button = $Panel/ResetKeysButton
@onready var close_button: Button = $Panel/CloseButton

var _listening_action: String = ""
var _keybind_buttons: Dictionary = {}

const ACTION_LABELS: Dictionary = {
	"move_forward": "move forward",
	"move_backward": "move backward",
	"move_left": "move left",
	"move_right": "move right",
	"jump": "jump",
	"dash": "dash",
	"weapon_1": "weapon 1",
	"weapon_2": "weapon 2",
	"weapon_3": "weapon 3",
}


func _ready() -> void:
	visible = false
	close_button.pressed.connect(_close)
	volume_slider.value_changed.connect(_on_volume_changed)
	sens_slider.value_changed.connect(_on_sens_changed)
	invert_check.toggled.connect(_on_invert_toggled)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	reset_keys_button.pressed.connect(_on_reset_keys_pressed)
	_apply_style()


func _apply_style() -> void:
	if close_button:
		close_button.add_theme_font_size_override("font_size", 17)
		close_button.custom_minimum_size = Vector2(120, 40)
	if volume_value:
		volume_value.add_theme_font_size_override("font_size", 16)
	if sens_value:
		sens_value.add_theme_font_size_override("font_size", 16)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if _listening_action != "":
		if event is InputEventKey and event.pressed and not event.echo:
			get_viewport().set_input_as_handled()
			if event.physical_keycode == KEY_ESCAPE:
				_cancel_listening()
			else:
				_finish_rebind(event.physical_keycode)
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()


func show_settings() -> void:
	_settings = GameSettings.load_settings()
	volume_slider.value = _settings.master_volume
	sens_slider.value = _settings.mouse_sensitivity
	invert_check.button_pressed = _settings.invert_mouse_y
	fullscreen_check.button_pressed = _settings.fullscreen
	_update_labels()
	_build_keybind_rows()
	visible = true
	close_button.call_deferred("grab_focus")


func _build_keybind_rows() -> void:
	for child in keybind_list.get_children():
		child.queue_free()
	_keybind_buttons.clear()

	for action: String in GameSettings.REBINDABLE_ACTIONS:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		keybind_list.add_child(row)

		var label: Label = Label.new()
		label.text = ACTION_LABELS.get(action, action)
		label.custom_minimum_size = Vector2(140, 0)
		label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		label.add_theme_font_size_override("font_size", 14)
		row.add_child(label)

		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(110, 32)
		button.text = OS.get_keycode_string(_settings.get_key_for_action(action))
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(_on_rebind_pressed.bind(action, button))
		row.add_child(button)

		_keybind_buttons[action] = button


func _on_rebind_pressed(action: String, button: Button) -> void:
	if _listening_action != "":
		return
	_listening_action = action
	button.text = "press a key..."


func _cancel_listening() -> void:
	if _listening_action == "":
		return
	var button: Button = _keybind_buttons.get(_listening_action)
	if button:
		button.text = OS.get_keycode_string(_settings.get_key_for_action(_listening_action))
	_listening_action = ""


func _finish_rebind(physical_keycode: int) -> void:
	var action: String = _listening_action
	_listening_action = ""
	_settings.set_key_for_action(action, physical_keycode)
	var button: Button = _keybind_buttons.get(action)
	if button:
		button.text = OS.get_keycode_string(physical_keycode)


func _on_volume_changed(value: float) -> void:
	_settings.master_volume = value
	_update_labels()
	_settings.apply()
	_settings.save()


func _on_sens_changed(value: float) -> void:
	_settings.mouse_sensitivity = value
	_update_labels()
	_settings.save()


func _on_invert_toggled(pressed: bool) -> void:
	_settings.invert_mouse_y = pressed
	_settings.save()


func _on_fullscreen_toggled(pressed: bool) -> void:
	_settings.fullscreen = pressed
	_settings.apply()
	_settings.save()


func _on_reset_keys_pressed() -> void:
	if _listening_action != "":
		_cancel_listening()
	_settings.reset_all_key_bindings()
	_build_keybind_rows()


func _update_labels() -> void:
	volume_value.text = "%d%%" % int(_settings.master_volume * 100)
	var sens_display: float = _settings.mouse_sensitivity * 1000.0
	if absf(sens_display - roundf(sens_display)) < 0.05:
		sens_value.text = "%d" % int(sens_display)
	else:
		sens_value.text = "%.1f" % sens_display


func _close() -> void:
	visible = false
	closed.emit()
