extends CharacterBody3D

signal player_damaged(amount: int)
signal player_dashed

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

const INTERP_SPEED: float = 18.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var health: int = max_health
var damage_resist: float = 1.0
var meta_kill_heal: int = 0
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var is_dashing: bool = false
var input: InputProvider = InputProvider.new()
var invert_mouse_y: bool = false

# network sync targets — synchronizer writes to these, visual lerps toward them
var sync_position: Vector3 = Vector3.ZERO
var sync_rotation_y: float = 0.0
var sync_head_rotation_x: float = 0.0
var sync_velocity: Vector3 = Vector3.ZERO

# fall death
var _fall_timer: float = 0.0
const FALL_DEATH_TIME: float = 2.0
const FALL_THRESHOLD_Y: float = -10.0

@onready var head: Node3D = $Head


func _ready() -> void:
	add_to_group("player")
	sync_position = global_position
	sync_rotation_y = rotation.y
	if head:
		sync_head_rotation_x = head.rotation.x

	if _is_local_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_apply_settings()
	var pm: PlayerManager = _get_player_manager()
	if pm:
		pm.register_player(self)


func _exit_tree() -> void:
	var pm: PlayerManager = _get_player_manager()
	if pm:
		pm.unregister_player(self)


func _get_player_manager() -> PlayerManager:
	return get_node_or_null("/root/Main/PlayerManager") as PlayerManager


#func _unhandled_input(event: InputEvent) -> void:
	#if not _is_local_authority():
		#return
#
	#if event is InputEventMouseMotion:
		#rotate_y(-event.screen_relative.x * mouse_sensitivity)
		#print("mouse motion received: ", event.screen_relative)
#
		#var y_input: float = -event.screen_relative.y * mouse_sensitivity
		#if invert_mouse_y:
			#y_input = -y_input
#
		#head.rotate_x(y_input)
		#head.rotation.x = clamp(head.rotation.x, -PI / 2, PI / 2)

	# escape is handled by pause_menu — don't override here

func _input(event: InputEvent) -> void:
	if not _is_local_authority():
		return

	if event is InputEventMouseMotion:
		#print("mouse motion received: ", event.screen_relative)

		rotate_y(-event.screen_relative.x * mouse_sensitivity)

		var y_input: float = -event.screen_relative.y * mouse_sensitivity
		if invert_mouse_y:
			y_input = -y_input

		head.rotate_x(y_input)
		head.rotation.x = clamp(head.rotation.x, -PI / 2, PI / 2)

func _physics_process(delta: float) -> void:
	if _is_local_authority():
		# fall death — kill player after falling for too long
		if global_position.y < FALL_THRESHOLD_Y:
			_fall_timer += delta
			if _fall_timer >= FALL_DEATH_TIME and health > 0:
				take_damage(health)
				return
		else:
			_fall_timer = 0.0

		_handle_dash(delta)
		_apply_gravity(delta)
		_handle_jump()
		_handle_movement(delta)
		move_and_slide()

		# update sync vars so synchronizer sends correct values
		sync_position = global_position
		sync_rotation_y = rotation.y
		sync_velocity = velocity
		if head:
			sync_head_rotation_x = head.rotation.x
	else:
		# remote player — interpolate toward synced values
		global_position = global_position.lerp(sync_position, INTERP_SPEED * delta)
		rotation.y = lerp_angle(rotation.y, sync_rotation_y, INTERP_SPEED * delta)
		velocity = sync_velocity
		if head:
			head.rotation.x = lerp_angle(head.rotation.x, sync_head_rotation_x, INTERP_SPEED * delta)


func _is_local_authority() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return is_multiplayer_authority()


func take_damage(amount: int) -> void:
	var actual: int = max(1, int(amount * damage_resist))
	health = max(0, health - actual)
	player_damaged.emit(actual)


func _handle_movement(delta: float) -> void:
	if is_dashing:
		return

	var move_dir: Vector2 = input.get_move_vector()
	var direction: Vector3 = (transform.basis * Vector3(move_dir.x, 0, move_dir.y)).normalized()

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
	if input.is_jump_pressed() and is_on_floor():
		velocity.y = jump_force


func _handle_dash(delta: float) -> void:
	dash_cooldown_timer = max(0, dash_cooldown_timer - delta)

	if input.is_dash_pressed() and dash_cooldown_timer <= 0:
		var input_dir: Vector2 = input.get_move_vector()
		if input_dir.length() > 0:
			dash_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		else:
			dash_direction = -transform.basis.z

		is_dashing = true
		dash_timer = dash_duration
		dash_cooldown_timer = dash_cooldown
		velocity = dash_direction * dash_force
		# camera feedback
		if head:
			var cam: Camera3D = head.get_node_or_null("Camera3D") as Camera3D
			if cam and cam.has_method("dash_kick"):
				cam.dash_kick()
		player_dashed.emit()

	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false


func _apply_settings() -> void:
	var settings: GameSettings = GameSettings.load_settings()
	mouse_sensitivity = settings.mouse_sensitivity
	invert_mouse_y = settings.invert_mouse_y
