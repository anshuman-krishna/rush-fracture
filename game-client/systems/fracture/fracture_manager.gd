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
var _explosion_timer: float = 0.0
var _camera: Camera3D


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
		return

	# random explosions tick
	if active_fracture == FractureDefinitions.FractureType.RANDOM_EXPLOSIONS:
		_explosion_timer -= delta
		if _explosion_timer <= 0:
			_explosion_timer = 1.5 + randf() * 1.5
			_spawn_random_explosion()


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
			pass
		FractureDefinitions.FractureType.LOW_GRAVITY:
			_player.gravity *= 0.15
			_player.jump_force *= 2.0
		FractureDefinitions.FractureType.DOUBLE_SPEED_ENEMIES:
			_buff_all_enemy_speeds(2.0)
		FractureDefinitions.FractureType.RANDOM_EXPLOSIONS:
			_explosion_timer = 1.0
		FractureDefinitions.FractureType.VISION_DISTORTION:
			_apply_vision_distortion()


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
		FractureDefinitions.FractureType.LOW_GRAVITY:
			_player.gravity = _original_gravity
			_player.jump_force = 10.0
		FractureDefinitions.FractureType.DOUBLE_SPEED_ENEMIES:
			_buff_all_enemy_speeds(0.5)
		FractureDefinitions.FractureType.RANDOM_EXPLOSIONS:
			_explosion_timer = 0.0
		FractureDefinitions.FractureType.VISION_DISTORTION:
			_revert_vision_distortion()


func _buff_all_enemy_speeds(multiplier: float) -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if "move_speed" in enemy:
			enemy.move_speed *= multiplier


func _spawn_random_explosion() -> void:
	if not _player:
		return

	# explosion at random position near the player
	var angle: float = randf() * TAU
	var dist: float = 3.0 + randf() * 12.0
	var pos: Vector3 = _player.global_position + Vector3(cos(angle) * dist, 0.5, sin(angle) * dist)

	# damage anything nearby (player and enemies)
	var radius: float = 3.5
	var damage: int = 10

	# damage player
	if _player.global_position.distance_to(pos) < radius:
		if _player.has_method("take_damage"):
			_player.take_damage(damage)

	# damage enemies
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy is Node3D and enemy.global_position.distance_to(pos) < radius:
			var h: HealthComponent = enemy.get_node_or_null("HealthComponent") as HealthComponent
			if h and h.is_alive():
				h.take_damage(damage)

	_spawn_explosion_visual(pos, radius)


func _spawn_explosion_visual(pos: Vector3, radius: float) -> void:
	var indicator: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	indicator.mesh = sphere

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.0, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.0)
	mat.emission_energy_multiplier = 3.0
	indicator.material_override = mat

	indicator.global_position = pos
	get_tree().root.add_child(indicator)

	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(indicator, "scale", Vector3(radius, radius, radius), 0.25)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tween.chain().tween_callback(indicator.queue_free)


func _apply_vision_distortion() -> void:
	_camera = _get_camera()
	if not _camera:
		return
	# reduce fov for claustrophobic feel
	_camera.fov = 55.0


func _revert_vision_distortion() -> void:
	if _camera:
		_camera.fov = 75.0
	_camera = null


func _get_camera() -> Camera3D:
	var pm: PlayerManager = get_node_or_null("/root/Main/PlayerManager") as PlayerManager
	if pm:
		return pm.get_primary_camera()
	return null
