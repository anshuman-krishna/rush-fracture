extends EnemyBase

# "tendon leaper" — coils, then crosses the room in one jump and lands on
# you. the landing spot is marked while it is still in the air.

const LEAP_MIN: float = 6.0
const LEAP_MAX: float = 18.0
const LEAP_TIME: float = 0.8
const LEAP_COOLDOWN: float = 3.4
const LAND_RADIUS: float = 2.8
const BITE_REACH: float = 1.4

var _cooldown: float = 1.5
var _bite_cooldown: float = 0.0
var _coil: float = 0.0
var _leaping: bool = false
var _air_time: float = 0.0
var _land_at: Vector3


func _setup() -> void:
	_cooldown = randf_range(0.8, 2.2)


func _ai(delta: float, dist: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_bite_cooldown = maxf(0.0, _bite_cooldown - delta)

	if _leaping:
		_air_time += delta
		_face_dir(Vector3(velocity.x, 0, velocity.z).normalized(), delta, 14.0)
		if _air_time > 0.15 and is_on_floor():
			_land()
		return

	if _coil > 0.0:
		_coil -= delta
		_brake(40.0, delta)
		_face_target(delta, 12.0)
		if _coil <= 0.0:
			_launch()
		return

	if dist >= LEAP_MIN and dist <= LEAP_MAX and _cooldown <= 0.0 and is_on_floor():
		_coil = 0.45
		_flare(0.45)
		return

	if dist <= BITE_REACH + body_radius + 0.5 and _bite_cooldown <= 0.0:
		_bite_cooldown = 1.2
		_start_melee(0.3, BITE_REACH, damage(0.7), 5.0)
	else:
		_chase(delta)


func _launch() -> void:
	if not is_instance_valid(target):
		return
	_land_at = target.global_position + Vector3(target.velocity.x, 0, target.velocity.z) * LEAP_TIME * 0.5
	_land_at.y = 0.1
	var rooms: RoomController = Game.rooms()
	if rooms:
		_land_at = rooms.clamp_to_arena(_land_at, 1.5)
	var flat: Vector3 = _land_at - global_position
	flat.y = 0.0
	velocity = flat / LEAP_TIME
	velocity.y = 0.5 * _gravity * LEAP_TIME
	_leaping = true
	_air_time = 0.0
	_cooldown = LEAP_COOLDOWN
	_warn_circle(_land_at, LAND_RADIUS, LEAP_TIME, Color(1.0, 0.3, 0.1))
	Game.sfx_at(&"leap", global_position, -8.0, 0.1)


func _land() -> void:
	_leaping = false
	velocity.x = 0.0
	velocity.z = 0.0
	_recover = 0.55
	Vfx.ring(global_position, LAND_RADIUS, Color(1.0, 0.4, 0.15), 0.3, 0.4, 0.3)
	Game.sfx_at(&"thud", global_position, -6.0, 0.1)
	Game.shake(3.0, global_position, 18.0)
	_hit_players_in_radius(global_position, LAND_RADIUS, damage(), DamageInfo.KIND_MELEE)


func _on_hurt(_amount: int, _info: DamageInfo) -> void:
	# shooting it out of a coil cancels the jump
	if _coil > 0.0:
		_coil = 0.0
		_cooldown = LEAP_COOLDOWN * 0.5
