extends CharacterBody3D

@export var move_speed: float = 4.0
@export var detection_range: float = 30.0
@export var preferred_range: float = 12.0
@export var attack_damage: int = 8
@export var attack_cooldown: float = 2.0
@export var projectile_speed: float = 30.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var target: CharacterBody3D
var attack_timer: float = 0.0
var is_dying: bool = false
var is_elite: bool = false
var _player_manager: PlayerManager

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

	_maintain_distance(delta, distance)
	_face_target()

	if distance < detection_range and attack_timer <= 0:
		_fire_at_target()

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
	if target.has_method("take_damage"):
		target.take_damage(attack_damage)
	if is_elite:
		_elite_burst_fire()


func _elite_burst_fire() -> void:
	# two extra rapid shots at reduced damage
	for i in 2:
		await get_tree().create_timer(0.15).timeout
		if is_dying or not target:
			return
		if target.has_method("take_damage"):
			target.take_damage(int(attack_damage * 0.6))


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
	is_dying = true
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
