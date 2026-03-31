extends CharacterBody3D

@export var move_speed: float = 3.5
@export var detection_range: float = 20.0
@export var dash_speed: float = 35.0
@export var dash_duration: float = 0.25
@export var dash_cooldown: float = 3.0
@export var attack_damage: int = 18
@export var attack_range: float = 2.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var target: CharacterBody3D
var is_dying: bool = false
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var is_elite: bool = false
var _chain_dash_pending: bool = false
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
	dash_cooldown_timer = max(0, dash_cooldown_timer - delta)

	if not target or not is_instance_valid(target):
		target = null
		_find_target()
		move_and_slide()
		return

	var distance: float = global_position.distance_to(target.global_position)

	if is_dashing:
		dash_timer -= delta
		velocity.x = dash_direction.x * dash_speed
		velocity.z = dash_direction.z * dash_speed
		if dash_timer <= 0:
			is_dashing = false
			_try_contact_damage()
			if is_elite and _chain_dash_pending:
				_chain_dash_pending = false
				_start_chain_dash()
	elif distance < detection_range:
		if distance > 8.0 and dash_cooldown_timer <= 0:
			_start_dash()
		else:
			_chase(delta)
		_face_target()

	move_and_slide()


func _start_dash() -> void:
	if not target:
		return
	dash_direction = (target.global_position - global_position).normalized()
	dash_direction.y = 0
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	if is_elite:
		_chain_dash_pending = true


func _start_chain_dash() -> void:
	# second dash after brief pause, re-targeted
	await get_tree().create_timer(0.15).timeout
	if is_dying or not target or not is_instance_valid(target):
		return
	dash_direction = (target.global_position - global_position).normalized()
	dash_direction.y = 0
	is_dashing = true
	dash_timer = dash_duration * 0.8


func _try_contact_damage() -> void:
	if not target:
		return
	var distance: float = global_position.distance_to(target.global_position)
	if distance < attack_range and target.has_method("take_damage"):
		target.take_damage(attack_damage)


func _chase(delta: float) -> void:
	var direction: Vector3 = (target.global_position - global_position).normalized()
	direction.y = 0
	velocity.x = move_toward(velocity.x, direction.x * move_speed, 18.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed, 18.0 * delta)


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
