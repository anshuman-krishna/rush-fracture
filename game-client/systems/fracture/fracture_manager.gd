class_name FractureManager
extends Node

signal fracture_started(type: FractureDefinitions.FractureType)
signal fracture_ended(type: FractureDefinitions.FractureType)

var active_fracture: FractureDefinitions.FractureType = -1
var fracture_timer: float = 0.0
var is_active: bool = false

var _player: CharacterBody3D
var _original_gravity: float
var _original_speed: float


func bind(player: CharacterBody3D) -> void:
	_player = player
	_original_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	_original_speed = player.move_speed


func _process(delta: float) -> void:
	if not is_active:
		return

	fracture_timer -= delta
	if fracture_timer <= 0:
		end_fracture()


func try_trigger(room_difficulty: float) -> bool:
	if is_active:
		return false

	# base 10% chance, scales with difficulty
	var chance: float = 0.10 + (room_difficulty - 1.0) * 0.08
	if randf() > chance:
		return false

	var types: Array = FractureDefinitions.FractureType.values()
	var type: FractureDefinitions.FractureType = types[randi() % types.size()]
	start_fracture(type)
	return true


func start_fracture(type: FractureDefinitions.FractureType) -> void:
	active_fracture = type
	fracture_timer = FractureDefinitions.get_duration(type)
	is_active = true

	_apply_effect(type)
	fracture_started.emit(type)


func end_fracture() -> void:
	if not is_active:
		return

	_revert_effect(active_fracture)
	var ended_type: FractureDefinitions.FractureType = active_fracture
	active_fracture = -1
	is_active = false
	fracture_timer = 0.0
	fracture_ended.emit(ended_type)


func get_active_name() -> String:
	if not is_active:
		return ""
	return FractureDefinitions.get_name(active_fracture)


func get_time_remaining() -> float:
	return fracture_timer if is_active else 0.0


func _apply_effect(type: FractureDefinitions.FractureType) -> void:
	if not _player:
		return

	_original_speed = _player.move_speed

	match type:
		FractureDefinitions.FractureType.VELOCITY_SURGE:
			_player.move_speed *= 1.8
			_player.dash_force *= 1.5
		FractureDefinitions.FractureType.UNSTABLE_GRAVITY:
			_player.gravity *= 0.35
			_player.jump_force *= 1.6
		FractureDefinitions.FractureType.ENEMY_DUPLICATION:
			# handled by room_controller checking fracture state
			pass


func _revert_effect(type: FractureDefinitions.FractureType) -> void:
	if not _player:
		return

	match type:
		FractureDefinitions.FractureType.VELOCITY_SURGE:
			_player.move_speed = _original_speed
			_player.dash_force = 28.0
		FractureDefinitions.FractureType.UNSTABLE_GRAVITY:
			_player.gravity = _original_gravity
			_player.jump_force = 10.0
		FractureDefinitions.FractureType.ENEMY_DUPLICATION:
			pass
