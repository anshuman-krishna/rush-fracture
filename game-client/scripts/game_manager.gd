extends Node

# central coordinator. connects run, room, combat, fracture, combo,
# mutation, difficulty, and ui systems.
# in multiplayer: host drives room progression, clients follow via rpc.

@onready var player_manager: PlayerManager = $"../PlayerManager"
@onready var player_spawner: PlayerSpawner = $"../PlayerSpawner"
@onready var damage_vignette: ColorRect = $"../UI/DamageVignette"
@onready var crosshair: CenterContainer = $"../UI/Crosshair"
@onready var run_manager: RunManager = $"../RunManager"
@onready var room_controller: RoomController = $"../RoomController"
@onready var upgrade_manager: UpgradeManager = $"../UpgradeManager"
@onready var fracture_manager: FractureManager = $"../FractureManager"
@onready var combo_tracker: ComboTracker = $"../ComboTracker"
@onready var mutation_manager: MutationManager = $"../MutationManager"
@onready var difficulty_tracker: DifficultyTracker = $"../DifficultyTracker"
@onready var audio: AudioManager = $"../AudioManager"
@onready var game_feel: GameFeel = $"../GameFeel"
@onready var run_hud: Control = $"../UI/RunHUD"
@onready var room_announce: Control = $"../UI/RoomAnnounce"
@onready var upgrade_ui: Control = $"../UI/UpgradeSelection"
@onready var mutation_ui: Control = $"../UI/MutationSelection"
@onready var summary_ui: Control = $"../UI/RunSummary"

# resolved from player_manager each run
var player: CharacterBody3D
var weapon_manager: WeaponManager
var camera: Camera3D
var network_manager: NetworkManager

var awaiting_upgrade: bool = false
var awaiting_mutation: bool = false
var awaiting_transition: bool = false
var _pending_mutation_after_upgrade: bool = false
var _boss_active: bool = false
var _boss_defeated: bool = false
var _run_seed: int = 0


func _ready() -> void:
	_detect_network()
	_setup_multiplayer_spawning()
	_resolve_player_refs()

	player.player_damaged.connect(_on_player_damaged)
	weapon_manager.enemy_killed.connect(_on_weapon_kill)
	weapon_manager.enemy_hit.connect(_on_weapon_hit)
	weapon_manager.weapon_switched.connect(_on_weapon_switched)

	run_manager.room_entered.connect(_on_room_entered)
	run_manager.room_cleared.connect(_on_room_cleared)
	run_manager.run_failed.connect(_on_run_failed)
	run_manager.run_completed.connect(_on_run_completed)

	room_controller.all_enemies_dead.connect(_on_all_enemies_dead)
	room_controller.enemy_killed.connect(_on_room_enemy_killed)
	room_controller.boss_defeated.connect(_on_boss_defeated)

	fracture_manager.fracture_started.connect(_on_fracture_started)
	fracture_manager.fracture_ended.connect(_on_fracture_ended)

	combo_tracker.combo_changed.connect(_on_combo_changed)
	combo_tracker.combo_reset.connect(_on_combo_reset)

	upgrade_ui.upgrade_selected.connect(_on_upgrade_selected)
	mutation_ui.mutation_selected.connect(_on_mutation_selected)
	mutation_ui.mutation_skipped.connect(_on_mutation_skipped)
	summary_ui.restart_requested.connect(_on_restart)

	get_tree().node_added.connect(_on_node_added)

	upgrade_manager.bind(player, weapon_manager)
	mutation_manager.bind(player, weapon_manager)
	fracture_manager.bind(player)
	combo_tracker.bind(player)
	run_hud.bind_run_manager(run_manager)

	if is_host_or_solo():
		_start_run()
	elif _is_online():
		# client requests run seed from host after scene loads
		_rpc_request_run_seed.rpc_id(1)


func _detect_network() -> void:
	network_manager = get_node_or_null("/root/NetworkManager") as NetworkManager
	if network_manager:
		network_manager.server_disconnected.connect(_on_server_disconnected)
		network_manager.player_disconnected.connect(_on_peer_disconnected)


func _setup_multiplayer_spawning() -> void:
	if not network_manager or not network_manager.is_online():
		return

	# setup player spawner for multiplayer
	var main_node: Node = get_parent()
	player_spawner.setup(main_node, player_manager, network_manager)

	# spawn players for all connected peers (except local — already in scene)
	for peer_id: int in network_manager.connected_peers:
		if peer_id != network_manager.local_peer_id:
			player_spawner._spawn_player_for_peer(peer_id)

	# set authority on the scene-tree player
	var scene_player: CharacterBody3D = player_manager.get_primary_player()
	if scene_player:
		scene_player.set_multiplayer_authority(network_manager.local_peer_id)
		player_spawner._add_synchronizer(scene_player, network_manager.local_peer_id)
		player_spawner._spawned_players[network_manager.local_peer_id] = scene_player


func is_host_or_solo() -> bool:
	if not network_manager or not network_manager.is_online():
		return true
	return network_manager.is_host()


func _is_online() -> bool:
	return network_manager and network_manager.is_online()


func _resolve_player_refs() -> void:
	player = player_manager.get_primary_player()
	weapon_manager = player_manager.get_primary_weapon_manager()
	camera = player_manager.get_primary_camera()


func _unhandled_input(event: InputEvent) -> void:
	if awaiting_transition and event.is_action_pressed("jump"):
		awaiting_transition = false
		if is_host_or_solo():
			_advance_room()
		else:
			_rpc_request_advance_room.rpc_id(1)


# --- run lifecycle ---

func _start_run() -> void:
	_run_seed = randi()
	_do_start_run(_run_seed)

	if _is_online():
		_rpc_start_run.rpc(_run_seed)


func _do_start_run(seed_value: int) -> void:
	_reset_player()
	upgrade_manager.reset()
	mutation_manager.reset()
	weapon_manager.reset_multipliers()
	fracture_manager.end_fracture()
	combo_tracker.reset()
	difficulty_tracker.reset()
	_boss_active = false
	_boss_defeated = false
	_pending_mutation_after_upgrade = false
	game_feel.reset()
	audio.play("run_start", -3.0)
	run_manager.start_run(seed_value)


@rpc("authority", "call_remote", "reliable")
func _rpc_start_run(seed_value: int) -> void:
	_do_start_run(seed_value)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_run_seed() -> void:
	# client asks host for current run seed after loading
	if is_host_or_solo() and _run_seed != 0:
		var sender_id: int = multiplayer.get_remote_sender_id()
		_rpc_start_run.rpc_id(sender_id, _run_seed)


func _advance_room() -> void:
	run_manager.advance_to_next_room()
	if _is_online():
		_rpc_advance_room.rpc()


@rpc("authority", "call_remote", "reliable")
func _rpc_advance_room() -> void:
	run_manager.advance_to_next_room()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_advance_room() -> void:
	# client requests host to advance — host validates and advances
	if is_host_or_solo():
		_advance_room()


# --- player ---

func _reset_player() -> void:
	player.health = player.max_health
	player.global_position = Vector3(0, 2, 0)
	player.velocity = Vector3.ZERO


func _on_death() -> void:
	if damage_vignette:
		damage_vignette.flash(3.0)
	game_feel.camera_punch(camera, 12.0)
	audio.play("player_damage", 0.0, 0.05)
	# brief death slow-mo
	Engine.time_scale = 0.3
	var tween: Tween = create_tween().set_ignore_time_scale(true)
	tween.tween_interval(0.4)
	tween.tween_callback(func(): Engine.time_scale = 1.0)


func _on_player_damaged(amount: int) -> void:
	# apply cursed damage multiplier
	var effective: int = int(amount * upgrade_manager.damage_taken_multiplier)
	if effective > amount:
		var extra: int = effective - amount
		player.health = maxi(player.health - extra, 0)

	difficulty_tracker.on_player_damaged(effective)
	audio.play("player_damage", -2.0, 0.1)

	var intensity: float = clamp(float(effective) / 30.0, 0.5, 2.0)
	if damage_vignette:
		damage_vignette.flash(intensity)
	game_feel.camera_punch(camera, effective * 0.3)
	if player.health <= 0:
		_on_death()
		if is_host_or_solo():
			run_manager.fail_run()
			if _is_online():
				_rpc_fail_run.rpc()


@rpc("authority", "call_remote", "reliable")
func _rpc_fail_run() -> void:
	run_manager.fail_run()


# --- combat ---

func _on_weapon_kill() -> void:
	run_manager.register_kill()
	upgrade_manager.on_enemy_killed()
	mutation_manager.on_enemy_killed()
	combo_tracker.register_kill()
	difficulty_tracker.on_enemy_killed()

	audio.play("enemy_death", -4.0, 0.15)
	game_feel.kill_freeze()
	crosshair.show_kill()

	if upgrade_manager.has_chain_reaction:
		_spawn_kill_explosion()


func _on_weapon_hit(hit_position: Vector3) -> void:
	upgrade_manager.on_enemy_hit(hit_position)
	mutation_manager.on_enemy_hit(hit_position)
	audio.play("enemy_hit", -8.0, 0.2)


func _on_weapon_switched(_weapon_name: String) -> void:
	run_hud.update_weapon_display(weapon_manager.get_weapon_name())


func _on_room_enemy_killed() -> void:
	if fracture_manager.is_active and fracture_manager.active_fracture == FractureDefinitions.FractureType.ENEMY_DUPLICATION:
		if randf() < 0.3:
			room_controller.spawn_duplicate_enemy()


func _on_boss_phase_changed(_phase: int) -> void:
	audio.play("boss_phase", 0.0)
	game_feel.boss_phase_slowmo()
	game_feel.camera_punch(camera, 8.0)


func _on_boss_defeated() -> void:
	_boss_defeated = true
	_boss_active = false
	room_announce.show_boss_defeated()
	audio.play("boss_death", 0.0)
	game_feel.boss_death_slowmo()


# --- room progression (host-driven) ---

func _on_all_enemies_dead() -> void:
	if is_host_or_solo():
		run_manager.on_room_enemies_cleared()
		if _is_online():
			_rpc_room_cleared.rpc()


@rpc("authority", "call_remote", "reliable")
func _rpc_room_cleared() -> void:
	run_manager.on_room_enemies_cleared()


func _on_room_entered(room: RunData.RoomData) -> void:
	var data: RunData = run_manager.data
	_reset_player_position()

	# apply dynamic difficulty subtly
	var diff_mod: float = difficulty_tracker.get_difficulty_modifier()
	room.difficulty *= diff_mod

	# apply enemy speed bonus from cursed upgrades
	if upgrade_manager.enemy_speed_bonus > 0:
		room.metadata["enemy_speed_bonus"] = upgrade_manager.enemy_speed_bonus

	if room.type == RoomDefinitions.RoomType.BOSS:
		_boss_active = true
		_boss_defeated = false
		audio.play("boss_warning", 0.0)
		room_announce.show_boss_warning()
		await get_tree().create_timer(2.0).timeout
		room_announce.show_room_enter(room, data.current_room_index + 1, data.total_rooms())
	else:
		room_announce.show_room_enter(room, data.current_room_index + 1, data.total_rooms())

	room_controller.enter_room(room)

	# connect boss phase signal after spawn delay
	if room.type == RoomDefinitions.RoomType.BOSS:
		await get_tree().create_timer(0.5).timeout
		if room_controller.active_boss:
			room_controller.active_boss.phase_changed.connect(_on_boss_phase_changed)

	# no fracture events during boss fight
	if room.type != RoomDefinitions.RoomType.BOSS:
		fracture_manager.try_trigger(room.difficulty)
	difficulty_tracker.on_room_entered()


func _on_room_cleared(room: RunData.RoomData) -> void:
	room_announce.show_room_clear()
	fracture_manager.end_fracture()
	difficulty_tracker.on_room_cleared()
	audio.play("room_clear", -3.0)

	# clients wait for host-driven room transitions
	if not is_host_or_solo():
		_prompt_next_room()
		return

	if room.type == RoomDefinitions.RoomType.BOSS:
		# boss reward: upgrade + mutation, then complete
		_pending_mutation_after_upgrade = true
		_show_upgrade_selection()
		return

	if room.reward_flag:
		_show_upgrade_selection()
	elif _should_offer_mutation():
		_show_mutation_selection()
	elif run_manager.data.is_final_room():
		_complete_run()
	else:
		_prompt_next_room()


func _complete_run() -> void:
	run_manager.complete_run()
	if _is_online():
		_rpc_complete_run.rpc()


@rpc("authority", "call_remote", "reliable")
func _rpc_complete_run() -> void:
	run_manager.complete_run()


# --- upgrades and mutations (host-driven) ---

func _show_upgrade_selection() -> void:
	awaiting_upgrade = true
	var choices: Array[Dictionary] = UpgradeDefinitions.pick_choices(3)
	upgrade_ui.show_choices(choices)


func _on_upgrade_selected(upgrade: Dictionary) -> void:
	awaiting_upgrade = false
	upgrade_manager.apply(upgrade)
	run_manager.apply_upgrade(upgrade)
	audio.play("upgrade_pick", -3.0)

	# boss reward guarantees a mutation choice
	if _pending_mutation_after_upgrade:
		_pending_mutation_after_upgrade = false
		_show_mutation_selection()
		return

	# check if mutation should follow upgrade
	if _should_offer_mutation():
		_show_mutation_selection()
		return

	if run_manager.data.is_final_room():
		_complete_run()
	else:
		_prompt_next_room()


func _should_offer_mutation() -> bool:
	var data: RunData = run_manager.data
	# offer mutation at rooms 3 and 6 (0-indexed: 2 and 5)
	var room_idx: int = data.current_room_index
	if room_idx == 2 or room_idx == 5:
		# only offer once per room index
		if data.chosen_mutations.size() < (1 if room_idx == 2 else 2):
			return true
	return false


func _show_mutation_selection() -> void:
	awaiting_mutation = true
	var exclude: Array = []
	for m in run_manager.data.chosen_mutations:
		exclude.append(m.type)
	var choices: Array[Dictionary] = MutationDefinitions.pick_choices(2, exclude)
	mutation_ui.show_choices(choices)


func _on_mutation_selected(mutation: Dictionary) -> void:
	awaiting_mutation = false
	mutation_manager.apply(mutation)
	run_manager.data.chosen_mutations.append(mutation)
	audio.play("upgrade_pick", -3.0)

	if _boss_defeated:
		_complete_run()
	elif run_manager.data.is_final_room():
		_complete_run()
	else:
		_prompt_next_room()


func _on_mutation_skipped() -> void:
	awaiting_mutation = false
	if _boss_defeated:
		_complete_run()
	elif run_manager.data.is_final_room():
		_complete_run()
	else:
		_prompt_next_room()


func _prompt_next_room() -> void:
	awaiting_transition = true


# --- run end ---

func _on_run_failed(data: RunData) -> void:
	fracture_manager.end_fracture()
	var best: int = combo_tracker.best_combo
	combo_tracker.reset()
	data.run_tags = RunTags.generate(data, best)
	BestStats.update_from_run(data, best)
	summary_ui.show_summary(data)


func _on_run_completed(data: RunData) -> void:
	fracture_manager.end_fracture()
	var best: int = combo_tracker.best_combo
	combo_tracker.reset()
	data.run_tags = RunTags.generate(data, best)
	BestStats.update_from_run(data, best)
	summary_ui.show_summary(data)


func _on_restart() -> void:
	awaiting_upgrade = false
	awaiting_mutation = false
	awaiting_transition = false
	upgrade_ui.visible = false
	mutation_ui.visible = false
	room_controller.clear_current_room()
	_resolve_player_refs()
	if is_host_or_solo():
		_start_run()


# --- fracture / combo ---

func _on_fracture_started(type: FractureDefinitions.FractureType) -> void:
	room_announce.show_fracture(FractureDefinitions.get_name(type))


func _on_fracture_ended(_type: FractureDefinitions.FractureType) -> void:
	pass


func _on_combo_changed(multiplier: int, kill_count: int) -> void:
	upgrade_manager.on_combo_changed(multiplier)
	run_hud.update_combo(multiplier, kill_count)


func _on_combo_reset() -> void:
	upgrade_manager.on_combo_reset()
	run_hud.update_combo(1, 0)


# --- network events ---

func _on_server_disconnected() -> void:
	# host dropped — clean up and return to menu
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_peer_disconnected(peer_id: int) -> void:
	# remote player left — spawner handles despawn, just log
	pass


# --- utilities ---

func _reset_player_position() -> void:
	player.global_position = Vector3(0, 2, 0)
	player.velocity = Vector3.ZERO


func _on_node_added(node: Node) -> void:
	if node.has_node("HealthComponent"):
		node.ready.connect(func(): _connect_enemy_hit(node), CONNECT_ONE_SHOT)


func _connect_enemy_hit(enemy: Node) -> void:
	var health: HealthComponent = enemy.get_node_or_null("HealthComponent") as HealthComponent
	if health:
		health.damaged.connect(func(_a, _b): crosshair.show_hit())


func _spawn_kill_explosion() -> void:
	var explosion_radius: float = 4.0
	var explosion_damage: int = int(weapon_manager.damage * 0.6)
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var aim_camera: Camera3D = get_viewport().get_camera_3d()
	if not aim_camera:
		return

	var screen_center: Vector2 = get_viewport().get_visible_rect().size / 2
	var from: Vector3 = aim_camera.project_ray_origin(screen_center)
	var forward: Vector3 = aim_camera.project_ray_normal(screen_center)
	var aim_point: Vector3 = from + forward * 20.0

	for enemy in enemies:
		if not enemy is Node3D:
			continue
		var health: HealthComponent = enemy.get_node_or_null("HealthComponent") as HealthComponent
		if not health or not health.is_alive():
			continue
		if enemy.global_position.distance_to(aim_point) < explosion_radius:
			health.take_damage(explosion_damage)
