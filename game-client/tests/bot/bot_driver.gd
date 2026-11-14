extends Node

# automated playtest bot. plays whole runs through the real game scene:
# aims at the nearest enemy, keeps moving (strafe, dash, jump, slide), picks
# rewards, chooses paths, shops, and restarts from the summary screen.
# progress goes to stdout with a "[bot]" prefix so a wrapper can grep it.
#
# it goes through the same entry points a player does (the InputProvider
# interface, each panel's own choice handlers, a real input event for
# "continue"), so a regression in any of those shows up here.

signal finished(passed: bool, reason: String)

const BotInput := preload("res://tests/bot/bot_input.gd")

# sim-seconds without any change in room/kill/enemy count before the bot
# declares the run stuck.
const STALL_SECONDS: float = 150.0

var god_mode: bool = true
var max_runs: int = 1
var max_sim_seconds: float = 3600.0
var verbose: bool = false
## stop a run after this many rooms (0 = play to the end). for endless.
var room_limit: int = 0
## 1.0 aims perfectly and never stops moving. lower values add aim error,
## slower tracking, fewer dashes and the odd pause, to stand in for a person.
var skill: float = 1.0

var results: Array[Dictionary] = []

var _input: InputProvider
var _bound_player: Node
var _sim_time: float = 0.0
var _runs_done: int = 0
var _stall_time: float = 0.0
var _progress_key: String = ""
var _summary_handled: bool = false
var _weapon_timer: float = 4.0
var _weapon_slot: int = 0
var _dash_timer: float = 1.0
var _jump_timer: float = 2.0
var _slide_timer: float = 3.0
var _slide_left: float = 0.0
var _strafe_dir: float = 1.0
var _strafe_timer: float = 3.0
var _continue_cooldown: float = 0.0
var _panel_delay: float = 0.0
var _last_room_index: int = -1
var _done: bool = false
var _aim_noise: Vector2 = Vector2.ZERO
var _noise_timer: float = 0.0
var _pause_left: float = 0.0
var _in_duel: bool = false
var _recent_hits: Array[String] = []

## print frame times for every room. only means something in a real window
## at real speed (no --headless, no --fixed-fps).
var perf: bool = false
## upgrade ids handed to the bot at the start of every run ("all" for the
## whole catalogue, each at its maximum), so one run exercises every effect.
var grant_upgrades: PackedStringArray = PackedStringArray()
var _granted: bool = false
var _perf_clock: int = 0
var _perf_frames: int = 0
var _perf_total_msec: float = 0.0
var _perf_worst_msec: float = 0.0
var _perf_slow_frames: int = 0
var _perf_peak_enemies: int = 0
var _perf_peak_draws: int = 0
var _perf_peak_nodes: int = 0
var _perf_room: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if not perf or _done:
		return
	var now: int = Time.get_ticks_usec()
	if _perf_clock > 0 and not get_tree().paused:
		var msec: float = float(now - _perf_clock) / 1000.0
		_perf_frames += 1
		_perf_total_msec += msec
		_perf_worst_msec = maxf(_perf_worst_msec, msec)
		if msec > 20.0:
			_perf_slow_frames += 1
		_perf_peak_enemies = maxi(_perf_peak_enemies, get_tree().get_nodes_in_group("enemies").size())
		_perf_peak_draws = maxi(_perf_peak_draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		_perf_peak_nodes = maxi(_perf_peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	_perf_clock = now


## closes the measurements for the room just left and starts the next.
func _perf_next_room(label: String) -> void:
	if not perf:
		return
	if _perf_frames > 30:
		print("[bot] perf %s: %d frames, avg %.1f ms (%.0f fps), worst %.1f ms, %d over 20 ms, peak enemies %d, draw calls %d, nodes %d" % [
			_perf_room, _perf_frames, _perf_total_msec / float(_perf_frames), 1000.0 * float(_perf_frames) / maxf(_perf_total_msec, 0.001),
			_perf_worst_msec, _perf_slow_frames, _perf_peak_enemies, _perf_peak_draws, _perf_peak_nodes])
	_perf_room = label
	_perf_frames = 0
	_perf_total_msec = 0.0
	_perf_worst_msec = 0.0
	_perf_slow_frames = 0
	_perf_peak_enemies = 0
	_perf_peak_draws = 0
	_perf_peak_nodes = 0


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
	_panel_delay = maxf(0.0, _panel_delay - delta)

	if _handle_onboarding(gm):
		return
	if _handle_summary(main, gm):
		return
	_summary_handled = false

	if get_tree().paused:
		return

	if not grant_upgrades.is_empty() and not _granted and gm.run_manager.is_active:
		_granted = true
		_grant(gm)

	_handle_panels(main, gm)
	_handle_transition(gm)
	_in_duel = gm.get("_pvp_active") == true
	_drive_combat(delta, player)
	_track_progress(delta, gm)

	if god_mode and not player.is_dead:
		player.health = player.max_health

	if room_limit > 0 and gm.run_manager.data and gm.run_manager.is_active \
			and gm.run_manager.data.rooms_cleared >= room_limit:
		_log("room limit reached, ending run")
		gm.run_manager.fail_run()
		if Game.is_online():
			gm._rpc_fail_run.rpc()


func _bind(player: CharacterBody3D) -> void:
	if player == _bound_player:
		return
	_bound_player = player
	_input = BotInput.new()
	player.input = _input
	player.damaged.connect(_on_player_damaged.bind(player))
	player.died.connect(_on_player_died.bind(player))
	_log("bound to player %s" % player.name)


## keeps the last few hits, so a death can say what caused it.
func _on_player_damaged(amount: int, info: DamageInfo, player: CharacterBody3D) -> void:
	var from: String = "?"
	if info and is_instance_valid(info.source):
		from = String(info.source.get("type_id")) if info.source.get("type_id") != null else String(info.source.name)
	_recent_hits.append("%d %s from %s at %.1fs (left %d/%d)" % [
		amount, info.kind if info else &"?", from, _sim_time, player.health, player.max_health])
	if _recent_hits.size() > 4:
		_recent_hits.pop_front()


func _on_player_died(player: CharacterBody3D) -> void:
	print("[bot] died at %.1fs pos=%s max_health=%d, last hits: %s" % [
		_sim_time, player.global_position.snappedf(0.1), player.max_health, " | ".join(_recent_hits)])


func _handle_onboarding(gm: Node) -> bool:
	var overlay: Variant = gm.get("_onboarding")
	if overlay == null or not is_instance_valid(overlay) or not overlay.get("_active"):
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
	var entry: Dictionary = {"run": _runs_done + 1, "status": "unknown"}
	if data:
		entry.status = "completed" if data.status == RunData.RunStatus.COMPLETED else "failed"
		entry.rooms_cleared = data.rooms_cleared
		entry.rooms_total = data.total_rooms()
		entry.kills = data.total_enemies_killed
		entry.time = data.elapsed_time
		entry.upgrades = data.chosen_upgrades.size()
		entry.mutations = data.chosen_mutations.size()
		entry.bosses = data.bosses_defeated
		entry.essence = data.essence_earned
		entry.damage_taken = data.damage_taken
		print("[bot] run %d %s: mode=%s rooms %d/%d kills %d bosses %d upgrades %d mutations %d essence %d dmg_taken %d time %.1fs" % [
			entry.run, entry.status, data.mode, entry.rooms_cleared, entry.rooms_total, entry.kills, entry.bosses,
			entry.upgrades, entry.mutations, entry.essence, entry.damage_taken, entry.time])
	results.append(entry)
	_runs_done += 1

	if _runs_done >= max_runs:
		_finish(true, "%d run(s) finished" % _runs_done)
		return true

	# restart through the summary's own button so that path is exercised too
	_stall_time = 0.0
	_last_room_index = -1
	_granted = false
	var btn: Variant = summary.get("restart_button")
	if btn is BaseButton:
		(btn as BaseButton).pressed.emit()
	else:
		summary.emit_signal("restart_requested")
	return true


func _grant(gm: Node) -> void:
	var count: int = 0
	for u: Dictionary in UpgradeDefinitions.CATALOG:
		if grant_upgrades.has("all") or grant_upgrades.has(String(u.id)):
			for i: int in UpgradeDefinitions.max_stacks(u):
				gm.upgrade_manager.apply(u)
				gm.run_manager.apply_upgrade(u)
			count += 1
	print("[bot] granted %d upgrades" % count)


func _handle_panels(main: Node, gm: Node) -> void:
	if _panel_delay > 0.0:
		return
	if gm.get("awaiting_upgrade"):
		var ui: Control = main.get_node_or_null("UI/UpgradeSelection") as Control
		if ui and ui.get("_active") and ui.choices.size() > 0:
			if int(ui.get("_rerolls")) > 0 and randf() < 0.25:
				_log("upgrade: reroll")
				_panel_delay = 0.2
				ui._on_reroll()
				return
			var pick: Dictionary = ui.choices[randi() % ui.choices.size()]
			_log("upgrade: %s" % pick.get("name", "?"))
			_panel_delay = 0.2
			ui._on_choice(pick)
			return
	if gm.get("awaiting_mutation"):
		var mui: Control = main.get_node_or_null("UI/MutationSelection") as Control
		if mui and mui.get("_active") and not mui.get("_chosen"):
			_panel_delay = 0.2
			if mui.choices.size() > 0 and randf() < 0.7:
				var m: Dictionary = mui.choices[randi() % mui.choices.size()]
				_log("mutation: %s" % m.get("name", "?"))
				mui._on_choice(m)
			else:
				_log("mutation: skipped")
				mui._on_skip()
			return
	if gm.get("awaiting_shop"):
		var shop: Control = main.get_node_or_null("UI/Shop") as Control
		if shop and shop.get("_active"):
			_panel_delay = 0.2
			# buy whatever is affordable, then leave
			var items: Array = shop.get("_items")
			var essence: int = gm.run_manager.data.essence
			for i: int in items.size():
				if not items[i].get("sold", false) and int(items[i].get("cost", 0)) <= essence and items[i].get("kind", "") != "reroll":
					_log("shop: buy %s for %d" % [items[i].get("name", "?"), items[i].get("cost", 0)])
					shop.buy_requested.emit(i)
					return
			_log("shop: leave")
			shop._close()
			return
	if gm.get("awaiting_path"):
		var path: Control = main.get_node_or_null("UI/PathChoice") as Control
		if path and path.get("_active") and path.options.size() > 0:
			var idx: int = randi() % path.options.size()
			_log("path: %s" % (path.options[idx] as RunData.RoomData).title())
			_panel_delay = 0.2
			path._choose(idx)


func _handle_transition(gm: Node) -> void:
	if not gm.get("awaiting_transition") or _continue_cooldown > 0.0:
		return
	_continue_cooldown = 0.5
	for pressed: bool in [true, false]:
		var ev: InputEventAction = InputEventAction.new()
		ev.action = "jump"
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _drive_combat(delta: float, player: CharacterBody3D) -> void:
	var enemy: Node3D = _nearest_enemy(player)
	_input.shoot = enemy != null and not player.is_dead

	_noise_timer -= delta
	if _noise_timer <= 0.0:
		_noise_timer = 0.35
		var spread: float = (1.0 - skill) * 0.14
		_aim_noise = Vector2(randf_range(-spread, spread), randf_range(-spread, spread) * 0.6)
	if enemy:
		_aim_at(player, _aim_point(enemy), delta)

	# keep moving: circle-strafe, flip direction now and then
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(2.0, 5.0)
		_strafe_dir = -_strafe_dir
		if randf() < (1.0 - skill) * 0.45:
			_pause_left = randf_range(0.5, 1.2)
	var forward: float = 0.0
	if enemy:
		var dist: float = player.global_position.distance_to(enemy.global_position)
		forward = -0.7 if dist > 16.0 else (0.8 if dist < 8.0 else 0.0)
	_input.move = Vector2(_strafe_dir, forward).normalized()
	if _pause_left > 0.0:
		_pause_left -= delta
		_input.move = Vector2.ZERO

	_dash_timer -= delta
	if _dash_timer <= 0.0:
		_dash_timer = randf_range(1.2, 3.5) * lerpf(3.0, 1.0, skill)
		_input.queue_dash()
	_jump_timer -= delta
	if _jump_timer <= 0.0:
		_jump_timer = randf_range(0.8, 3.0)
		_input.queue_jump()

	# slide now and then; pressing it in the air exercises the ground slam
	_slide_timer -= delta
	if _slide_left > 0.0:
		_slide_left -= delta
		if _slide_left <= 0.0:
			_input.slide = false
	elif _slide_timer <= 0.0:
		_slide_timer = randf_range(3.0, 7.0)
		_slide_left = randf_range(0.4, 1.0)
		_input.slide = true
		_input.queue_slide_press()

	_weapon_timer -= delta
	if _weapon_timer <= 0.0:
		_weapon_timer = randf_range(5.0, 9.0)
		if randf() < 0.3:
			_input.queue_cycle(1)
		else:
			_weapon_slot = (_weapon_slot + 1) % 3
			_input.queue_weapon(_weapon_slot)


func _nearest_enemy(player: CharacterBody3D) -> Node3D:
	var best: Node3D = null
	var best_d: float = INF
	if _in_duel:
		# player against player: the target is whoever else is standing
		for other: Node in get_tree().get_nodes_in_group("player"):
			if other == player or not other is Node3D or other.get("is_dead") == true:
				continue
			var gap: float = (other as Node3D).global_position.distance_squared_to(player.global_position)
			if gap < best_d:
				best_d = gap
				best = other as Node3D
		return best
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not e is Node3D or not is_instance_valid(e) or e.get("is_dying") == true:
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
	if enemy.has_method("aim_point"):
		return enemy.aim_point()
	return enemy.global_position + Vector3(0, 0.8, 0)


func _aim_at(player: CharacterBody3D, point: Vector3, delta: float) -> void:
	var head: Node3D = player.get_node_or_null("Head") as Node3D
	if not head:
		return
	var dir: Vector3 = point - head.global_position
	if dir.length() < 0.05:
		return
	dir = dir.normalized()
	var want_yaw: float = atan2(-dir.x, -dir.z) + _aim_noise.x
	var want_pitch: float = clampf(asin(clampf(dir.y, -1.0, 1.0)) + _aim_noise.y, -PI / 2.0 + 0.05, PI / 2.0 - 0.05)
	if skill >= 0.999:
		player.rotation.y = want_yaw
		head.rotation.x = want_pitch
		return
	# a person tracks a target, they don't snap to it
	var rate: float = clampf(lerpf(5.0, 26.0, skill) * delta, 0.0, 1.0)
	player.rotation.y = lerp_angle(player.rotation.y, want_yaw, rate)
	head.rotation.x = lerpf(head.rotation.x, want_pitch, rate)


func _track_progress(delta: float, gm: Node) -> void:
	var data: Variant = gm.run_manager.data
	if not data:
		return
	var alive: int = get_tree().get_nodes_in_group("enemies").size()
	var key: String = "%d|%d|%d|%s|%d" % [data.current_room_index, data.total_enemies_killed, alive, data.status, data.rooms_cleared]
	if _in_duel:
		var duel: Node = gm.get("pvp_manager")
		for other: Node in get_tree().get_nodes_in_group("player"):
			key += "|%d" % duel.get_pvp_health(other.get_multiplayer_authority())
	if data.current_room_index != _last_room_index:
		_last_room_index = data.current_room_index
		var room: Variant = data.current_room()
		if room:
			_perf_next_room("room %d %s" % [data.current_room_index + 1, room.title()])
			print("[bot] room %d/%d %s act=%d biome=%s layout=%s diff=%.2f budget=%.1f reward=%s t=%.1fs" % [
				data.current_room_index + 1, data.total_rooms(), room.title(), room.act + 1, room.biome,
				gm.room_controller.builder.template if gm.room_controller.builder else "?",
				room.difficulty, room.enemy_budget, room.reward, _sim_time])
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
	print("[bot] awaiting upgrade=%s mutation=%s transition=%s path=%s shop=%s paused=%s time_scale=%.2f" % [
		gm.get("awaiting_upgrade"), gm.get("awaiting_mutation"), gm.get("awaiting_transition"),
		gm.get("awaiting_path"), gm.get("awaiting_shop"), get_tree().paused, Engine.time_scale])
	var rc: Node = gm.get("room_controller")
	if rc:
		print("[bot] room_active=%s enemies_alive=%s waves=%s/%s" % [
			rc.get("room_active"), rc.get("enemies_alive"), rc.get("_wave_index"), (rc.get("_waves") as Array).size()])
	if is_instance_valid(_bound_player):
		print("[bot] player pos=%s hp=%s dead=%s sliding=%s on_floor=%s velocity=%s" % [
			_bound_player.global_position, _bound_player.get("health"), _bound_player.get("is_dead"),
			_bound_player.get("is_sliding"), (_bound_player as CharacterBody3D).is_on_floor(), (_bound_player as CharacterBody3D).velocity.snappedf(0.1)])
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if e is Node3D:
			var hc: Node = e.get_node_or_null("HealthComponent")
			print("[bot]   enemy %s (%s) pos=%s hp=%s dying=%s counts=%s invulnerable=%s unseen=%s velocity=%s" % [
				e.name, e.get("type_id"), (e as Node3D).global_position,
				hc.get("current_health") if hc else "?", e.get("is_dying"), e.get("counts_for_room"),
				hc.get("invulnerable") if hc else "?", e.get("unseen_time"), e.get("velocity")])


func _finish(passed: bool, reason: String) -> void:
	if _done:
		return
	_done = true
	_perf_next_room("")
	print("[bot] %s: %s (sim %.1fs)" % ["PASS" if passed else "FAIL", reason, _sim_time])
	finished.emit(passed, reason)


func _log(msg: String) -> void:
	if verbose:
		print("[bot] ", msg)
