extends Control

signal restart_requested

var status_label: Label
var stats_label: Label
var tags_label: Label
var restart_button: Button
var menu_button: Button


func _ready() -> void:
	visible = false
	_build_layout()
	restart_button.pressed.connect(func():
		visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		restart_requested.emit()
	)
	menu_button.pressed.connect(func():
		Engine.time_scale = 1.0
		var err: Error = get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		if err != OK:
			push_error("failed to return to menu: %s" % error_string(err))
	)


func _build_layout() -> void:
	# remove any scene-defined children under Panel
	var panel: PanelContainer = get_node_or_null("Panel") as PanelContainer
	if not panel:
		# create panel if missing
		panel = PanelContainer.new()
		panel.name = "Panel"
		add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(500, 420)
	panel.size = Vector2(500, 420)
	# center it
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -250
	panel.offset_top = -210
	panel.offset_right = 250
	panel.offset_bottom = 210
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	for child in panel.get_children():
		child.queue_free()

	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# status label — top, large
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 26)
	vbox.add_child(status_label)

	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	# stats — expands to fill available space
	stats_label = Label.new()
	stats_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_label.add_theme_font_size_override("font_size", 17)
	stats_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vbox.add_child(stats_label)

	# tags
	tags_label = Label.new()
	tags_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tags_label.add_theme_font_size_override("font_size", 13)
	tags_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	tags_label.visible = false
	vbox.add_child(tags_label)

	# spacer
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	# buttons at bottom — side by side
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	restart_button = Button.new()
	restart_button.text = "restart run"
	restart_button.custom_minimum_size = Vector2(170, 44)
	restart_button.add_theme_font_size_override("font_size", 17)
	restart_button.add_theme_color_override("font_color", Color(1, 0.9, 0.9))
	restart_button.add_theme_color_override("font_hover_color", Color(1, 0.3, 0.15))
	restart_button.add_theme_color_override("font_focus_color", Color(1, 0.3, 0.15))
	btn_row.add_child(restart_button)

	menu_button = Button.new()
	menu_button.text = "main menu"
	menu_button.custom_minimum_size = Vector2(170, 44)
	menu_button.add_theme_font_size_override("font_size", 17)
	menu_button.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	menu_button.add_theme_color_override("font_hover_color", Color(0.85, 0.85, 0.85))
	menu_button.add_theme_color_override("font_focus_color", Color(0.85, 0.85, 0.85))
	btn_row.add_child(menu_button)


func show_summary(data: RunData) -> void:
	if not status_label or not stats_label or not tags_label:
		push_error("run summary ui labels missing")
		return

	var is_win: bool = data.status == RunData.RunStatus.COMPLETED
	var beat_boss: bool = false
	for room in data.room_sequence:
		if room.type == RoomDefinitions.RoomType.BOSS and room.status == RoomDefinitions.RoomStatus.CLEARED:
			beat_boss = true
			break

	if beat_boss:
		status_label.text = "boss defeated"
	elif is_win:
		status_label.text = "run complete"
	else:
		status_label.text = "run failed"
	status_label.add_theme_color_override("font_color",
		Color(1.0, 0.8, 0.0) if beat_boss else (Color(0.2, 1.0, 0.3) if is_win else Color(1.0, 0.2, 0.15)))

	var time_str: String = "%d:%02d" % [int(data.elapsed_time) / 60, int(data.elapsed_time) % 60]

	var best_combo: int = 0
	var combo: ComboTracker = get_node_or_null("/root/Main/ComboTracker") as ComboTracker
	if combo:
		best_combo = combo.best_combo

	var lines: PackedStringArray = PackedStringArray()
	lines.append("rooms: %d/%d" % [data.rooms_cleared, data.total_rooms()])
	lines.append("kills: %d" % data.total_enemies_killed)
	lines.append("time: %s" % time_str)
	lines.append("upgrades: %d" % data.chosen_upgrades.size())
	lines.append("mutations: %d" % data.chosen_mutations.size())
	if best_combo > 0:
		lines.append("best combo: %d" % best_combo)

	var saved: BestStats = BestStats.load_stats()
	if saved and data.total_enemies_killed >= saved.best_kills and saved.best_kills > 0:
		lines.append(">> new best kills!")
	if saved and best_combo >= saved.best_combo and saved.best_combo > 0:
		lines.append(">> new best combo!")

	var shards_earned: int = data.metadata.get("shards_earned", 0) if data.metadata else 0
	if shards_earned > 0:
		lines.append("")
		lines.append("+%d fracture shards" % shards_earned)
		var breakdown: Dictionary = data.metadata.get("shard_breakdown", {})
		var detail_parts: PackedStringArray = PackedStringArray()
		if breakdown.get("kills", 0) > 0:
			detail_parts.append("kills:%d" % breakdown.kills)
		if breakdown.get("rooms", 0) > 0:
			detail_parts.append("rooms:%d" % breakdown.rooms)
		if breakdown.get("completed", 0) > 0:
			detail_parts.append("clear:%d" % breakdown.completed)
		if breakdown.get("bosses", 0) > 0:
			detail_parts.append("boss:%d" % breakdown.bosses)
		if breakdown.get("pvp_win", 0) > 0:
			detail_parts.append("pvp:%d" % breakdown.pvp_win)
		if breakdown.get("combo_bonus", 0) > 0:
			detail_parts.append("combo:%d" % breakdown.combo_bonus)
		if detail_parts.size() > 0:
			lines.append("  (%s)" % " + ".join(detail_parts))

	stats_label.text = "\n".join(lines)

	if data.run_tags.size() > 0:
		tags_label.text = " / ".join(data.run_tags)
		tags_label.visible = true
	else:
		tags_label.visible = false

	# staggered reveal
	status_label.modulate.a = 0.0
	stats_label.modulate.a = 0.0
	tags_label.modulate.a = 0.0
	restart_button.modulate.a = 0.0
	menu_button.modulate.a = 0.0
	modulate.a = 0.0
	visible = true

	var tween: Tween = create_tween().set_ignore_time_scale(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.tween_property(status_label, "modulate:a", 1.0, 0.2)
	tween.tween_interval(0.1)
	tween.tween_property(stats_label, "modulate:a", 1.0, 0.2)
	tween.tween_interval(0.08)
	tween.tween_property(tags_label, "modulate:a", 1.0, 0.15)
	tween.tween_interval(0.1)
	tween.tween_property(restart_button, "modulate:a", 1.0, 0.15)
	tween.tween_property(menu_button, "modulate:a", 1.0, 0.15)
	tween.tween_callback(func(): restart_button.call_deferred("grab_focus"))

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
