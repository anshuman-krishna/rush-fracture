class_name BossWardenController
extends BossBase

# fracture warden — mid-run boss encounter.
# phase 1: defensive posture, shield pulses, summons minions.
# phase 2 (40% hp): aggressive, rapid teleport slams, arena hazards.

@export var move_speed: float = 2.5
@export var detection_range: float = 35.0
@export var attack_damage: int = 15
@export var pulse_damage: int = 12
@export var pulse_radius: float = 8.0
@export var slam_damage: int = 25
@export var slam_radius: float = 5.0

var _add_timer: float = 5.0
var _hazard_timer: float = 0.0


func _ready() -> void:
	super._ready()
	attack_cooldown_base = 3.5


func _get_detection_range() -> float:
	return detection_range


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


func _phase_two_cooldown_mult() -> float:
	return 0.55


func _do_pulse() -> void:
	# expanding damage ring
	for p in _get_players():
		if p is Node3D and global_position.distance_to(p.global_position) <= pulse_radius:
			if p.has_method("take_damage"):
				var dmg: int = pulse_damage
				if current_phase == Phase.TWO:
					dmg = int(dmg * 1.3)
				p.take_damage(dmg)
	_spawn_expanding_ring_visual(pulse_radius, Color(0.0, 0.8, 0.8, 0.5), Color(0.0, 0.7, 0.7), 0.4, 2.0, 0.12)


func _do_slam() -> void:
	for p in _get_players():
		if p is Node3D and global_position.distance_to(p.global_position) <= slam_radius:
			if p.has_method("take_damage"):
				p.take_damage(slam_damage)
	_spawn_flat_ring_visual(slam_radius, Color(1.0, 0.3, 0.0, 0.5), Color(1.0, 0.4, 0.0), 2.0)


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


func _phase_tick(delta: float) -> void:
	# phase 1: summon minions
	if current_phase == Phase.ONE:
		_handle_add_spawning(delta)

	# phase 2: spawn arena hazards
	if current_phase == Phase.TWO:
		_handle_arena_hazards(delta)


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
	tween.chain().tween_callback(func():
		if is_instance_valid(indicator):
			indicator.queue_free()
	)


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
