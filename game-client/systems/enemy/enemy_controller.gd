extends EnemyBase

@export var move_speed: float = 5.0
@export var detection_range: float = 60.0
@export var attack_range: float = 2.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.5

var attack_timer: float = 0.0


func _physics_process(delta: float) -> void:
	if _check_fall_death():
		return

	if is_dying:
		return

	# only host runs enemy ai in multiplayer
	if not _is_local_authority():
		return

	_apply_gravity(delta)
	_update_attack_timer(delta)

	if not target or not is_instance_valid(target):
		target = null
		_find_target()
		move_and_slide()
		return

	var distance: float = global_position.distance_to(target.global_position)

	if distance > detection_range:
		move_and_slide()
		return

	if distance > attack_range:
		_chase(delta)
	else:
		_try_attack()

	_clamp_to_arena()
	move_and_slide()


func _chase(delta: float) -> void:
	var desired: Vector3 = (target.global_position - global_position).normalized()
	var direction: Vector3 = _steer_around_obstacles(desired)

	velocity.x = move_toward(velocity.x, direction.x * move_speed, 20.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed, 20.0 * delta)

	# face movement direction
	if direction.length() > 0.1:
		var look_target: Vector3 = global_position + direction
		look_target.y = global_position.y
		look_at(look_target)


func _try_attack() -> void:
	velocity.x = move_toward(velocity.x, 0, 10.0)
	velocity.z = move_toward(velocity.z, 0, 10.0)

	if attack_timer <= 0 and target:
		if target.has_method("take_damage"):
			target.take_damage(attack_damage)
		attack_timer = attack_cooldown


func _update_attack_timer(delta: float) -> void:
	attack_timer = max(0, attack_timer - delta)


func _build_visual() -> void:
	# chaser: lean body with clawed arms — melee indicator
	var arm_l: MeshInstance3D = _make_box(Vector3(0.12, 0.5, 0.12), Vector3(-0.35, 0.6, 0), Color(0.7, 0.1, 0.05))
	var arm_r: MeshInstance3D = _make_box(Vector3(0.12, 0.5, 0.12), Vector3(0.35, 0.6, 0), Color(0.7, 0.1, 0.05))
	add_child(arm_l)
	add_child(arm_r)
	# claws
	var claw_l: MeshInstance3D = _make_box(Vector3(0.08, 0.2, 0.06), Vector3(-0.35, 0.3, -0.08), Color(1.0, 0.3, 0.1), Color(1.0, 0.2, 0.0))
	var claw_r: MeshInstance3D = _make_box(Vector3(0.08, 0.2, 0.06), Vector3(0.35, 0.3, -0.08), Color(1.0, 0.3, 0.1), Color(1.0, 0.2, 0.0))
	add_child(claw_l)
	add_child(claw_r)
	# eye visor
	var visor: MeshInstance3D = _make_box(Vector3(0.3, 0.06, 0.08), Vector3(0, 1.2, -0.25), Color(1.0, 0.15, 0.0), Color(1.0, 0.1, 0.0))
	add_child(visor)
