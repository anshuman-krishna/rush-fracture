extends Control

signal restart_requested

@onready var status_label: Label = $Panel/StatusLabel
@onready var stats_label: Label = $Panel/StatsLabel
@onready var tags_label: Label = $Panel/TagsLabel
@onready var restart_button: Button = $Panel/RestartButton
@onready var menu_button: Button = $Panel/MenuButton


func _ready() -> void:
	visible = false
	restart_button.pressed.connect(func():
		visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		restart_requested.emit()
	)
	menu_button.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)


func show_summary(data: RunData) -> void:
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
	lines.append("best combo: %d" % best_combo)

	# show personal best markers
	var saved: BestStats = BestStats.load_stats()
	if data.total_enemies_killed >= saved.best_kills and saved.best_kills > 0:
		lines.append(">> new best kills!")
	if best_combo >= saved.best_combo and saved.best_combo > 0:
		lines.append(">> new best combo!")

	stats_label.text = "\n".join(lines)

	if data.run_tags.size() > 0:
		tags_label.text = " / ".join(data.run_tags)
		tags_label.visible = true
	else:
		tags_label.visible = false

	modulate.a = 0.0
	visible = true
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
