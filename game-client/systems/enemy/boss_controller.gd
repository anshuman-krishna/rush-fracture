class_name BossController
extends BossBase

# fracture titan — the run's final challenge.
# phase 1: slow, deliberate area attacks.
# phase 2: faster, aggressive, spawns adds.

@export var move_speed: float = 3.0
@export var detection_range: float = 40.0
@export var attack_damage: int = 20
@export var slam_damage: int = 30
@export var slam_radius: float = 6.0
@export var shockwave_damage: int = 15
@export var shockwave_radius: float = 10.0

var _add_timer: float = 0.0
# how long the player has been kept beyond shockwave_radius, where none of
# this boss's attacks can land at all — see _choose_attack's far branch.
var _time_at_range: float = 0.0
const KITE_CHARGE_THRESHOLD: float = 3.0


func _get_detection_range() -> float:
	return detection_range


func _handle_idle(delta: float, distance: float) -> void:
	if distance > slam_radius:
		_chase(delta)
	else:
		velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 10.0 * delta)

	if distance > shockwave_radius:
		_time_at_range += delta
	else:
		_time_at_range = 0.0

	attack_timer -= delta
	if attack_timer <= 0:
		_choose_attack(distance)


func _choose_attack(distance: float) -> void:
	if distance <= slam_radius:
		_begin_telegraph("slam", 0.8)
	elif distance <= shockwave_radius:
		if current_phase == Phase.TWO and randf() < 0.4:
			_begin_telegraph("charge", 0.6)
		else:
			_begin_telegraph("shockwave", 0.8)
	elif _time_at_range >= KITE_CHARGE_THRESHOLD:
		# out of every attack's range and has stayed there — telegraphing
		# "shockwave" here would just whiff (it only damages within
		# shockwave_radius), letting a player who keeps their distance stall
		# forever. close the gap with a charge instead; nothing about
		# _do_charge is actually phase-2-specific, that was only ever true
		# of how it used to get picked.
		_time_at_range = 0.0
		_begin_telegraph("charge", 0.6)
	else:
		# still out of range but hasn't camped there long enough to force a
		# charge — skip this attack cycle and keep chasing rather than
		# freezing in place to telegraph an attack that can't reach.
		attack_timer = 0.5


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


func _phase_two_cooldown_mult() -> float:
	return 0.65


func _do_slam() -> void:
	# ground slam — damages everything in radius
	if not target:
		return
	for p in _get_players():
		if p is Node3D and global_position.distance_to(p.global_position) <= slam_radius:
			if p.has_method("take_damage"):
				p.take_damage(slam_damage if current_phase == Phase.ONE else int(slam_damage * 1.25))
	_spawn_flat_ring_visual(slam_radius, Color(1.0, 0.2, 0.0, 0.5), Color(1.0, 0.3, 0.0), 2.0)


func _do_shockwave() -> void:
	# expanding ring — damages at distance
	if not target:
		return
	for p in _get_players():
		if p is Node3D:
			var dist: float = global_position.distance_to(p.global_position)
			if dist <= shockwave_radius and dist > 2.0:
				if p.has_method("take_damage"):
					p.take_damage(shockwave_damage)
	_spawn_expanding_ring_visual(shockwave_radius, Color(0.8, 0.0, 0.8, 0.6), Color(0.8, 0.1, 0.8), 0.5, 2.0, 0.15)


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
	if not is_instance_valid(self) or not is_inside_tree():
		return
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
		attack_cooldown_base *= 0.65
		phase_changed.emit(2)
		_flash_phase_transition()


func _phase_tick(delta: float) -> void:
	# phase 2: periodically spawn adds
	if current_phase == Phase.TWO:
		_handle_add_spawning(delta)


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

func _build_visual() -> void:
	# "Hive-Colossus" — grafted brood art lane, see testing/design-ideas.md.
	# phase 2 is modelled in: the rib plates and add pods are already visible
	# on the model, this just needs a core mesh for telegraph-color signaling.
	var model: Node3D = _load_visual_model("res://assets/models/grafted-brood-titan.glb")
	mesh = _find_mesh(model, "phase_core")
	_make_material_unique(mesh)


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
