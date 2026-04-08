extends CharacterBody3D

@export var move_speed: float = 6.0
@export var detection_range: float = 60.0
@export var explode_range: float = 3.0
@export var explosion_damage: int = 30
@export var explosion_radius: float = 5.0
@export var attack_damage: int = 5

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var target: CharacterBody3D
var is_dying: bool = false
var has_exploded: bool = false
var _player_manager: PlayerManager

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
	_flash_hit()


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


func _play_explosion() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3(2.5, 2.5, 2.5), 0.12)
	tween.tween_property(mesh, "transparency", 1.0, 0.15)
	tween.chain().tween_callback(queue_free)


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
