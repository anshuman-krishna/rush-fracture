extends CharacterBody3D

# long-range enemy that holds position and fires high-damage shots.
# telegraphs attacks with a laser sight before firing.

@export var move_speed: float = 2.5
@export var detection_range: float = 60.0
@export var preferred_range: float = 20.0
@export var attack_damage: int = 18
@export var attack_cooldown: float = 3.5
@export var telegraph_duration: float = 1.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var target: CharacterBody3D
var attack_timer: float = 0.0
var is_dying: bool = false
var is_elite: bool = false
var _player_manager: PlayerManager
var _telegraphing: bool = false
var _telegraph_timer: float = 0.0
var _laser_line: MeshInstance3D

@onready var health: HealthComponent = $HealthComponent
@onready var mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	add_to_group("enemies")
	_player_manager = get_node_or_null("/root/Main/PlayerManager") as PlayerManager
	_build_visual()


func _physics_process(delta: float) -> void:
	if is_dying:
		return

	if not _is_local_authority():
		return

	_apply_gravity(delta)
	attack_timer = max(0, attack_timer - delta)

	if not target:
		_find_target()
		move_and_slide()
		return

	var distance: float = global_position.distance_to(target.global_position)
	if distance > detection_range:
		move_and_slide()
		return

	if _telegraphing:
		_handle_telegraph(delta)
		_face_target()
		move_and_slide()
		return

	_maintain_distance(delta, distance)
	_face_target()

	if distance <= detection_range and attack_timer <= 0:
		_start_telegraph()

	move_and_slide()


func _maintain_distance(delta: float, distance: float) -> void:
	var direction: Vector3 = (target.global_position - global_position).normalized()
	direction.y = 0

	if distance < preferred_range * 0.6:
		# too close — retreat
		velocity.x = move_toward(velocity.x, -direction.x * move_speed * 1.5, 12.0 * delta)
		velocity.z = move_toward(velocity.z, -direction.z * move_speed * 1.5, 12.0 * delta)
	elif distance > preferred_range * 1.2:
		# too far — approach slowly
		velocity.x = move_toward(velocity.x, direction.x * move_speed * 0.5, 8.0 * delta)
		velocity.z = move_toward(velocity.z, direction.z * move_speed * 0.5, 8.0 * delta)
	else:
		# ideal range — slow strafe
		var strafe: Vector3 = direction.cross(Vector3.UP)
		velocity.x = move_toward(velocity.x, strafe.x * move_speed * 0.4, 6.0 * delta)
		velocity.z = move_toward(velocity.z, strafe.z * move_speed * 0.4, 6.0 * delta)


func _start_telegraph() -> void:
	_telegraphing = true
	_telegraph_timer = telegraph_duration
	velocity.x = 0
	velocity.z = 0
	_show_laser()


func _handle_telegraph(delta: float) -> void:
	_telegraph_timer -= delta
	_update_laser()

	if _telegraph_timer <= 0:
		_telegraphing = false
		_fire()
		_hide_laser()


func _fire() -> void:
	attack_timer = attack_cooldown
	if not target or not is_instance_valid(target):
		return

	var damage: int = attack_damage
	if is_elite:
		damage = int(damage * 1.5)

	var from_pos: Vector3 = global_position + Vector3(0, 0.7, 0)
	var to_pos: Vector3 = target.global_position + Vector3(0, 0.8, 0)

	# raycast for line of sight
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collision_mask = 3
	query.exclude = [get_rid()]
	var result: Dictionary = space_state.intersect_ray(query)

	var end_pos: Vector3 = to_pos
	if result.is_empty() or result.collider == target:
		if target.has_method("take_damage"):
			target.take_damage(damage)
		if not result.is_empty():
			end_pos = result.position
	else:
		end_pos = result.get("position", to_pos)
		# break walls
		if result.collider is StaticBody3D and result.collider.has_meta("breakable"):
			var rc: Node = get_node_or_null("/root/Main/RoomController")
			if rc and rc.has_method("damage_breakable_wall"):
				rc.damage_breakable_wall(result.collider)
		# reduced damage through cover
		if target.has_method("take_damage"):
			target.take_damage(maxi(int(damage * 0.15), 1))

	# spawn tracer
	_spawn_tracer(from_pos, end_pos)
	_flash_muzzle()


func _spawn_tracer(from_pos: Vector3, to_pos: Vector3) -> void:
	var tracer: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	var dist: float = from_pos.distance_to(to_pos)
	cyl.top_radius = 0.025
	cyl.bottom_radius = 0.015
	cyl.height = dist
	cyl.radial_segments = 4
	tracer.mesh = cyl

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.0)
	mat.emission_energy_multiplier = 4.0
	mat.albedo_color = Color(1.0, 0.3, 0.1, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tracer.material_override = mat

	var midpoint: Vector3 = (from_pos + to_pos) / 2.0
	tracer.global_position = midpoint
	var dir: Vector3 = (to_pos - from_pos).normalized()
	if dir.length() > 0.001:
		tracer.look_at(tracer.global_position + dir)
		tracer.rotate_object_local(Vector3.RIGHT, PI / 2.0)

	get_tree().root.add_child(tracer)
	var tween: Tween = tracer.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.2)
	tween.parallel().tween_property(mat, "emission_energy_multiplier", 0.0, 0.2)
	tween.chain().tween_callback(tracer.queue_free)


func _show_laser() -> void:
	if _laser_line:
		_laser_line.visible = true
		return

	_laser_line = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.015
	cyl.bottom_radius = 0.015
	cyl.height = 1.0
	_laser_line.mesh = cyl

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.1, 0.1, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.0, 0.0)
	mat.emission_energy_multiplier = 3.0
	mat.no_depth_test = true
	_laser_line.material_override = mat

	add_child(_laser_line)


func _update_laser() -> void:
	if not _laser_line or not target:
		return

	var from_pos: Vector3 = global_position + Vector3(0, 0.7, 0)
	var to_pos: Vector3 = target.global_position + Vector3(0, 0.8, 0)
	var mid: Vector3 = (from_pos + to_pos) / 2.0
	var dist: float = from_pos.distance_to(to_pos)
	var dir: Vector3 = (to_pos - from_pos).normalized()

	_laser_line.global_position = mid
	_laser_line.mesh.height = dist

	# orient cylinder along laser direction
	if dir.length() > 0.01:
		_laser_line.look_at(to_pos)
		_laser_line.rotate_object_local(Vector3.RIGHT, PI / 2.0)


func _hide_laser() -> void:
	if _laser_line:
		_laser_line.visible = false


func _flash_muzzle() -> void:
	if not mesh:
		return
	var mat: Material = mesh.get_surface_override_material(0)
	if mat is StandardMaterial3D:
		var prev: float = mat.emission_energy_multiplier
		mat.emission_energy_multiplier = 4.0
		var tween: Tween = create_tween()
		tween.tween_property(mat, "emission_energy_multiplier", prev, 0.15)


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
	# interrupt telegraph on hit
	if _telegraphing:
		_telegraphing = false
		_hide_laser()
		attack_timer = attack_cooldown * 0.5
	_flash_hit()


func _on_died() -> void:
	is_dying = true
	_hide_laser()
	_play_death()


func _build_visual() -> void:
	# long sniper rifle — extends far forward
	var rifle_body: MeshInstance3D = _make_box(Vector3(0.08, 0.08, 0.7), Vector3(0.25, 0.9, -0.5), Color(0.08, 0.3, 0.45))
	add_child(rifle_body)
	var barrel: MeshInstance3D = _make_box(Vector3(0.04, 0.04, 0.35), Vector3(0.25, 0.9, -0.95), Color(0.06, 0.25, 0.4), Color(0.1, 0.4, 0.7))
	add_child(barrel)
	# scope on top
	var scope: MeshInstance3D = _make_box(Vector3(0.05, 0.05, 0.15), Vector3(0.25, 0.98, -0.55), Color(0.15, 0.5, 0.7), Color(0.1, 0.4, 0.6))
	add_child(scope)
	# stock
	var stock: MeshInstance3D = _make_box(Vector3(0.07, 0.1, 0.15), Vector3(0.25, 0.85, -0.05), Color(0.08, 0.3, 0.45))
	add_child(stock)
	# hood/visor — narrow targeting slit
	var hood: MeshInstance3D = _make_box(Vector3(0.35, 0.15, 0.2), Vector3(0, 1.6, -0.15), Color(0.08, 0.3, 0.5))
	add_child(hood)
	var visor: MeshInstance3D = _make_box(Vector3(0.25, 0.03, 0.06), Vector3(0, 1.5, -0.28), Color(0.2, 0.7, 1.0), Color(0.1, 0.5, 0.9))
	add_child(visor)


func _make_box(size: Vector3, offset: Vector3, color: Color, emission: Color = Color.BLACK) -> MeshInstance3D:
	var m: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	m.mesh = box
	m.position = offset
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	if emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = 1.5
	m.material_override = mat
	return m


func _flash_hit() -> void:
	if not mesh:
		return
	var mat: Material = mesh.get_surface_override_material(0)
	if mat is StandardMaterial3D:
		var original_color: Color = mat.albedo_color
		mat.albedo_color = Color.WHITE
		var tween: Tween = create_tween()
		tween.tween_property(mat, "albedo_color", original_color, 0.1)


func _play_death() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3(1.3, 0.1, 1.3), 0.15)
	tween.tween_property(mesh, "transparency", 1.0, 0.2)
	tween.chain().tween_callback(queue_free)


func _is_local_authority() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return is_multiplayer_authority()
