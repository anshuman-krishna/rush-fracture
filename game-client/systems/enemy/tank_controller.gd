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
	var direction: Vector3 = (target.global_position - global_position).normalized()
	direction.y = 0
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
	# heavy shoulder armor
	var shoulder_l: MeshInstance3D = _make_box(Vector3(0.4, 0.25, 0.35), Vector3(-0.6, 1.4, 0), Color(0.35, 0.32, 0.38))
	var shoulder_r: MeshInstance3D = _make_box(Vector3(0.4, 0.25, 0.35), Vector3(0.6, 1.4, 0), Color(0.35, 0.32, 0.38))
	add_child(shoulder_l)
	add_child(shoulder_r)
	# massive fists — melee indicator
	var fist_l: MeshInstance3D = _make_box(Vector3(0.25, 0.25, 0.25), Vector3(-0.6, 0.6, -0.15), Color(0.4, 0.15, 0.1), Color(0.5, 0.1, 0.0))
	var fist_r: MeshInstance3D = _make_box(Vector3(0.25, 0.25, 0.25), Vector3(0.6, 0.6, -0.15), Color(0.4, 0.15, 0.1), Color(0.5, 0.1, 0.0))
	add_child(fist_l)
	add_child(fist_r)
	# chest plate
	var chest: MeshInstance3D = _make_box(Vector3(0.7, 0.4, 0.15), Vector3(0, 1.1, -0.45), Color(0.25, 0.25, 0.3))
	add_child(chest)
	# visor — narrow angry slit
	var visor: MeshInstance3D = _make_box(Vector3(0.5, 0.06, 0.1), Vector3(0, 1.5, -0.45), Color(0.8, 0.15, 0.1), Color(0.7, 0.1, 0.0))
	add_child(visor)


func _play_death() -> void:
	# heavier unit — bigger, slower death animation than the base default
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3(1.5, 0.1, 1.5), 0.2)
	tween.tween_property(mesh, "transparency", 1.0, 0.25)
	tween.chain().tween_callback(queue_free)
