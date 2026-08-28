extends EnemyBase

@export var move_speed: float = 2.5
@export var detection_range: float = 60.0
@export var attack_range: float = 2.5
@export var attack_damage: int = 25
@export var attack_cooldown: float = 2.5

var attack_timer: float = 0.0
var is_elite: bool = false
var slam_cooldown: float = 0.0


func _physics_process(delta: float) -> void:
	if _check_fall_death():
		return

	if is_dying:
		return

	if not _is_local_authority():
		return

	_apply_gravity(delta)
	attack_timer = max(0, attack_timer - delta)
	slam_cooldown = max(0, slam_cooldown - delta)

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
		# elite slam when close enough
		if is_elite and distance <= 5.0 and slam_cooldown <= 0:
			_elite_ground_slam()
	else:
		_try_attack()

	_face_target()
	_clamp_to_arena()
	move_and_slide()


func _chase(delta: float) -> void:
	var desired: Vector3 = (target.global_position - global_position).normalized()
	var direction: Vector3 = _steer_around_obstacles(desired)
	velocity.x = move_toward(velocity.x, direction.x * move_speed, 12.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed, 12.0 * delta)


func _try_attack() -> void:
	velocity.x = move_toward(velocity.x, 0, 8.0)
	velocity.z = move_toward(velocity.z, 0, 8.0)

	if attack_timer <= 0 and target:
		if target.has_method("take_damage"):
			target.take_damage(attack_damage)
		attack_timer = attack_cooldown


func _elite_ground_slam() -> void:
	slam_cooldown = 6.0
	var slam_radius: float = 5.0
	var slam_damage: int = int(attack_damage * 0.8)
	var players: Array = []
	if _player_manager:
		players = _player_manager.get_all_players()
	else:
		players = get_tree().get_nodes_in_group("player")
	for p in players:
		if p is Node3D and global_position.distance_to(p.global_position) <= slam_radius:
			if p.has_method("take_damage"):
				p.take_damage(slam_damage)
	_spawn_slam_ring(slam_radius)


func _spawn_slam_ring(radius: float) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 0.5
	disc.bottom_radius = 0.5
	disc.height = 0.1
	ring.mesh = disc
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.1, 0.0, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.15, 0.0)
	ring.material_override = mat
	ring.global_position = Vector3(global_position.x, 0.1, global_position.z)
	get_tree().root.add_child(ring)
	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(radius, 1, radius), 0.3)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.chain().tween_callback(func():
		if is_instance_valid(ring):
			ring.queue_free()
	)


func _face_target() -> void:
	if not target:
		return
	var look_pos: Vector3 = target.global_position
	look_pos.y = global_position.y
	if global_position.distance_to(look_pos) > 0.1:
		look_at(look_pos)


func _build_visual() -> void:
	# "Brood Hulk" — grafted brood art lane, see testing/design-ideas.md.
	# the abdomen (brood_core / abdomen_seam_N) is the model's own HP readout;
	# nothing here needs to drive it manually.
	_load_visual_model("res://assets/models/grafted-brood-tank.glb")


func _play_death() -> void:
	# heavier unit — bigger, slower death animation than the base default
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3(1.5, 0.1, 1.5), 0.2)
	for mi: MeshInstance3D in _all_meshes():
		tween.tween_property(mi, "transparency", 1.0, 0.25)
	tween.chain().tween_callback(queue_free)
