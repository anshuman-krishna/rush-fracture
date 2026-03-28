extends Control

signal restart_requested

@onready var status_label: Label = $Panel/StatusLabel
@onready var stats_label: Label = $Panel/StatsLabel
@onready var tags_label: Label = $Panel/TagsLabel
@onready var restart_button: Button = $Panel/RestartButton


func _ready() -> void:
	visible = false
	restart_button.pressed.connect(func():
		visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		restart_requested.emit()
	)


func show_summary(data: RunData) -> void:
	var is_win := data.status == RunData.RunStatus.COMPLETED

	status_label.text = "run complete" if is_win else "run failed"
	status_label.add_theme_color_override("font_color",
		Color(0.2, 1.0, 0.3) if is_win else Color(1.0, 0.2, 0.15))

	var time_str := "%d:%02d" % [int(data.elapsed_time) / 60, int(data.elapsed_time) % 60]

	var best_combo := 0
	var combo := get_node_or_null("/root/Main/ComboTracker") as ComboTracker
	if combo:
		best_combo = combo.best_combo

	var lines := PackedStringArray()
	lines.append("rooms: %d/%d" % [data.rooms_cleared, data.total_rooms()])
	lines.append("kills: %d" % data.total_enemies_killed)
	lines.append("time: %s" % time_str)
	lines.append("upgrades: %d" % data.chosen_upgrades.size())
	lines.append("mutations: %d" % data.chosen_mutations.size())
	lines.append("best combo: %d" % best_combo)
	stats_label.text = "\n".join(lines)

	# run tags
	if data.run_tags.size() > 0:
		tags_label.text = " / ".join(data.run_tags)
		tags_label.visible = true
	else:
		tags_label.visible = false

	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
