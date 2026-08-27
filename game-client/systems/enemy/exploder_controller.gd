extends EnemyBase

@export var move_speed: float = 6.0
@export var detection_range: float = 60.0
@export var explode_range: float = 3.0
@export var explosion_damage: int = 30
@export var explosion_radius: float = 5.0
@export var attack_damage: int = 5

var has_exploded: bool = false


func _physics_process(delta: float) -> void:
	if _check_fall_death():
		return

	if is_dying:
		return

	if not _is_local_authority():
		return

	_apply_gravity(delta)

	if not target:
		_find_target()
		move_and_slide()
		return

	var distance: float = global_position.distance_to(target.global_position)
	if distance > detection_range:
		move_and_slide()
		return

	if distance < explode_range:
		_explode()
		return

	_chase(delta)
	_face_target()

	# pulsing glow as it approaches
	_update_urgency(distance)
	_clamp_to_arena()
	move_and_slide()


func _chase(delta: float) -> void:
	var direction: Vector3 = (target.global_position - global_position).normalized()
	direction.y = 0
	velocity.x = move_toward(velocity.x, direction.x * move_speed, 25.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed, 25.0 * delta)


func _explode() -> void:
	if has_exploded:
		return
	has_exploded = true
	is_dying = true

	if target and global_position.distance_to(target.global_position) < explosion_radius:
		if target.has_method("take_damage"):
			target.take_damage(explosion_damage)

	_play_explosion()


func _update_urgency(distance: float) -> void:
	if not mesh:
		return
	var mat: Material = mesh.get_surface_override_material(0)
	if mat is StandardMaterial3D:
		var urgency: float = clamp(1.0 - (distance / detection_range), 0.0, 1.0)
		mat.emission_energy_multiplier = 0.5 + urgency * 3.0


func _face_target() -> void:
	if not target:
		return
	var look_pos: Vector3 = target.global_position
	look_pos.y = global_position.y
	if global_position.distance_to(look_pos) > 0.1:
		look_at(look_pos)


func _on_died() -> void:
	if not has_exploded:
		_explode()
	else:
		is_dying = true
		_play_death()


func _build_visual() -> void:
	# danger spikes radiating outward — warning indicator
	var spike_color: Color = Color(1.0, 0.5, 0.0)
	var spike_emit: Color = Color(1.0, 0.3, 0.0)
	for i in 6:
		var angle: float = (float(i) / 6.0) * TAU
		var dir: Vector3 = Vector3(cos(angle), 0, sin(angle))
		var spike: MeshInstance3D = _make_box(
			Vector3(0.06, 0.06, 0.25),
			Vector3(dir.x * 0.5, 0.5, dir.z * 0.5),
			spike_color, spike_emit
		)
		spike.rotation.y = -angle
		add_child(spike)
	# fuse on top — glowing
	var fuse: MeshInstance3D = _make_box(Vector3(0.06, 0.2, 0.06), Vector3(0, 1.1, 0), Color(1.0, 0.8, 0.2), Color(1.0, 0.6, 0.0))
	add_child(fuse)
	# warning ring at base
	var ring: MeshInstance3D = _make_box(Vector3(0.8, 0.04, 0.8), Vector3(0, 0.05, 0), Color(1.0, 0.2, 0.0), Color(1.0, 0.15, 0.0))
	add_child(ring)


func _play_explosion() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3(2.5, 2.5, 2.5), 0.12)
	tween.tween_property(mesh, "transparency", 1.0, 0.15)
	tween.chain().tween_callback(queue_free)
