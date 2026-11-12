extends Node

# automated playtest bot. plays whole runs through the real game scene:
# aims at the nearest enemy, keeps moving, picks rewards, advances rooms,
# and restarts from the summary screen. reports progress on stdout with a
# "[bot]" prefix so a wrapper script can grep the outcome.
#
# it deliberately goes through the same entry points a player does (the
# InputProvider interface, the reward UIs' own choice handlers, real input
# events for "continue") so a regression in any of those shows up here.

signal finished(passed: bool, reason: String)

const BotInput := preload("res://tests/bot/bot_input.gd")

# sim-seconds without any change in room/kill/enemy count before the bot
# declares the run stuck.
const STALL_SECONDS: float = 120.0

var god_mode: bool = true
var max_runs: int = 1
var max_sim_seconds: float = 1800.0
var verbose: bool = false

var _input: InputProvider
var _bound_player: Node
var _sim_time: float = 0.0
var _runs_done: int = 0
var _stall_time: float = 0.0
var _progress_key: String = ""
var _summary_handled: bool = false
var _weapon_timer: float = 0.0
var _weapon_slot: int = 0
var _dash_timer: float = 1.0
var _jump_timer: float = 2.0
var _strafe_dir: float = 1.0
var _strafe_timer: float = 3.0
var _continue_cooldown: float = 0.0
var _last_room_index: int = -1
var _done: bool = false
var results: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(delta: float) -> void:
	if _done:
		return
	_sim_time += delta
	if _sim_time > max_sim_seconds:
		_finish(false, "exceeded %.0f sim seconds" % max_sim_seconds)
		return

	var main: Node = get_tree().root.get_node_or_null("Main")
	if not main:
		return
	var gm: Node = main.get_node_or_null("GameManager")
	if not gm or not is_instance_valid(gm.get("player")):
		return

	var player: CharacterBody3D = gm.player
	_bind(player)
	_continue_cooldown = maxf(0.0, _continue_cooldown - delta)

	if _handle_onboarding(gm):
		return
	if _handle_summary(main, gm):
		return
	_summary_handled = false

	if get_tree().paused:
		return

	_handle_rewards(main, gm)
	_handle_transition(gm)
	_drive_combat(delta, main, gm, player)
	_track_progress(delta, main, gm)

	if god_mode and "health" in player and "max_health" in player:
		player.health = player.max_health


func _bind(player: CharacterBody3D) -> void:
	if player == _bound_player:
		return
	_bound_player = player
	_input = BotInput.new()
	player.input = _input
	_log("bound to player %s" % player.name)


func _handle_onboarding(gm: Node) -> bool:
	var overlay: Variant = gm.get("_onboarding")
	if overlay == null or not is_instance_valid(overlay):
		return false
	if not overlay.get("_active"):
		return false
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.pressed = true
	Input.parse_input_event(ev)
	return true


func _handle_summary(main: Node, gm: Node) -> bool:
	var summary: Control = main.get_node_or_null("UI/RunSummary") as Control
	if not summary or not summary.visible:
		return false
	if _summary_handled:
		return true
	_summary_handled = true

	var data: Variant = gm.run_manager.data
	var entry: Dictionary = {
		"run": _runs_done + 1,
		"status": "unknown",
		"rooms_cleared": 0,
		"rooms_total": 0,
		"kills": 0,
		"time": 0.0,
	}
	if data:
		entry.status = "completed" if data.status == RunData.RunStatus.COMPLETED else "failed"
		entry.rooms_cleared = data.rooms_cleared
		entry.rooms_total = data.total_rooms()
		entry.kills = data.total_enemies_killed
		entry.time = data.elapsed_time
		entry.upgrades = data.chosen_upgrades.size()
		entry.mutations = data.chosen_mutations.size()
	results.append(entry)
	_runs_done += 1
	print("[bot] run %d %s: rooms %d/%d kills %d time %.1fs" % [
		entry.run, entry.status, entry.rooms_cleared, entry.rooms_total, entry.kills, entry.time])

	if _runs_done >= max_runs:
		_finish(true, "%d run(s) finished" % _runs_done)
		return true

	# restart through the summary's own button so that path is exercised too
	_stall_time = 0.0
	_last_room_index = -1
	var btn: Variant = summary.get("restart_button")
	if btn is BaseButton:
		(btn as BaseButton).pressed.emit()
	else:
		summary.emit_signal("restart_requested")
	return true


func _handle_rewards(main: Node, gm: Node) -> void:
	if gm.get("awaiting_upgrade"):
		var ui: Control = main.get_node_or_null("UI/UpgradeSelection") as Control
		if ui and ui.get("_active") and ui.choices.size() > 0:
			var pick: Dictionary = ui.choices[randi() % ui.choices.size()]
			_log("upgrade: %s" % pick.get("name", "?"))
			ui._on_choice(pick)
	if gm.get("awaiting_mutation"):
		var mui: Control = main.get_node_or_null("UI/MutationSelection") as Control
		if mui and mui.visible and not mui.get("_chosen"):
			if mui.choices.size() > 0 and randf() < 0.7:
				var m: Dictionary = mui.choices[randi() % mui.choices.size()]
				_log("mutation: %s" % m.get("name", "?"))
				mui._on_choice(m)
			else:
				_log("mutation: skipped")
				mui._on_skip()


func _handle_transition(gm: Node) -> void:
	if not gm.get("awaiting_transition") or _continue_cooldown > 0.0:
		return
	_continue_cooldown = 0.5
	for pressed: bool in [true, false]:
		var ev: InputEventAction = InputEventAction.new()
		ev.action = "jump"
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _drive_combat(delta: float, _main: Node, _gm: Node, player: CharacterBody3D) -> void:
	var enemy: Node3D = _nearest_enemy(player)
	_input.shoot = enemy != null

	if enemy:
		_aim_at(player, _aim_point(enemy))

	# keep moving: circle-strafe, flip direction now and then, drift back to
	# the middle if the bot wanders toward the wall
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(2.0, 5.0)
		_strafe_dir = -_strafe_dir
	var forward: float = 0.0
	if enemy:
		var dist: float = player.global_position.distance_to(enemy.global_position)
		forward = -0.6 if dist > 14.0 else (0.7 if dist < 7.0 else 0.0)
	var flat: Vector2 = Vector2(player.global_position.x, player.global_position.z)
	if flat.length() > 24.0:
		forward = -1.0 if enemy == null else forward
	_input.move = Vector2(_strafe_dir, forward).normalized()

	_dash_timer -= delta
	if _dash_timer <= 0.0:
		_dash_timer = randf_range(1.5, 4.0)
		_input.queue_dash()
	_jump_timer -= delta
	if _jump_timer <= 0.0:
		_jump_timer = randf_range(1.0, 3.5)
		_input.queue_jump()

	_weapon_timer -= delta
	if _weapon_timer <= 0.0:
		_weapon_timer = 8.0
		_weapon_slot = (_weapon_slot + 1) % 3
		_input.queue_weapon(_weapon_slot)


func _nearest_enemy(player: CharacterBody3D) -> Node3D:
	var best: Node3D = null
	var best_d: float = INF
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not e is Node3D or not is_instance_valid(e):
			continue
		var hc: Node = e.get_node_or_null("HealthComponent")
		if hc and hc.has_method("is_alive") and not hc.is_alive():
			continue
		var d: float = (e as Node3D).global_position.distance_squared_to(player.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _aim_point(enemy: Node3D) -> Vector3:
	for child: Node in enemy.get_children():
		if child is CollisionShape3D:
			return (child as CollisionShape3D).global_position
	return enemy.global_position + Vector3(0, 0.8, 0)


func _aim_at(player: CharacterBody3D, point: Vector3) -> void:
	var head: Node3D = player.get_node_or_null("Head") as Node3D
	if not head:
		return
	var dir: Vector3 = point - head.global_position
	if dir.length() < 0.05:
		return
	dir = dir.normalized()
	player.rotation.y = atan2(-dir.x, -dir.z)
	head.rotation.x = clampf(asin(clampf(dir.y, -1.0, 1.0)), -PI / 2.0, PI / 2.0)


func _track_progress(delta: float, _main: Node, gm: Node) -> void:
	var data: Variant = gm.run_manager.data
	if not data:
		return
	var alive: int = get_tree().get_nodes_in_group("enemies").size()
	var key: String = "%d|%d|%d|%s" % [data.current_room_index, data.total_enemies_killed, alive, data.status]
	if data.current_room_index != _last_room_index:
		_last_room_index = data.current_room_index
		var room: Variant = data.current_room()
		if room:
			print("[bot] room %d/%d type=%s diff=%.2f t=%.1fs" % [
				data.current_room_index + 1, data.total_rooms(),
				RoomDefinitions.type_to_string(room.type), room.difficulty, _sim_time])
	if key != _progress_key:
		_progress_key = key
		_stall_time = 0.0
		return
	_stall_time += delta
	if _stall_time >= STALL_SECONDS:
		_dump_state(gm)
		_finish(false, "no progress for %.0f sim seconds (key %s)" % [STALL_SECONDS, key])


func _dump_state(gm: Node) -> void:
	print("[bot] --- stall dump ---")
	print("[bot] awaiting upgrade=%s mutation=%s transition=%s paused=%s time_scale=%.2f" % [
		gm.get("awaiting_upgrade"), gm.get("awaiting_mutation"), gm.get("awaiting_transition"),
		get_tree().paused, Engine.time_scale])
	var rc: Node = gm.get("room_controller")
	if rc:
		print("[bot] room_active=%s enemies_alive=%s" % [rc.get("room_active"), rc.get("enemies_alive")])
	if is_instance_valid(_bound_player):
		print("[bot] player pos=%s hp=%s" % [_bound_player.global_position, _bound_player.get("health")])
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if e is Node3D:
			var hc: Node = e.get_node_or_null("HealthComponent")
			print("[bot]   enemy %s pos=%s hp=%s dying=%s" % [
				e.name, (e as Node3D).global_position,
				hc.get("current_health") if hc else "?", e.get("is_dying")])


func _finish(passed: bool, reason: String) -> void:
	if _done:
		return
	_done = true
	print("[bot] %s: %s (sim %.1fs)" % ["PASS" if passed else "FAIL", reason, _sim_time])
	finished.emit(passed, reason)


func _log(msg: String) -> void:
	if verbose:
		print("[bot] ", msg)
