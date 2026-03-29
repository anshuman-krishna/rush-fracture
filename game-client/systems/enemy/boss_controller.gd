class_name BossController
extends CharacterBody3D

# fracture titan — the run's final challenge.
# phase 1: slow, deliberate area attacks.
# phase 2: faster, aggressive, spawns adds.

signal phase_changed(phase: int)
signal boss_defeated

enum Phase { ONE, TWO }
enum AttackState { IDLE, TELEGRAPH, ATTACKING, COOLDOWN }

@export var move_speed: float = 3.0
@export var detection_range: float = 40.0
@export var attack_damage: int = 20
@export var slam_damage: int = 30
@export var slam_radius: float = 6.0
@export var shockwave_damage: int = 15
@export var shockwave_radius: float = 10.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var target: CharacterBody3D
var current_phase: Phase = Phase.ONE
var _player_manager: PlayerManager
var attack_state: AttackState = AttackState.IDLE
var attack_timer: float = 0.0
var attack_cooldown: float = 3.0
var phase_two_triggered: bool = false
var is_dying: bool = false
var _telegraph_timer: float = 0.0
var _attack_duration: float = 0.0
var _pending_attack: String = ""
var _adds_spawned: int = 0
var _add_timer: float = 0.0

@onready var health: HealthComponent = $HealthComponent
@onready var mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	add_to_group("enemies")
	add_to_group("boss")
	_player_manager = get_node_or_null("/root/Main/PlayerManager") as PlayerManager


func _physics_process(delta: float) -> void:
	if is_dying:
		return

	if not _is_local_authority():
		return

	_apply_gravity(delta)
	_check_phase_transition()

	if not target:
		_find_target()
		move_and_slide()
		return

	var distance: float = global_position.distance_to(target.global_position)
	if distance > detection_range:
		move_and_slide()
		return

	match attack_state:
		AttackState.IDLE:
			_handle_idle(delta, distance)
		AttackState.TELEGRAPH:
			_handle_telegraph(delta)
		AttackState.ATTACKING:
			_handle_attacking(delta)
		AttackState.COOLDOWN:
			_handle_cooldown(delta)

	_face_target()
	move_and_slide()

	# phase 2: periodically spawn adds
	if current_phase == Phase.TWO:
		_handle_add_spawning(delta)


func _handle_idle(delta: float, distance: float) -> void:
	if distance > slam_radius:
		_chase(delta)
	else:
		velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 10.0 * delta)

	attack_timer -= delta
	if attack_timer <= 0:
		_choose_attack(distance)


func _choose_attack(distance: float) -> void:
	if distance <= slam_radius:
		_begin_telegraph("slam", 0.6)
	elif distance <= shockwave_radius:
		if current_phase == Phase.TWO and randf() < 0.4:
			_begin_telegraph("charge", 0.4)
		else:
			_begin_telegraph("shockwave", 0.8)
	else:
		_begin_telegraph("shockwave", 0.8)


func _begin_telegraph(attack_name: String, duration: float) -> void:
	attack_state = AttackState.TELEGRAPH
	_pending_attack = attack_name
	_telegraph_timer = duration
	velocity.x = 0
	velocity.z = 0
	_show_telegraph(attack_name)


func _handle_telegraph(delta: float) -> void:
	_telegraph_timer -= delta
	if _telegraph_timer <= 0:
		_execute_attack()


func _execute_attack() -> void:
	attack_state = AttackState.ATTACKING
	_attack_duration = 0.3

	var audio: AudioManager = _get_audio()
	match _pending_attack:
		"slam":
			_do_slam()
			if audio: audio.play("boss_slam", 0.0)
		"shockwave":
			_do_shockwave()
			if audio: audio.play("boss_shockwave", -2.0)
		"charge":
			_do_charge()


func _handle_attacking(delta: float) -> void:
	_attack_duration -= delta
	if _attack_duration <= 0:
		attack_state = AttackState.COOLDOWN
		var cd: float = attack_cooldown
		if current_phase == Phase.TWO:
			cd *= 0.65
		attack_timer = cd
		attack_state = AttackState.IDLE
		_clear_telegraph()


func _handle_cooldown(delta: float) -> void:
	attack_timer -= delta
	if attack_timer <= 0:
		attack_state = AttackState.IDLE


func _do_slam() -> void:
	# ground slam — damages everything in radius
	if not target:
		return
	var players: Array[Node]
	if _player_manager:
		players = _player_manager.get_all_players()
	else:
		players = get_tree().get_nodes_in_group("player")
	for p in players:
		if p is Node3D and global_position.distance_to(p.global_position) <= slam_radius:
			if p.has_method("take_damage"):
				p.take_damage(slam_damage if current_phase == Phase.ONE else int(slam_damage * 1.4))
	_spawn_slam_visual()


func _do_shockwave() -> void:
	# expanding ring — damages at distance
	if not target:
		return
	var players: Array[Node]
	if _player_manager:
		players = _player_manager.get_all_players()
	else:
		players = get_tree().get_nodes_in_group("player")
	for p in players:
		if p is Node3D:
			var dist: float = global_position.distance_to(p.global_position)
			if dist <= shockwave_radius and dist > 2.0:
				if p.has_method("take_damage"):
					p.take_damage(shockwave_damage)
	_spawn_shockwave_visual()


func _do_charge() -> void:
	# phase 2 only — quick lunge toward player
	if not target:
		return
	var dir: Vector3 = (target.global_position - global_position).normalized()
	dir.y = 0
	velocity = dir * move_speed * 8.0
	_attack_duration = 0.35

	# damage on arrival
	await get_tree().create_timer(0.3).timeout
	if not is_dying and target:
		var dist: float = global_position.distance_to(target.global_position)
		if dist <= 3.5 and target.has_method("take_damage"):
			target.take_damage(attack_damage)


func _chase(delta: float) -> void:
	var direction: Vector3 = (target.global_position - global_position).normalized()
	direction.y = 0
	var speed: float = move_speed
	if current_phase == Phase.TWO:
		speed *= 1.5
	velocity.x = move_toward(velocity.x, direction.x * speed, 8.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 8.0 * delta)


func _check_phase_transition() -> void:
	if phase_two_triggered:
		return
	if not health:
		return
	var ratio: float = float(health.current_health) / float(health.max_health)
	if ratio <= 0.5:
		phase_two_triggered = true
		current_phase = Phase.TWO
		attack_cooldown *= 0.65
		phase_changed.emit(2)
		_flash_phase_transition()


func _handle_add_spawning(delta: float) -> void:
	if _adds_spawned >= 6:
		return
	_add_timer -= delta
	if _add_timer <= 0:
		_add_timer = 8.0
		_spawn_add()


func _spawn_add() -> void:
	# spawn a chaser near the boss
	var scene_path: String = EnemyTypes.scene_path(EnemyTypes.Type.CHASER)
	if not ResourceLoader.exists(scene_path):
		return
	var scene: PackedScene = load(scene_path) as PackedScene
	if not scene:
		return
	var instance: CharacterBody3D = scene.instantiate() as CharacterBody3D
	var angle: float = randf() * TAU
	var offset: Vector3 = Vector3(cos(angle) * 4.0, 1.0, sin(angle) * 4.0)
	instance.global_position = global_position + offset

	# scale adds to current difficulty
	var h: HealthComponent = instance.get_node_or_null("HealthComponent") as HealthComponent
	if h:
		h.max_health = int(h.max_health * 0.6)
		h.current_health = h.max_health

	get_parent().add_child(instance)
	_adds_spawned += 1


# --- visuals ---

func _show_telegraph(attack_name: String) -> void:
	if not mesh:
		return
	var mat: Material = mesh.get_surface_override_material(0)
	if mat is StandardMaterial3D:
		match attack_name:
			"slam":
				mat.emission = Color(1.0, 0.3, 0.0)
				mat.emission_energy_multiplier = 3.0
			"shockwave":
				mat.emission = Color(0.8, 0.0, 0.8)
				mat.emission_energy_multiplier = 2.5
			"charge":
				mat.emission = Color(1.0, 0.0, 0.0)
				mat.emission_energy_multiplier = 4.0


func _clear_telegraph() -> void:
	if not mesh:
		return
	var mat: Material = mesh.get_surface_override_material(0)
	if mat is StandardMaterial3D:
		mat.emission = Color(0.6, 0.05, 0.0)
		mat.emission_energy_multiplier = 1.0


func _spawn_slam_visual() -> void:
	var indicator: MeshInstance3D = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = slam_radius
	disc.bottom_radius = slam_radius
	disc.height = 0.1
	indicator.mesh = disc

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.0, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.0)
	mat.emission_energy_multiplier = 2.0
	indicator.material_override = mat

	indicator.global_position = Vector3(global_position.x, 0.1, global_position.z)
	get_tree().root.add_child(indicator)

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.tween_callback(indicator.queue_free)


func _spawn_shockwave_visual() -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: CylinderMesh = CylinderMesh.new()
	torus.top_radius = 1.0
	torus.bottom_radius = 1.0
	torus.height = 0.15
	ring.mesh = torus

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.0, 0.8, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.1, 0.8)
	mat.emission_energy_multiplier = 2.0
	ring.material_override = mat

	ring.global_position = Vector3(global_position.x, 0.1, global_position.z)
	get_tree().root.add_child(ring)

	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(shockwave_radius, 1, shockwave_radius), 0.5)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tween.chain().tween_callback(ring.queue_free)


func _flash_phase_transition() -> void:
	if not mesh:
		return
	var mat: Material = mesh.get_surface_override_material(0)
	if not mat is StandardMaterial3D:
		return

	# bright flash then settle to phase 2 colors
	var tween: Tween = create_tween()
	tween.tween_property(mat, "emission_energy_multiplier", 6.0, 0.1)
	tween.tween_property(mat, "emission_energy_multiplier", 1.5, 0.3)
	tween.tween_property(mat, "emission", Color(0.8, 0.0, 0.0), 0.2)

	# scale up slightly for phase 2
	var size_tween: Tween = create_tween()
	size_tween.tween_property(self, "scale", Vector3(1.15, 1.15, 1.15), 0.3)


func _face_target() -> void:
	if not target:
		return
	var look_pos: Vector3 = target.global_position
	look_pos.y = global_position.y
	if global_position.distance_to(look_pos) > 0.1:
		look_at(look_pos)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta


func _find_target() -> void:
	if _player_manager:
		target = _player_manager.get_nearest_player(global_position)
	else:
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0] as CharacterBody3D


func _on_damaged(_amount: int, _current: int) -> void:
	_flash_hit()


func _on_died() -> void:
	is_dying = true
	boss_defeated.emit()
	_play_death()


func _flash_hit() -> void:
	if not mesh:
		return
	var mat: Material = mesh.get_surface_override_material(0)
	if mat is StandardMaterial3D:
		var prev_emission: Color = mat.emission
		mat.emission = Color.WHITE
		var tween: Tween = create_tween()
		tween.tween_property(mat, "emission", prev_emission, 0.12)


func _play_death() -> void:
	# dramatic boss death — slow collapse
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale:y", 0.1, 0.8).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(mesh, "transparency", 1.0, 1.0)
	tween.tween_callback(queue_free)


# --- public api ---

func get_phase() -> int:
	return current_phase + 1


func _get_audio() -> AudioManager:
	return get_node_or_null("/root/Main/AudioManager") as AudioManager


func get_health_ratio() -> float:
	if not health:
		return 0.0
	return float(health.current_health) / float(health.max_health)


func _is_local_authority() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return is_multiplayer_authority()
