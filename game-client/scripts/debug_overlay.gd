extends Label

var player: CharacterBody3D
var run_manager: RunManager
var _player_manager: PlayerManager
var _network_manager: NetworkManager
var _combo: ComboTracker
var _mutation_manager: MutationManager
var _difficulty_tracker: DifficultyTracker
var _fracture_manager: FractureManager
var _room_controller: RoomController
var _weapon_manager: WeaponManager
var _debug_visible: bool = false
var _update_timer: float = 0.0

const UPDATE_INTERVAL: float = 0.1


func _ready() -> void:
	add_theme_color_override("font_color", Color(0.0, 1.0, 0.3))
	add_theme_font_size_override("font_size", 12)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		_debug_visible = not _debug_visible
		visible = _debug_visible
		if _debug_visible:
			_resolve_refs()


func _process(delta: float) -> void:
	if not _debug_visible:
		return

	_update_timer += delta
	if _update_timer < UPDATE_INTERVAL:
		return
	_update_timer = 0.0

	if not player or not is_instance_valid(player):
		_resolve_refs()
	if not player:
		return

	var lines: PackedStringArray = PackedStringArray()
	var player_count: int = _player_manager.get_player_count() if _player_manager else 1
	lines.append("fps: %d" % Engine.get_frames_per_second())

	# network info
	if _network_manager and _network_manager.is_online():
		var role: String = "host" if _network_manager.is_host() else "client"
		lines.append("net: %s | peer: %d | peers: %d | ping: %.0fms" % [
			role, _network_manager.local_peer_id, _network_manager.connected_peers.size(),
			_network_manager.estimated_ping_ms])
	else:
		lines.append("net: solo")

	lines.append("players: %d" % player_count)
	lines.append("speed: %.1f" % Vector2(player.velocity.x, player.velocity.z).length())
	var enemy_count: int = get_tree().get_nodes_in_group("enemies").size()
	lines.append("enemies: %d" % enemy_count)
	if enemy_count > 0:
		var enemy_nodes: Array[Node] = get_tree().get_nodes_in_group("enemies")
		var types: Dictionary = {}
		for e in enemy_nodes:
			if e.get_script():
				var type_name: String = e.get_script().get_path().get_file().replace("_controller.gd", "")
				types[type_name] = types.get(type_name, 0) + 1
		var parts: PackedStringArray = PackedStringArray()
		for t in types:
			parts.append("%s:%d" % [t, types[t]])
		lines.append("  comp: %s" % " ".join(parts))
	lines.append("hp: %d/%d" % [player.health, player.max_health])

	if _weapon_manager and is_instance_valid(_weapon_manager):
		lines.append("weapon: %s (dmg:%d rate:%.2f)" % [_weapon_manager.get_weapon_name(), _weapon_manager.damage, _weapon_manager.fire_rate])
		if _weapon_manager.active_slot == WeaponManager.WeaponSlot.BEAM_EMITTER:
			lines.append("heat: %.0f%% %s" % [_weapon_manager.get_beam_heat_ratio() * 100, "OVERHEAT" if _weapon_manager.is_beam_overheated() else ""])

	if _combo and _combo.combo_count > 0:
		lines.append("combo: %d (x%d) %.1fs spd:+%.0f%% dmg:+%.0f%%" % [
			_combo.combo_count, _combo.combo_multiplier, _combo.get_time_remaining(),
			_combo.speed_buff * 100, _combo.damage_buff * 100])

	if _mutation_manager and _mutation_manager.active_mutations.size() > 0:
		lines.append("mutations: %s" % " / ".join(_mutation_manager.get_mutation_names()))

	if _difficulty_tracker:
		lines.append("diff mod: %.2f" % _difficulty_tracker.get_difficulty_modifier())

	if run_manager and run_manager.data:
		var data: RunData = run_manager.data
		lines.append("---")
		lines.append("run: %s" % ["active", "paused", "failed", "done"][data.status])
		if data.current_room_index < data.room_sequence.size():
			var cur_room: RunData.RoomData = data.room_sequence[data.current_room_index]
			lines.append("room type: %s (d:%.1f)" % [RoomDefinitions.type_to_string(cur_room.type), cur_room.difficulty])
		lines.append("kills: %d" % data.total_enemies_killed)
		lines.append("upgrades: %d" % data.chosen_upgrades.size())

		if data.run_tags.size() > 0:
			lines.append("tags: %s" % " / ".join(data.run_tags))

		if _fracture_manager and _fracture_manager.is_active:
			lines.append("fracture: %s (%.1fs)" % [_fracture_manager.get_active_name(), _fracture_manager.get_time_remaining()])

		if _room_controller and _room_controller.current_palette:
			lines.append("palette: active")

		if _room_controller and _room_controller.active_boss:
			var boss_node: Node = _room_controller.active_boss
			if is_instance_valid(boss_node):
				var bh: HealthComponent = boss_node.get_node_or_null("HealthComponent") as HealthComponent
				if bh and boss_node.has_method("get_phase") and boss_node.has_method("get_health_ratio"):
					lines.append("boss: phase %d hp:%d/%d (%.0f%%)" % [
						boss_node.get_phase(), bh.current_health, bh.max_health,
						boss_node.get_health_ratio() * 100])

		lines.append("---")
		for i in data.room_sequence.size():
			var room: RunData.RoomData = data.room_sequence[i]
			var marker: String = ">" if i == data.current_room_index else " "
			var status_char: String = ([".", "*", "v"][room.status] as String)
			var type_name: String = RoomDefinitions.type_to_string(room.type)
			lines.append("%s%s %s d:%.1f e:%d" % [marker, status_char, type_name, room.difficulty, room.enemy_budget])

	text = "\n".join(lines)


func _resolve_refs() -> void:
	if not _player_manager:
		_player_manager = get_node_or_null("/root/Main/PlayerManager") as PlayerManager
	if not _network_manager:
		_network_manager = get_node_or_null("/root/NetworkManager") as NetworkManager
	if _player_manager:
		player = _player_manager.get_primary_player()
		_weapon_manager = _player_manager.get_primary_weapon_manager()
	elif not player:
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
	if not run_manager:
		run_manager = get_node_or_null("/root/Main/RunManager") as RunManager
	if not _combo:
		_combo = get_node_or_null("/root/Main/ComboTracker") as ComboTracker
	if not _mutation_manager:
		_mutation_manager = get_node_or_null("/root/Main/MutationManager") as MutationManager
	if not _difficulty_tracker:
		_difficulty_tracker = get_node_or_null("/root/Main/DifficultyTracker") as DifficultyTracker
	if not _fracture_manager:
		_fracture_manager = get_node_or_null("/root/Main/FractureManager") as FractureManager
	if not _room_controller:
		_room_controller = get_node_or_null("/root/Main/RoomController") as RoomController
