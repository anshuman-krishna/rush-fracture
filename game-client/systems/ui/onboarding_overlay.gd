class_name OnboardingOverlay
extends Control

# first-run controls card. shown once, dismissed with any key, click or button.

signal dismissed

var _active: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

	add_child(UiKit.backdrop(0.78))
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	centre.add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var title: Label = UiKit.label("break speed. survive chaos.", 32, UiKit.ACCENT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var lead: Label = UiKit.label("you are safest when you are fastest. never stand still.", 17, UiKit.TEXT_DIM)
	lead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(lead)
	col.add_child(HSeparator.new())

	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(grid)
	var rows: Array = [
		["move", "W A S D"],
		["look / fire", "mouse / left click"],
		["jump", _key("jump")],
		["dash (brief invulnerability, passes through enemies)", _key("dash")],
		["slide (hold while running); slam (press in the air)", _key("slide")],
		["weapons", "1  2  3  or mouse wheel"],
		["hide hud", "F2"],
		["pause", "Esc"],
	]
	for row: Array in rows:
		var name_label: Label = UiKit.label(row[0], 17, UiKit.TEXT_DIM)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(name_label)
		grid.add_child(UiKit.label(row[1], 19, UiKit.TEXT, true))

	col.add_child(HSeparator.new())
	for tip: String in [
		"red circles and lanes on the floor are attacks about to land. get out of them.",
		"rings that travel along the floor can be jumped.",
		"hits to the head or a boss's glowing core do extra damage.",
	]:
		var t: Label = UiKit.label(tip, 16, UiKit.TEXT)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(t)

	var go: Label = UiKit.label("press any key to begin", 18, UiKit.WARN, true)
	go.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(go)


func _key(action: String) -> String:
	InputSetup.ensure()
	return InputSetup.key_label(action)


func show_onboarding() -> void:
	_active = true
	visible = true
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	var pressed: bool = false
	if event is InputEventKey and event.pressed and not event.echo:
		pressed = true
	elif event is InputEventMouseButton and event.pressed:
		pressed = true
	elif event is InputEventJoypadButton and event.pressed:
		pressed = true
	if pressed:
		get_viewport().set_input_as_handled()
		_dismiss()


func _gui_input(event: InputEvent) -> void:
	if _active and event is InputEventMouseButton and event.pressed:
		accept_event()
		_dismiss()


func _dismiss() -> void:
	if not _active:
		return
	_active = false
	var settings: GameSettings = GameSettings.load_settings()
	settings.has_seen_onboarding = true
	settings.save()
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func() -> void:
		visible = false
		dismissed.emit()
		queue_free())
