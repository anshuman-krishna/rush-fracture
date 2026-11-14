extends UiModal

# escape menu. solo it pauses the game; in multiplayer the world keeps
# running (one peer freezing its own simulation would desync it from
# everyone else), so it is only an overlay there.

signal resume_requested
signal restart_requested
signal main_menu_requested
## the player changed something in settings while paused
signal settings_changed

var _buttons: VBoxContainer
var _settings_panel: SettingsPanel


func _ready() -> void:
	panel_width = 420.0
	super._ready()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _settings_panel and _settings_panel.visible:
		return
	if _active:
		_resume()
		get_viewport().set_input_as_handled()
	elif _can_open():
		_show()
		get_viewport().set_input_as_handled()


func is_paused() -> bool:
	return _active


func _can_open() -> bool:
	# not on top of another panel: those own escape while they are open
	var parent: Node = get_parent()
	if parent:
		for sibling: Node in parent.get_children():
			if sibling != self and sibling is UiModal and (sibling as UiModal).is_open():
				return false
	return true


func _show() -> void:
	_clear_content()
	_title("paused" if not Game.is_online() else "menu", UiKit.TEXT, 32)

	var run: RunManager = Game.run()
	if run and run.data:
		var lines: PackedStringArray = PackedStringArray()
		var taken: Dictionary = {}
		for u: Dictionary in run.data.chosen_upgrades:
			var label: String = String(u.get("name", ""))
			taken[label] = int(taken.get(label, 0)) + 1
		for label: String in taken:
			lines.append(label if taken[label] == 1 else "%s x%d" % [label, taken[label]])
		for m: Dictionary in run.data.chosen_mutations:
			lines.append("%s (mutation)" % m.get("name", ""))
		if not lines.is_empty():
			_note("build: " + ", ".join(lines), UiKit.TEXT_DIM, 14)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	_content.add_child(_buttons)
	_add("resume", _resume)
	_add("settings", _open_settings)
	if Game.is_host_or_solo():
		_add("restart run", func() -> void:
			_close_quietly()
			restart_requested.emit())
	_add("main menu", func() -> void:
		_close_quietly()
		main_menu_requested.emit())
	_add("quit game", func() -> void: get_tree().quit())

	if not Game.is_online():
		get_tree().paused = true
	_open()
	_focus_first(_buttons)


func _add(text: String, callback: Callable) -> void:
	var b: Button = UiKit.button(text, 19, Vector2(0, 48))
	b.pressed.connect(callback)
	_buttons.add_child(b)


## shows the same settings screen as the main menu, over the paused game.
func _open_settings() -> void:
	if not _settings_panel:
		_settings_panel = SettingsPanel.new()
		add_child(_settings_panel)
		_settings_panel.closed.connect(_on_settings_closed)
	_panel.visible = false
	_settings_panel.open()


func _on_settings_closed() -> void:
	_panel.visible = true
	settings_changed.emit()
	if _active:
		_focus_first(_buttons)


func _resume() -> void:
	_close_quietly()
	resume_requested.emit()


func _close_quietly() -> void:
	if _settings_panel:
		_settings_panel.visible = false
	_panel.visible = true
	get_tree().paused = false
	hide_panel()
