class_name BossWardenController
extends CharacterBody3D

# fracture warden — mid-run boss encounter.
# phase 1: defensive posture, shield pulses, summons minions.
# phase 2 (40% hp): aggressive, rapid teleport slams, arena hazards.

signal phase_changed(phase: int)
signal boss_defeated

enum Phase { ONE, TWO }
enum AttackState { IDLE, TELEGRAPH, ATTACKING, COOLDOWN }

@export var move_speed: float = 2.5
@export var detection_range: float = 35.0
@export var attack_damage: int = 15
@export var pulse_damage: int = 12
@export var pulse_radius: float = 8.0
@export var slam_damage: int = 25
@export var slam_radius: float = 5.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var target: CharacterBody3D
var current_phase: Phase = Phase.ONE
var _player_manager: PlayerManager
var attack_state: AttackState = AttackState.IDLE
var attack_timer: float = 0.0
var attack_cooldown: float = 3.5
var phase_two_triggered: bool = false
var is_dying: bool = false
var _telegraph_timer: float = 0.0
var _attack_duration: float = 0.0
var _pending_attack: String = ""
var _adds_spawned: int = 0
var _add_timer: float = 5.0
var _hazard_timer: float = 0.0

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

	# phase 1: summon minions
	if current_phase == Phase.ONE:
		_handle_add_spawning(delta)

	# phase 2: spawn arena hazards
	if current_phase == Phase.TWO:
		_handle_arena_hazards(delta)


func _handle_idle(delta: float, distance: float) -> void:
	if current_phase == Phase.ONE:
		# defensive — maintain distance
		var direction: Vector3 = (target.global_position - global_position).normalized()
		direction.y = 0
		if distance < pulse_radius * 0.8:
			velocity.x = move_toward(velocity.x, -direction.x * move_speed, 8.0 * delta)
			velocity.z = move_toward(velocity.z, -direction.z * move_speed, 8.0 * delta)
		elif distance > pulse_radius * 1.5:
			velocity.x = move_toward(velocity.x, direction.x * move_speed * 0.6, 6.0 * delta)
			velocity.z = move_toward(velocity.z, direction.z * move_speed * 0.6, 6.0 * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, 5.0 * delta)
			velocity.z = move_toward(velocity.z, 0, 5.0 * delta)
	else:
		# phase 2 — aggressive chase
		_chase(delta)

	attack_timer -= delta
	if attack_timer <= 0:
		_choose_attack(distance)


func _choose_attack(distance: float) -> void:
	if current_phase == Phase.ONE:
		if distance <= pulse_radius:
			_begin_telegraph("pulse", 0.7)
		else:
			_begin_telegraph("pulse", 0.7)
	else:
		# phase 2: mix of teleport slam and pulse
		var roll: float = randf()
		if roll < 0.5:
			_begin_telegraph("teleport_slam", 0.5)
		elif distance <= slam_radius * 1.5:
			_begin_telegraph("slam", 0.4)
		else:
			_begin_telegraph("pulse", 0.5)


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
		"pulse":
			_do_pulse()
			if audio: audio.play("boss_shockwave", -2.0)
		"slam":
			_do_slam()
			if audio: audio.play("boss_slam", 0.0)
		"teleport_slam":
			_do_teleport_slam()
			if audio: audio.play("boss_slam", 0.0)


func _handle_attacking(delta: float) -> void:
	_attack_duration -= delta
	if _attack_duration <= 0:
		var cd: float = attack_cooldown
		if current_phase == Phase.TWO:
			cd *= 0.55
		attack_timer = cd
		attack_state = AttackState.IDLE
		_clear_telegraph()


func _handle_cooldown(delta: float) -> void:
	attack_timer -= delta
	if attack_timer <= 0:
		attack_state = AttackState.IDLE


func _do_pulse() -> void:
	# expanding damage ring
	var players: Array[Node] = _get_players()
	for p in players:
		if p is Node3D and global_position.distance_to(p.global_position) <= pulse_radius:
			if p.has_method("take_damage"):
				var dmg: int = pulse_damage
				if current_phase == Phase.TWO:
					dmg = int(dmg * 1.3)
				p.take_damage(dmg)
	_spawn_pulse_visual()


func _do_slam() -> void:
	var players: Array[Node] = _get_players()
	for p in players:
		if p is Node3D and global_position.distance_to(p.global_position) <= slam_radius:
			if p.has_method("take_damage"):
				p.take_damage(slam_damage)
	_spawn_slam_visual()


func _do_teleport_slam() -> void:
	if not target:
		return

	# teleport near the player
	var dir: Vector3 = (target.global_position - global_position).normalized()
	dir.y = 0
	var tp_pos: Vector3 = target.global_position - dir * 2.5
	tp_pos.y = 1.0

	_spawn_warp_visual(global_position)
	global_position = tp_pos
	_spawn_warp_visual(tp_pos)

	# slam at new position
	_attack_duration = 0.4
	await get_tree().create_timer(0.15).timeout
	if not is_dying:
		_do_slam()


func _chase(delta: float) -> void:
	var direction: Vector3 = (target.global_position - global_position).normalized()
	direction.y = 0
	var speed: float = move_speed * 2.0
	velocity.x = move_toward(velocity.x, direction.x * speed, 10.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 10.0 * delta)


func _check_phase_transition() -> void:
	if phase_two_triggered or not health:
		return
	var ratio: float = float(health.current_health) / float(health.max_health)
	if ratio <= 0.4:
		phase_two_triggered = true
		current_phase = Phase.TWO
		phase_changed.emit(2)
		_flash_phase_transition()


func _handle_add_spawning(delta: float) -> void:
	if _adds_spawned >= 4:
		return
	_add_timer -= delta
	if _add_timer <= 0:
		_add_timer = 6.0
		_spawn_add()


func _spawn_add() -> void:
	# spawn support or chaser near the warden
	var type: EnemyTypes.Type = EnemyTypes.Type.CHASER
	if _adds_spawned % 2 == 1:
		type = EnemyTypes.Type.SUPPORT

	var scene_path: String = EnemyTypes.scene_path(type)
	if not ResourceLoader.exists(scene_path):
		return
	var scene: PackedScene = load(scene_path) as PackedScene
	if not scene:
		return

	var instance: CharacterBody3D = scene.instantiate() as CharacterBody3D
	var angle: float = randf() * TAU
	var offset: Vector3 = Vector3(cos(angle) * 5.0, 1.0, sin(angle) * 5.0)
	instance.global_position = global_position + offset

	var h: HealthComponent = instance.get_node_or_null("HealthComponent") as HealthComponent
	if h:
		h.max_health = int(h.max_health * 0.5)
		h.current_health = h.max_health

	get_parent().add_child(instance)
	_adds_spawned += 1


func _handle_arena_hazards(delta: float) -> void:
	_hazard_timer -= delta
	if _hazard_timer <= 0:
		_hazard_timer = 5.0
		_spawn_arena_hazard()


func _spawn_arena_hazard() -> void:
	# drop a damage zone at player's position
	if not target:
		return

	var zone: Area3D = Area3D.new()
	zone.position = Vector3(target.global_position.x, 0, target.global_position.z)
	zone.collision_layer = 0
	zone.collision_mask = 1

	var size: float = 3.0
	var zone_mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(size, 0.1, size)
	zone_mesh.mesh = box
	zone_mesh.position.y = 0.05

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.2, 0.0, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.0)
	mat.emission_energy_multiplier = 1.5
	zone_mesh.material_override = mat

	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(size, 0.5, size)
	col.shape = shape
	col.position.y = 0.25

	zone.add_child(zone_mesh)
	zone.add_child(col)

	zone.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(10)
	)

	get_tree().root.add_child(zone)

	# remove after 4 seconds
	get_tree().create_timer(4.0).timeout.connect(func():
		if is_instance_valid(zone):
			zone.queue_free()
	)


# --- visuals ---

func _show_telegraph(attack_name: String) -> void:
	if not mesh:
		return
	var mat: Material = mesh.get_surface_override_material(0)
	if mat is StandardMaterial3D:
		match attack_name:
			"pulse":
				mat.emission = Color(0.0, 0.8, 0.8)
				mat.emission_energy_multiplier = 2.5
			"slam":
				mat.emission = Color(1.0, 0.4, 0.0)
				mat.emission_energy_multiplier = 3.0
			"teleport_slam":
				mat.emission = Color(0.8, 0.0, 1.0)
				mat.emission_energy_multiplier = 4.0


func _clear_telegraph() -> void:
	if not mesh:
		return
	var mat: Material = mesh.get_surface_override_material(0)
	if mat is StandardMaterial3D:
		mat.emission = Color(0.0, 0.4, 0.5)
		mat.emission_energy_multiplier = 1.0


func _spawn_pulse_visual() -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.12
	ring.mesh = cyl

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 0.8, 0.8, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.0, 0.7, 0.7)
	mat.emission_energy_multiplier = 2.0
	ring.material_override = mat

	ring.global_position = Vector3(global_position.x, 0.1, global_position.z)
	get_tree().root.add_child(ring)

	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(pulse_radius, 1, pulse_radius), 0.4)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.chain().tween_callback(ring.queue_free)


func _spawn_slam_visual() -> void:
	var indicator: MeshInstance3D = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = slam_radius
	disc.bottom_radius = slam_radius
	disc.height = 0.1
	indicator.mesh = disc

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.3, 0.0, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.0)
	mat.emission_energy_multiplier = 2.0
	indicator.material_override = mat

	indicator.global_position = Vector3(global_position.x, 0.1, global_position.z)
	get_tree().root.add_child(indicator)

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.tween_callback(indicator.queue_free)


func _spawn_warp_visual(pos: Vector3) -> void:
	var indicator: MeshInstance3D = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 2.0
	disc.bottom_radius = 2.0
	disc.height = 0.08
	indicator.mesh = disc

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.0, 0.9, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.0, 1.0)
	mat.emission_energy_multiplier = 3.0
	indicator.material_override = mat

	indicator.global_position = Vector3(pos.x, 0.1, pos.z)
	get_tree().root.add_child(indicator)

	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(indicator, "scale", Vector3(0.1, 1, 0.1), 0.35)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tween.chain().tween_callback(indicator.queue_free)


func _flash_phase_transition() -> void:
	if not mesh:
		return
	var mat: Material = mesh.get_surface_override_material(0)
	if not mat is StandardMaterial3D:
		return

	var tween: Tween = create_tween()
	tween.tween_property(mat, "emission_energy_multiplier", 8.0, 0.1)
	tween.tween_property(mat, "emission_energy_multiplier", 2.0, 0.3)
	tween.tween_property(mat, "emission", Color(0.9, 0.0, 0.2), 0.2)

	var size_tween: Tween = create_tween()
	size_tween.tween_property(self, "scale", Vector3(1.2, 1.2, 1.2), 0.3)


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


func _get_players() -> Array[Node]:
	if _player_manager:
		return _player_manager.get_all_players()
	return get_tree().get_nodes_in_group("player")


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
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale:y", 0.1, 0.8).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(mesh, "transparency", 1.0, 1.0)
	tween.tween_callback(queue_free)


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
