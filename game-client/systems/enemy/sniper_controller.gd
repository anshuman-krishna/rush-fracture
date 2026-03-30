extends CharacterBody3D

# long-range enemy that holds position and fires high-damage shots.
# telegraphs attacks with a laser sight before firing.

@export var move_speed: float = 2.5
@export var detection_range: float = 40.0
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
	if not target:
		return

	var damage: int = attack_damage
	if is_elite:
		damage = int(damage * 1.5)

	if target.has_method("take_damage"):
		target.take_damage(damage)

	_flash_muzzle()


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
