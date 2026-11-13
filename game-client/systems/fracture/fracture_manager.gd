class_name FractureManager
extends Node

# runs fracture events. every effect on the player is a stat modifier under
# the "fracture" key, so starting and ending an event can never clobber a
# change some other system made in the meantime.
#
# in multiplayer the host rolls and broadcasts the event; each peer then
# applies it to its own player.

signal fracture_started(type: int)
signal fracture_ended(type: int)

const KEY: StringName = &"fracture"
const T: Dictionary = FractureDefinitions.FractureType

var active_fracture: int = -1
var fracture_timer: float = 0.0
var is_active: bool = false

var _player: CharacterBody3D
var _explosion_timer: float = 0.0


func bind(player: CharacterBody3D) -> void:
	_player = player


func _process(delta: float) -> void:
	if not is_active:
		return
	fracture_timer -= delta
	if fracture_timer <= 0.0:
		end_fracture()
		return
	if active_fracture == T.RANDOM_EXPLOSIONS:
		_explosion_timer -= delta
		if _explosion_timer <= 0.0:
			_explosion_timer = randf_range(0.9, 1.8)
			_spawn_eruption()


## rolls for an event and starts it if the roll succeeds. returns the type, or
## -1. only the host (or a solo player) should call this.
func try_trigger(room_difficulty: float) -> int:
	if is_active:
		return -1
	var chance: float = clampf(0.1 + (room_difficulty - 1.0) * 0.07, 0.0, 0.3)
	if randf() > chance:
		return -1
	var types: Array = FractureDefinitions.EVENTS.keys()
	var type: int = types[randi() % types.size()]
	start_fracture(type)
	return type


func start_fracture(type: int) -> void:
	if is_active:
		end_fracture()
	active_fracture = type
	fracture_timer = FractureDefinitions.get_duration(type)
	is_active = true
	_apply(type)
	fracture_started.emit(type)


func end_fracture() -> void:
	if not is_active:
		return
	var ended: int = active_fracture
	_revert()
	active_fracture = -1
	is_active = false
	fracture_timer = 0.0
	fracture_ended.emit(ended)


func get_active_name() -> String:
	return FractureDefinitions.get_event_name(active_fracture) if is_active else ""


func get_time_remaining() -> float:
	return fracture_timer if is_active else 0.0


func get_time_ratio() -> float:
	if not is_active:
		return 0.0
	return clampf(fracture_timer / FractureDefinitions.get_duration(active_fracture), 0.0, 1.0)


func _apply(type: int) -> void:
	var rooms: RoomController = Game.rooms()
	if type == T.DOUBLE_SPEED_ENEMIES and rooms:
		rooms.set_enemy_speed_mod(KEY, 1.7)
	if type == T.RANDOM_EXPLOSIONS:
		_explosion_timer = 1.0
	if not is_instance_valid(_player):
		return
	var s: StatBlock = _player.stats
	match type:
		T.VELOCITY_SURGE:
			s.set_mul(&"move_speed", KEY, 1.7)
			s.set_mul(&"dash_force", KEY, 1.4)
		T.UNSTABLE_GRAVITY:
			s.set_mul(&"gravity_scale", KEY, 0.4)
			s.set_mul(&"jump_force", KEY, 1.3)
		T.LOW_GRAVITY:
			s.set_mul(&"gravity_scale", KEY, 0.18)
			s.set_mul(&"jump_force", KEY, 1.15)
		T.VISION_DISTORTION:
			s.set_add(&"fov_bias", KEY, -32.0)
		T.BLOOD_FRENZY:
			s.set_mul(&"damage", KEY, 1.5)
			s.set_mul(&"damage_taken", KEY, 1.5)
		T.ESSENCE_STORM:
			s.set_mul(&"essence_gain", KEY, 3.0)


func _revert() -> void:
	var rooms: RoomController = Game.rooms()
	if rooms:
		rooms.set_enemy_speed_mod(KEY, 1.0)
	if is_instance_valid(_player):
		_player.stats.remove_key(KEY)


## a marked circle near the player that goes off a moment later. it hurts
## whoever is standing in it, enemies included.
func _spawn_eruption() -> void:
	if not is_instance_valid(_player):
		return
	var angle: float = randf() * TAU
	var at: Vector3 = _player.global_position + Vector3(cos(angle), 0, sin(angle)) * randf_range(0.0, 9.0)
	at.y = 0.1
	var rooms: RoomController = Game.rooms()
	if rooms:
		at = rooms.clamp_to_arena(at, 1.0)
	var radius: float = 3.6
	var color: Color = Color(1.0, 0.45, 0.1)
	Vfx.telegraph_circle(at, radius, 0.9, color)
	var player: CharacterBody3D = _player
	get_tree().create_timer(0.9).timeout.connect(func() -> void:
		Vfx.blast(at + Vector3(0, 0.5, 0), radius, color)
		Game.sfx_at(&"explosion_small", at, -5.0, 0.2)
		if is_instance_valid(player) and Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length() <= radius:
			player.take_damage(12, DamageInfo.make(12, DamageInfo.KIND_HAZARD))
		var combat: Combat = Game.combat()
		if combat:
			combat.blast(at, radius, 40.0, {"can_proc": false})
	)
