extends EnemyBase

@export var move_speed: float = 4.0
@export var detection_range: float = 60.0
@export var preferred_range: float = 12.0
@export var attack_damage: int = 8
@export var attack_cooldown: float = 2.0
@export var projectile_speed: float = 30.0

const TRACER_DURATION: float = 0.15

var attack_timer: float = 0.0
var is_elite: bool = false
var _muzzle_offset: Vector3 = Vector3(0.35, 0.8, -0.74)


func _physics_process(delta: float) -> void:
	if _check_fall_death():
		return

	if is_dying:
		return

	if not _is_local_authority():
		return

	_apply_gravity(delta)
	attack_timer = max(0, attack_timer - delta)

	if not target or not is_instance_valid(target):
		target = null
		_find_target()
		move_and_slide()
		return

	var distance: float = global_position.distance_to(target.global_position)
	if distance > detection_range:
		move_and_slide()
		return

	_maintain_distance(delta, distance)
	_face_target()

	if distance < detection_range and attack_timer <= 0:
		_fire_at_target()

	_clamp_to_arena()
	move_and_slide()


func _maintain_distance(delta: float, distance: float) -> void:
	var direction: Vector3 = (target.global_position - global_position).normalized()
	direction.y = 0

	if distance < preferred_range * 0.7:
		# too close — back away
		velocity.x = move_toward(velocity.x, -direction.x * move_speed, 15.0 * delta)
		velocity.z = move_toward(velocity.z, -direction.z * move_speed, 15.0 * delta)
	elif distance > preferred_range * 1.3:
		# too far — approach
		velocity.x = move_toward(velocity.x, direction.x * move_speed, 15.0 * delta)
		velocity.z = move_toward(velocity.z, direction.z * move_speed, 15.0 * delta)
	else:
		# strafe
		var strafe: Vector3 = direction.cross(Vector3.UP)
		velocity.x = move_toward(velocity.x, strafe.x * move_speed * 0.6, 10.0 * delta)
		velocity.z = move_toward(velocity.z, strafe.z * move_speed * 0.6, 10.0 * delta)


func _fire_at_target() -> void:
	attack_timer = attack_cooldown
	if not target or not is_instance_valid(target):
		return

	var muzzle_pos: Vector3 = global_transform * _muzzle_offset
	var target_pos: Vector3 = target.global_position + Vector3(0, 0.8, 0)

	# raycast for line of sight — check if we can see the player
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(muzzle_pos, target_pos)
	query.collision_mask = 3  # layers 1 (terrain) + 2 (entities)
	query.exclude = [get_rid()]
	var result: Dictionary = space_state.intersect_ray(query)

	var hit_pos: Vector3 = target_pos
	var hit_player: bool = false

	if result.is_empty():
		# no hit means clear path (target has no collision on this mask? apply damage)
		hit_player = true
	elif result.collider == target:
		hit_player = true
		hit_pos = result.position
	elif result.collider is StaticBody3D:
		# hit a wall — check if it's a breakable wall
		hit_pos = result.position
		var wall: StaticBody3D = result.collider as StaticBody3D
		if wall.has_meta("breakable"):
			var rc: Node = get_node_or_null("/root/Main/RoomController")
			if rc and rc.has_method("damage_breakable_wall"):
				rc.damage_breakable_wall(wall)
		# blocked by terrain — reduced damage through walls
		if target.has_method("take_damage"):
			target.take_damage(maxi(int(attack_damage * 0.2), 1))
	else:
		hit_pos = result.get("position", target_pos)

	if hit_player and target.has_method("take_damage"):
		target.take_damage(attack_damage)

	# spawn tracer visual
	_spawn_tracer(muzzle_pos, hit_pos)

	if is_elite:
		_elite_burst_fire()


func _elite_burst_fire() -> void:
	for i in 2:
		await get_tree().create_timer(0.15).timeout
		if not is_instance_valid(self) or not is_inside_tree():
			return
		if is_dying or not target or not is_instance_valid(target):
			return
		var muzzle_pos: Vector3 = global_transform * _muzzle_offset
		var target_pos: Vector3 = target.global_position + Vector3(0, 0.8, 0)
		var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(muzzle_pos, target_pos)
		query.collision_mask = 3
		query.exclude = [get_rid()]
		var result: Dictionary = space_state.intersect_ray(query)

		var burst_dmg: int = int(attack_damage * 0.6)
		var end_pos: Vector3 = target_pos

		if result.is_empty() or result.collider == target:
			if target.has_method("take_damage"):
				target.take_damage(burst_dmg)
			if not result.is_empty():
				end_pos = result.position
		else:
			end_pos = result.get("position", target_pos)
			if result.collider is StaticBody3D and result.collider.has_meta("breakable"):
				var rc: Node = get_node_or_null("/root/Main/RoomController")
				if rc and rc.has_method("damage_breakable_wall"):
					rc.damage_breakable_wall(result.collider)
			if target.has_method("take_damage"):
				target.take_damage(maxi(int(burst_dmg * 0.2), 1))

		_spawn_tracer(muzzle_pos, end_pos)


func _spawn_tracer(from_pos: Vector3, to_pos: Vector3) -> void:
	TracerPool.spawn(self, from_pos, to_pos, Color(0.4, 0.2, 1.0), TRACER_DURATION, 0.02)


func _face_target() -> void:
	if not target:
		return
	var look_pos: Vector3 = target.global_position
	look_pos.y = global_position.y
	if global_position.distance_to(look_pos) > 0.1:
		look_at(look_pos)


func _build_visual() -> void:
	# gun arm — barrel extends forward from right side
	var gun_body: MeshInstance3D = _make_box(Vector3(0.12, 0.12, 0.4), Vector3(0.35, 0.8, -0.3), Color(0.15, 0.1, 0.5))
	add_child(gun_body)
	var gun_barrel: MeshInstance3D = _make_box(Vector3(0.06, 0.06, 0.25), Vector3(0.35, 0.8, -0.6), Color(0.1, 0.08, 0.4), Color(0.2, 0.1, 0.8))
	add_child(gun_barrel)
	# muzzle tip glow
	var muzzle: MeshInstance3D = _make_box(Vector3(0.08, 0.08, 0.04), Vector3(0.35, 0.8, -0.74), Color(0.3, 0.2, 1.0), Color(0.4, 0.2, 1.0))
	add_child(muzzle)
	# left arm stub
	var arm_l: MeshInstance3D = _make_box(Vector3(0.1, 0.35, 0.1), Vector3(-0.35, 0.7, 0), Color(0.18, 0.12, 0.55))
	add_child(arm_l)
	# antenna/sensor on head
	var antenna: MeshInstance3D = _make_box(Vector3(0.04, 0.2, 0.04), Vector3(0.15, 1.6, 0), Color(0.3, 0.2, 0.9), Color(0.2, 0.1, 0.7))
	add_child(antenna)
	# visor
	var visor: MeshInstance3D = _make_box(Vector3(0.35, 0.06, 0.08), Vector3(0, 1.2, -0.25), Color(0.4, 0.3, 1.0), Color(0.3, 0.15, 0.8))
	add_child(visor)
