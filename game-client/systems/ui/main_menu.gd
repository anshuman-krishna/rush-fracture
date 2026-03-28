extends Control

# main menu — entry point. aggressive, minimal.

@onready var title_label: Label = $Panel/TitleLabel
@onready var tagline_label: Label = $Panel/TaglineLabel
@onready var start_button: Button = $Panel/StartButton
@onready var best_stats_label: Label = $Panel/BestStatsLabel
@onready var quit_button: Button = $Panel/QuitButton


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	start_button.pressed.connect(_on_start)
	quit_button.pressed.connect(_on_quit)
	start_button.grab_focus()
	_show_best_stats()
	_animate_in()


func _on_start() -> void:
	_animate_out(func():
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)


func _on_quit() -> void:
	get_tree().quit()


func _show_best_stats() -> void:
	var stats := BestStats.load_stats()
	if stats.best_kills <= 0 and stats.best_combo <= 0:
		best_stats_label.visible = false
		return

	var lines := PackedStringArray()
	if stats.best_kills > 0:
		lines.append("best kills: %d" % stats.best_kills)
	if stats.best_combo > 0:
		lines.append("best combo: %d" % stats.best_combo)
	if stats.best_time > 0:
		var m := int(stats.best_time) / 60
		var s := int(stats.best_time) % 60
		lines.append("best time: %d:%02d" % [m, s])
	if stats.runs_completed > 0:
		lines.append("runs completed: %d" % stats.runs_completed)

	best_stats_label.text = " / ".join(lines)
	best_stats_label.visible = true


func _animate_in() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.4)


func _animate_out(callback: Callable) -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(callback)
