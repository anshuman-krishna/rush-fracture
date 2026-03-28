extends Label

var player: CharacterBody3D
var run_manager: RunManager


func _ready() -> void:
	add_theme_color_override("font_color", Color(0.0, 1.0, 0.3))
	add_theme_font_size_override("font_size", 12)


func _process(_delta: float) -> void:
	if not player:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
	if not run_manager:
		run_manager = get_tree().get_first_node_in_group("run_manager") as RunManager
		if not run_manager:
			var node := get_node_or_null("/root/Main/RunManager")
			if node is RunManager:
				run_manager = node
	if not player:
		return

	var lines := PackedStringArray()
	lines.append("fps: %d" % Engine.get_frames_per_second())
	lines.append("speed: %.1f" % Vector2(player.velocity.x, player.velocity.z).length())
	lines.append("enemies: %d" % get_tree().get_nodes_in_group("enemies").size())
	lines.append("hp: %d/%d" % [player.health, player.max_health])

	if run_manager and run_manager.data:
		var data := run_manager.data
		lines.append("---")
		lines.append("run: %s" % ["active", "paused", "failed", "done"][data.status])
		lines.append("kills: %d" % data.total_enemies_killed)
		lines.append("upgrades: %d" % data.chosen_upgrades.size())

		var fracture := get_node_or_null("/root/Main/FractureManager") as FractureManager
		if fracture and fracture.is_active:
			lines.append("fracture: %s (%.1fs)" % [fracture.get_active_name(), fracture.get_time_remaining()])

		lines.append("---")
		for i in data.room_sequence.size():
			var room := data.room_sequence[i]
			var marker := ">" if i == data.current_room_index else " "
			var status_char := [".", "*", "v"][room.status]
			var type_name := RoomDefinitions.type_to_string(room.type)
			lines.append("%s%s %s d:%.1f e:%d" % [marker, status_char, type_name, room.difficulty, room.enemy_budget])

	text = "\n".join(lines)
