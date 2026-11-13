class_name SettingsPanel
extends Control

# settings: audio, controls, display, feel, and key rebinding. every change
# is applied and saved immediately.

signal closed

const ACTION_LABELS: Dictionary = {
	"move_forward": "move forward", "move_backward": "move backward",
	"move_left": "move left", "move_right": "move right",
	"jump": "jump", "dash": "dash", "slide": "slide / slam", "ability": "ability",
	"weapon_1": "weapon 1", "weapon_2": "weapon 2", "weapon_3": "weapon 3",
}
const QUALITY_NAMES: Array[String] = ["low", "medium", "high"]

var _settings: GameSettings
var _list: VBoxContainer
var _listening_action: String = ""
var _key_buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 70)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 60)
	margin.add_theme_constant_override("margin_right", 70)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.custom_minimum_size = Vector2(760, 0)
	margin.add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	col.add_child(UiKit.label("settings", 34, UiKit.ACCENT, true))

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 640)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)

	var back: Button = UiKit.button("back", 18, Vector2(180, 44))
	back.pressed.connect(_close)
	col.add_child(back)


func open() -> void:
	_settings = GameSettings.load_settings()
	_listening_action = ""
	visible = true
	_rebuild()


func _close() -> void:
	_listening_action = ""
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not _listening_action.is_empty():
		if event is InputEventKey and event.pressed and not event.echo:
			get_viewport().set_input_as_handled()
			var key: InputEventKey = event as InputEventKey
			if key.keycode != KEY_ESCAPE:
				var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
				_settings.set_key_for_action(_listening_action, code)
			_listening_action = ""
			_refresh_keys()
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _rebuild() -> void:
	for child: Node in _list.get_children():
		child.queue_free()
	_key_buttons.clear()

	_heading("audio")
	_slider("master volume", _settings.master_volume, 0.0, 1.0, 0.05, func(v: float) -> void: _settings.master_volume = v, true)
	_slider("effects volume", _settings.sfx_volume, 0.0, 1.0, 0.05, func(v: float) -> void: _settings.sfx_volume = v, true)
	_slider("music volume", _settings.music_volume, 0.0, 1.0, 0.05, func(v: float) -> void: _settings.music_volume = v, true)

	_heading("controls")
	_slider("mouse sensitivity", _settings.mouse_sensitivity * 1000.0, 0.5, 10.0, 0.1,
		func(v: float) -> void: _settings.mouse_sensitivity = v / 1000.0)
	_toggle("invert vertical look", _settings.invert_mouse_y, func(v: bool) -> void: _settings.invert_mouse_y = v)

	_heading("display")
	_slider("field of view", _settings.fov, 70.0, 120.0, 1.0, func(v: float) -> void: _settings.fov = v)
	_toggle("fullscreen", _settings.fullscreen, func(v: bool) -> void: _settings.fullscreen = v)
	_toggle("vertical sync", _settings.vsync, func(v: bool) -> void: _settings.vsync = v)
	_choice("graphics quality", QUALITY_NAMES, _settings.quality, func(i: int) -> void: _settings.quality = i)

	_heading("feel")
	_slider("screen shake", _settings.screen_shake, 0.0, 1.0, 0.05, func(v: float) -> void: _settings.screen_shake = v, true)
	_slider("hit stop", _settings.hit_stop, 0.0, 1.0, 0.05, func(v: float) -> void: _settings.hit_stop = v, true)
	_slider("hud size", _settings.hud_scale, 0.75, 1.5, 0.05, func(v: float) -> void: _settings.hud_scale = v, true)
	_toggle("damage numbers", _settings.damage_numbers, func(v: bool) -> void: _settings.damage_numbers = v)

	_heading("key bindings")
	for action: String in GameSettings.REBINDABLE_ACTIONS:
		_key_row(action)
	var reset: Button = UiKit.button("reset all keys", 16, Vector2(220, 40))
	reset.pressed.connect(func() -> void:
		_settings.reset_all_key_bindings()
		_refresh_keys())
	_list.add_child(reset)


func _commit() -> void:
	_settings.save()
	_settings.apply()


func _heading(text: String) -> void:
	var l: Label = UiKit.label(text, 17, UiKit.WARN, true)
	_list.add_child(l)


func _row(text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l: Label = UiKit.label(text, 17, UiKit.TEXT)
	l.custom_minimum_size = Vector2(260, 0)
	row.add_child(l)
	_list.add_child(row)
	return row


func _slider(text: String, value: float, lo: float, hi: float, step: float, apply_value: Callable, percent: bool = false) -> void:
	var row: HBoxContainer = _row(text)
	var slider: HSlider = HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(300, 28)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var readout: Label = UiKit.label(_format(value, percent), 16, UiKit.TEXT_DIM)
	readout.custom_minimum_size = Vector2(70, 0)
	row.add_child(readout)
	slider.value_changed.connect(func(v: float) -> void:
		apply_value.call(v)
		readout.text = _format(v, percent)
		_commit())


func _format(v: float, percent: bool) -> String:
	if percent:
		return "%d%%" % int(round(v * 100.0))
	return ("%d" % int(v)) if is_equal_approx(v, round(v)) else ("%.1f" % v)


func _toggle(text: String, value: bool, apply_value: Callable) -> void:
	var row: HBoxContainer = _row(text)
	var b: Button = UiKit.button("on" if value else "off", 16, Vector2(110, 36))
	b.toggle_mode = true
	b.button_pressed = value
	b.toggled.connect(func(pressed: bool) -> void:
		b.text = "on" if pressed else "off"
		apply_value.call(pressed)
		_commit())
	row.add_child(b)


func _choice(text: String, names: Array[String], index: int, apply_value: Callable) -> void:
	var row: HBoxContainer = _row(text)
	var b: Button = UiKit.button(names[clampi(index, 0, names.size() - 1)], 16, Vector2(160, 36))
	var state: Array = [clampi(index, 0, names.size() - 1)]
	b.pressed.connect(func() -> void:
		state[0] = (state[0] + 1) % names.size()
		b.text = names[state[0]]
		apply_value.call(state[0])
		_commit())
	row.add_child(b)


func _key_row(action: String) -> void:
	var row: HBoxContainer = _row(ACTION_LABELS.get(action, action))
	var b: Button = UiKit.button("", 16, Vector2(200, 36))
	b.pressed.connect(func() -> void:
		_listening_action = action
		_refresh_keys())
	row.add_child(b)
	var clear: Button = UiKit.button("default", 14, Vector2(100, 36))
	clear.pressed.connect(func() -> void:
		_settings.reset_key_for_action(action)
		_refresh_keys())
	row.add_child(clear)
	_key_buttons[action] = b
	_refresh_keys()


func _refresh_keys() -> void:
	for action: String in _key_buttons:
		var b: Button = _key_buttons[action]
		if not is_instance_valid(b):
			continue
		if action == _listening_action:
			b.text = "press a key..."
		else:
			var code: int = _settings.get_key_for_action(action)
			b.text = OS.get_keycode_string(code) if code != KEY_NONE else "unbound"
