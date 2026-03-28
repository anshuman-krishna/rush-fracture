extends Control

signal restart_requested

@onready var status_label: Label = $Panel/StatusLabel
@onready var stats_label: Label = $Panel/StatsLabel
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
	stats_label.text = "rooms: %d/%d\nkills: %d\ntime: %s\nupgrades: %d" % [
		data.rooms_cleared,
		data.total_rooms(),
		data.total_enemies_killed,
		time_str,
		data.chosen_upgrades.size(),
	]

	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
