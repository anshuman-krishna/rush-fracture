extends Node

# central coordinator. connects run, room, combat, fracture, combo,
# mutation, difficulty, and ui systems.

@onready var player: CharacterBody3D = $"../Player"
@onready var weapon_manager: WeaponManager = $"../Player/Head/WeaponManager"
@onready var damage_vignette = $"../UI/DamageVignette"
@onready var crosshair = $"../UI/Crosshair"
@onready var run_manager: RunManager = $"../RunManager"
@onready var room_controller: RoomController = $"../RoomController"
@onready var upgrade_manager: UpgradeManager = $"../UpgradeManager"
@onready var fracture_manager: FractureManager = $"../FractureManager"
@onready var combo_tracker: ComboTracker = $"../ComboTracker"
@onready var mutation_manager: MutationManager = $"../MutationManager"
@onready var difficulty_tracker: DifficultyTracker = $"../DifficultyTracker"
@onready var run_hud = $"../UI/RunHUD"
@onready var room_announce = $"../UI/RoomAnnounce"
@onready var upgrade_ui = $"../UI/UpgradeSelection"
@onready var mutation_ui = $"../UI/MutationSelection"
@onready var summary_ui = $"../UI/RunSummary"

var awaiting_upgrade := false
var awaiting_mutation := false
var awaiting_transition := false
var _pending_mutation_after_upgrade := false


func _ready() -> void:
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

	_start_run()


func _unhandled_input(event: InputEvent) -> void:
	if awaiting_transition and event.is_action_pressed("jump"):
		awaiting_transition = false
		run_manager.advance_to_next_room()


func _start_run() -> void:
	_reset_player()
	upgrade_manager.reset()
	mutation_manager.reset()
	weapon_manager.reset_multipliers()
	fracture_manager.end_fracture()
	combo_tracker.reset()
	difficulty_tracker.reset()
	run_manager.start_run()


func _reset_player() -> void:
	player.health = player.max_health
	player.global_position = Vector3(0, 2, 0)
	player.velocity = Vector3.ZERO


func _on_player_damaged(amount: int) -> void:
	# apply cursed damage multiplier
	var effective := int(amount * upgrade_manager.damage_taken_multiplier)
	if effective > amount:
		var extra := effective - amount
		player.health = maxi(player.health - extra, 0)

	difficulty_tracker.on_player_damaged(effective)

	if damage_vignette:
		damage_vignette.flash()
	if player.health <= 0:
		run_manager.fail_run()


func _on_weapon_kill() -> void:
	run_manager.register_kill()
	upgrade_manager.on_enemy_killed()
	mutation_manager.on_enemy_killed()
	combo_tracker.register_kill()
	difficulty_tracker.on_enemy_killed()

	if upgrade_manager.has_chain_reaction:
		_spawn_kill_explosion()


func _on_weapon_hit(hit_position: Vector3) -> void:
	upgrade_manager.on_enemy_hit(hit_position)
	mutation_manager.on_enemy_hit(hit_position)


func _on_weapon_switched(_weapon_name: String) -> void:
	run_hud.update_weapon_display(weapon_manager.get_weapon_name())


func _on_room_enemy_killed() -> void:
	if fracture_manager.is_active and fracture_manager.active_fracture == FractureDefinitions.FractureType.ENEMY_DUPLICATION:
		if randf() < 0.3:
			room_controller.spawn_duplicate_enemy()


func _on_all_enemies_dead() -> void:
	run_manager.on_room_enemies_cleared()


func _on_room_entered(room: RunData.RoomData) -> void:
	var data := run_manager.data
	room_announce.show_room_enter(room, data.current_room_index + 1, data.total_rooms())
	_reset_player_position()

	# apply dynamic difficulty subtly
	var diff_mod := difficulty_tracker.get_difficulty_modifier()
	room.difficulty *= diff_mod

	# apply enemy speed bonus from cursed upgrades
	if upgrade_manager.enemy_speed_bonus > 0:
		room.metadata["enemy_speed_bonus"] = upgrade_manager.enemy_speed_bonus

	room_controller.enter_room(room)
	fracture_manager.try_trigger(room.difficulty)
	difficulty_tracker.on_room_entered()


func _on_room_cleared(room: RunData.RoomData) -> void:
	room_announce.show_room_clear()
	fracture_manager.end_fracture()
	difficulty_tracker.on_room_cleared()

	if room.reward_flag:
		_show_upgrade_selection()
	elif _should_offer_mutation():
		_show_mutation_selection()
	elif run_manager.data.is_final_room():
		run_manager.complete_run()
	else:
		_prompt_next_room()


func _show_upgrade_selection() -> void:
	awaiting_upgrade = true
	var choices := UpgradeDefinitions.pick_choices(3)
	upgrade_ui.show_choices(choices)


func _on_upgrade_selected(upgrade: Dictionary) -> void:
	awaiting_upgrade = false
	upgrade_manager.apply(upgrade)
	run_manager.apply_upgrade(upgrade)

	# check if mutation should follow upgrade
	if _should_offer_mutation():
		_show_mutation_selection()
		return

	if run_manager.data.is_final_room():
		run_manager.complete_run()
	else:
		_prompt_next_room()


func _should_offer_mutation() -> bool:
	var data := run_manager.data
	# offer mutation at rooms 3 and 6 (0-indexed: 2 and 5)
	var room_idx := data.current_room_index
	if room_idx == 2 or room_idx == 5:
		# only offer once per room index
		if data.chosen_mutations.size() < (1 if room_idx == 2 else 2):
			return true
	return false


func _show_mutation_selection() -> void:
	awaiting_mutation = true
	var exclude := []
	for m in run_manager.data.chosen_mutations:
		exclude.append(m.type)
	var choices := MutationDefinitions.pick_choices(2, exclude)
	mutation_ui.show_choices(choices)


func _on_mutation_selected(mutation: Dictionary) -> void:
	awaiting_mutation = false
	mutation_manager.apply(mutation)
	run_manager.data.chosen_mutations.append(mutation)

	if run_manager.data.is_final_room():
		run_manager.complete_run()
	else:
		_prompt_next_room()


func _on_mutation_skipped() -> void:
	awaiting_mutation = false
	if run_manager.data.is_final_room():
		run_manager.complete_run()
	else:
		_prompt_next_room()


func _prompt_next_room() -> void:
	awaiting_transition = true


func _on_run_failed(data: RunData) -> void:
	fracture_manager.end_fracture()
	combo_tracker.reset()
	data.run_tags = RunTags.generate(data, combo_tracker.best_combo)
	summary_ui.show_summary(data)


func _on_run_completed(data: RunData) -> void:
	fracture_manager.end_fracture()
	combo_tracker.reset()
	data.run_tags = RunTags.generate(data, combo_tracker.best_combo)
	summary_ui.show_summary(data)


func _on_restart() -> void:
	_start_run()


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


func _reset_player_position() -> void:
	player.global_position = Vector3(0, 2, 0)
	player.velocity = Vector3.ZERO


func _on_node_added(node: Node) -> void:
	if node.has_node("HealthComponent"):
		node.ready.connect(func(): _connect_enemy_hit(node), CONNECT_ONE_SHOT)


func _connect_enemy_hit(enemy: Node) -> void:
	var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
	if health:
		health.damaged.connect(func(_a, _b): crosshair.show_hit())


func _spawn_kill_explosion() -> void:
	var explosion_radius := 4.0
	var explosion_damage := int(weapon_manager.damage * 0.6)
	var enemies := get_tree().get_nodes_in_group("enemies")
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	var screen_center := get_viewport().get_visible_rect().size / 2
	var from := camera.project_ray_origin(screen_center)
	var forward := camera.project_ray_normal(screen_center)
	var aim_point := from + forward * 20.0

	for enemy in enemies:
		if not enemy is Node3D:
			continue
		var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
		if not health or not health.is_alive():
			continue
		if enemy.global_position.distance_to(aim_point) < explosion_radius:
			health.take_damage(explosion_damage)
