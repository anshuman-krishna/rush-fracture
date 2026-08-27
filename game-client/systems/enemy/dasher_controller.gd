extends EnemyBase

@export var move_speed: float = 3.5
@export var detection_range: float = 60.0
@export var dash_speed: float = 35.0
@export var dash_duration: float = 0.25
@export var dash_cooldown: float = 3.0
@export var attack_damage: int = 18
@export var attack_range: float = 2.0

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var is_elite: bool = false
var _chain_dash_pending: bool = false


func _physics_process(delta: float) -> void:
	if _check_fall_death():
		return

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

	_clamp_to_arena()
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
	if not is_instance_valid(self) or not is_inside_tree():
		return
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


func _build_visual() -> void:
	# speed fins on back
	var fin_l: MeshInstance3D = _make_box(Vector3(0.04, 0.4, 0.25), Vector3(-0.3, 0.9, 0.15), Color(1.0, 0.7, 0.05), Color(0.9, 0.5, 0.0))
	var fin_r: MeshInstance3D = _make_box(Vector3(0.04, 0.4, 0.25), Vector3(0.3, 0.9, 0.15), Color(1.0, 0.7, 0.05), Color(0.9, 0.5, 0.0))
	add_child(fin_l)
	add_child(fin_r)
	# blade weapon — large forward blade
	var blade: MeshInstance3D = _make_box(Vector3(0.06, 0.08, 0.6), Vector3(0.3, 0.5, -0.45), Color(0.9, 0.9, 0.95), Color(1.0, 0.6, 0.0))
	add_child(blade)
	# blade handle
	var handle: MeshInstance3D = _make_box(Vector3(0.08, 0.15, 0.08), Vector3(0.3, 0.5, -0.1), Color(0.4, 0.3, 0.1))
	add_child(handle)
	# eye slit
	var eye: MeshInstance3D = _make_box(Vector3(0.25, 0.04, 0.06), Vector3(0, 1.1, -0.3), Color(1.0, 0.5, 0.0), Color(1.0, 0.4, 0.0))
	add_child(eye)
