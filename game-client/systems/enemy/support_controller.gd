extends EnemyBase

# support enemy that buffs nearby allies. stays behind other enemies.
# periodically heals or speeds up nearby enemies. priority target.

@export var move_speed: float = 3.5
@export var detection_range: float = 60.0
@export var preferred_range: float = 16.0
@export var attack_damage: int = 5
@export var attack_cooldown: float = 2.5
@export var buff_radius: float = 8.0
@export var buff_cooldown: float = 4.0
@export var heal_amount: int = 15

var attack_timer: float = 0.0
var buff_timer: float = 2.0
var is_elite: bool = false


func _physics_process(delta: float) -> void:
	if _check_fall_death():
		return

	if is_dying:
		return

	if not _is_local_authority():
		return

	_apply_gravity(delta)
	attack_timer = max(0, attack_timer - delta)
	buff_timer -= delta

	if not target:
		_find_target()
		move_and_slide()
		return

	var distance: float = global_position.distance_to(target.global_position)
	if distance > detection_range:
		move_and_slide()
		return

	_maintain_distance(delta, distance)
	_face_target()

	# weak ranged attack
	if distance < detection_range and attack_timer <= 0:
		_fire_at_target()

	# buff allies periodically
	if buff_timer <= 0:
		_buff_allies()
		buff_timer = buff_cooldown
		if is_elite:
			buff_timer *= 0.7

	_clamp_to_arena()
	move_and_slide()


func _maintain_distance(delta: float, distance: float) -> void:
	# stay behind other enemies — keep far from player
	var direction: Vector3 = (target.global_position - global_position).normalized()
	direction.y = 0

	if distance < preferred_range * 0.5:
		# too close — flee
		velocity.x = move_toward(velocity.x, -direction.x * move_speed * 1.3, 15.0 * delta)
		velocity.z = move_toward(velocity.z, -direction.z * move_speed * 1.3, 15.0 * delta)
	elif distance > preferred_range * 1.4:
		# too far — approach to stay in buff range of allies
		velocity.x = move_toward(velocity.x, direction.x * move_speed, 10.0 * delta)
		velocity.z = move_toward(velocity.z, direction.z * move_speed, 10.0 * delta)
	else:
		# orbit at safe distance
		var strafe: Vector3 = direction.cross(Vector3.UP)
		velocity.x = move_toward(velocity.x, strafe.x * move_speed * 0.5, 8.0 * delta)
		velocity.z = move_toward(velocity.z, strafe.z * move_speed * 0.5, 8.0 * delta)


func _fire_at_target() -> void:
	attack_timer = attack_cooldown
	if not target or not is_instance_valid(target):
		return

	# every other ranged enemy (shooter, sniper) raycasts for line of sight
	# before landing a hit — this one didn't, so a support enemy could chip
	# a player through walls/obstacles from anywhere inside its generous
	# 60-unit detection_range, bypassing the cover the game's obstacles
	# exist for. mirrors shooter_controller.gd's check.
	var muzzle_pos: Vector3 = global_position + Vector3(0, 0.7, 0)
	var target_pos: Vector3 = target.global_position + Vector3(0, 0.8, 0)
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(muzzle_pos, target_pos)
	query.collision_mask = 3  # layers 1 (terrain) + 2 (entities)
	query.exclude = [get_rid()]
	var result: Dictionary = space_state.intersect_ray(query)

	if result.is_empty() or result.collider == target:
		if target.has_method("take_damage"):
			target.take_damage(attack_damage)
	elif result.collider is StaticBody3D:
		var wall: StaticBody3D = result.collider as StaticBody3D
		if wall.has_meta("breakable"):
			var rc: Node = get_node_or_null("/root/Main/RoomController")
			if rc and rc.has_method("damage_breakable_wall"):
				rc.damage_breakable_wall(wall)
		if target.has_method("take_damage"):
			target.take_damage(maxi(int(attack_damage * 0.2), 1))


func _buff_allies() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var buffed_count: int = 0

	for enemy in enemies:
		if enemy == self or not enemy is Node3D:
			continue
		if enemy.global_position.distance_to(global_position) > buff_radius:
			continue

		# heal allies
		var h: HealthComponent = enemy.get_node_or_null("HealthComponent") as HealthComponent
		if h and h.is_alive() and h.current_health < h.max_health:
			var amount: int = heal_amount
			if is_elite:
				amount = int(amount * 1.5)
			h.current_health = mini(h.current_health + amount, h.max_health)
			buffed_count += 1

		# speed boost for 3 seconds
		if "move_speed" in enemy and not enemy.get_meta("support_buffed", false):
			var base_speed: float = enemy.move_speed
			enemy.move_speed *= 1.25
			enemy.set_meta("support_buffed", true)
			# revert after duration
			get_tree().create_timer(3.0).timeout.connect(func():
				if is_instance_valid(enemy) and "move_speed" in enemy:
					enemy.move_speed = base_speed
					enemy.set_meta("support_buffed", false)
			)

	if buffed_count > 0:
		_show_buff_visual()


func _show_buff_visual() -> void:
	# pulse ring showing buff area
	var ring: MeshInstance3D = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = buff_radius
	disc.bottom_radius = buff_radius
	disc.height = 0.08
	ring.mesh = disc

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.9, 0.3, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.8, 0.2)
	mat.emission_energy_multiplier = 1.5
	ring.material_override = mat

	ring.global_position = Vector3(global_position.x, 0.1, global_position.z)
	get_tree().root.add_child(ring)

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tween.tween_callback(ring.queue_free)


func _face_target() -> void:
	if not target:
		return
	var look_pos: Vector3 = target.global_position
	look_pos.y = global_position.y
	if global_position.distance_to(look_pos) > 0.1:
		look_at(look_pos)


func _build_visual() -> void:
	# "Choir Spore" — grafted brood art lane, see testing/design-ideas.md.
	_load_visual_model("res://assets/models/grafted-brood-support.glb")
