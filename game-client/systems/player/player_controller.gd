extends CharacterBody3D

signal player_damaged(amount: int)

@export var move_speed: float = 12.0
@export var acceleration: float = 50.0
@export var friction: float = 35.0
@export var air_acceleration: float = 20.0
@export var air_friction: float = 5.0
@export var jump_force: float = 10.0
@export var dash_force: float = 28.0
@export var dash_duration: float = 0.12
@export var dash_cooldown: float = 0.6
@export var mouse_sensitivity: float = 0.002
@export var max_health: int = 100

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var health: int = max_health
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var is_dashing: bool = false

@onready var head: Node3D = $Head


func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, -PI / 2, PI / 2)

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	_handle_dash(delta)
	_apply_gravity(delta)
	_handle_jump()
	_handle_movement(delta)
	move_and_slide()


func take_damage(amount: int) -> void:
	health = max(0, health - amount)
	player_damaged.emit(amount)


func _handle_movement(delta: float) -> void:
	if is_dashing:
		return

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var on_floor: bool = is_on_floor()
	var accel: float = acceleration if on_floor else air_acceleration
	var fric: float = friction if on_floor else air_friction

	if direction.length() > 0:
		velocity.x = move_toward(velocity.x, direction.x * move_speed, accel * delta)
		velocity.z = move_toward(velocity.z, direction.z * move_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, fric * delta)
		velocity.z = move_toward(velocity.z, 0, fric * delta)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta


func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force


func _handle_dash(delta: float) -> void:
	dash_cooldown_timer = max(0, dash_cooldown_timer - delta)

	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0:
		var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if input_dir.length() > 0:
			dash_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		else:
			dash_direction = -transform.basis.z

		is_dashing = true
		dash_timer = dash_duration
		dash_cooldown_timer = dash_cooldown
		velocity = dash_direction * dash_force

	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
