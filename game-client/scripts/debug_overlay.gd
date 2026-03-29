extends Label

var player: CharacterBody3D
var run_manager: RunManager
var _player_manager: PlayerManager
var _debug_visible: bool = false


func _ready() -> void:
	add_theme_color_override("font_color", Color(0.0, 1.0, 0.3))
	add_theme_font_size_override("font_size", 12)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		_debug_visible = not _debug_visible
		visible = _debug_visible


func _process(_delta: float) -> void:
	if not _debug_visible:
		return
	if not _player_manager:
		_player_manager = get_node_or_null("/root/Main/PlayerManager") as PlayerManager
	if not player:
		if _player_manager:
			player = _player_manager.get_primary_player()
		else:
			var players: Array[Node] = get_tree().get_nodes_in_group("player")
			if players.size() > 0:
				player = players[0]
	if not run_manager:
		run_manager = get_tree().get_first_node_in_group("run_manager") as RunManager
		if not run_manager:
			var node: Node = get_node_or_null("/root/Main/RunManager")
			if node is RunManager:
				run_manager = node
	if not player:
		return

	var lines: PackedStringArray = PackedStringArray()
	var player_count: int = _player_manager.get_player_count() if _player_manager else 1
	lines.append("fps: %d" % Engine.get_frames_per_second())
	lines.append("players: %d" % player_count)
	lines.append("speed: %.1f" % Vector2(player.velocity.x, player.velocity.z).length())
	lines.append("enemies: %d" % get_tree().get_nodes_in_group("enemies").size())
	lines.append("hp: %d/%d" % [player.health, player.max_health])

	var wm: WeaponManager = _player_manager.get_primary_weapon_manager() if _player_manager else null
	if wm:
		lines.append("weapon: %s (dmg:%d rate:%.2f)" % [wm.get_weapon_name(), wm.damage, wm.fire_rate])
		if wm.active_slot == WeaponManager.WeaponSlot.BEAM_EMITTER:
			lines.append("heat: %.0f%% %s" % [wm.get_beam_heat_ratio() * 100, "OVERHEAT" if wm.is_beam_overheated() else ""])

	var combo: ComboTracker = get_node_or_null("/root/Main/ComboTracker") as ComboTracker
	if combo and combo.combo_count > 0:
		lines.append("combo: %d (x%d) %.1fs spd:+%.0f%% dmg:+%.0f%%" % [
			combo.combo_count, combo.combo_multiplier, combo.get_time_remaining(),
			combo.speed_buff * 100, combo.damage_buff * 100])

	var mm: MutationManager = get_node_or_null("/root/Main/MutationManager") as MutationManager
	if mm and mm.active_mutations.size() > 0:
		lines.append("mutations: %s" % " / ".join(mm.get_mutation_names()))

	var dt: DifficultyTracker = get_node_or_null("/root/Main/DifficultyTracker") as DifficultyTracker
	if dt:
		lines.append("diff mod: %.2f" % dt.get_difficulty_modifier())

	if run_manager and run_manager.data:
		var data: RunData = run_manager.data
		lines.append("---")
		lines.append("run: %s" % ["active", "paused", "failed", "done"][data.status])
		lines.append("kills: %d" % data.total_enemies_killed)
		lines.append("upgrades: %d" % data.chosen_upgrades.size())

		if data.run_tags.size() > 0:
			lines.append("tags: %s" % " / ".join(data.run_tags))

		var fracture: FractureManager = get_node_or_null("/root/Main/FractureManager") as FractureManager
		if fracture and fracture.is_active:
			lines.append("fracture: %s (%.1fs)" % [fracture.get_active_name(), fracture.get_time_remaining()])

		# room controller info
		var rc: RoomController = get_node_or_null("/root/Main/RoomController") as RoomController
		if rc and rc.current_palette:
			lines.append("palette: active")

		if rc and rc.active_boss:
			var boss: BossController = rc.active_boss
			var bh: HealthComponent = boss.get_node_or_null("HealthComponent") as HealthComponent
			if bh:
				lines.append("boss: phase %d hp:%d/%d (%.0f%%)" % [
					boss.get_phase(), bh.current_health, bh.max_health,
					boss.get_health_ratio() * 100])

		lines.append("---")
		for i in data.room_sequence.size():
			var room: RunData.RoomData = data.room_sequence[i]
			var marker: String = ">" if i == data.current_room_index else " "
			var status_char: String = ([".", "*", "v"][room.status] as String)
			var type_name: String = RoomDefinitions.type_to_string(room.type)
			lines.append("%s%s %s d:%.1f e:%d" % [marker, status_char, type_name, room.difficulty, room.enemy_budget])

	text = "\n".join(lines)
