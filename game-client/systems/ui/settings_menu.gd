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
@onready var close_button: Button = $Panel/CloseButton


func _ready() -> void:
	visible = false
	close_button.pressed.connect(_close)
	volume_slider.value_changed.connect(_on_volume_changed)
	sens_slider.value_changed.connect(_on_sens_changed)
	invert_check.toggled.connect(_on_invert_toggled)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
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
	visible = true
	close_button.call_deferred("grab_focus")


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
