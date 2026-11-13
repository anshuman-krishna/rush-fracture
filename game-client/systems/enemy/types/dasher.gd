extends EnemyBase

# "blink fang" — circles at a distance, then commits to a straight-line
# charge along a marked lane. sidestep the lane and it sails past.

const ORBIT_RANGE: float = 10.0
const DASH_SPEED: float = 34.0
const DASH_TIME: float = 0.38
const DASH_COOLDOWN: float = 3.0
const TELEGRAPH: float = 0.55
const HIT_REACH: float = 1.5

var _cooldown: float = 1.5
var _aim_time: float = 0.0
var _dash_time: float = 0.0
var _dash_dir: Vector3
var _has_hit: bool = false
var _chain_left: int = 0


func _setup() -> void:
	_cooldown = randf_range(1.0, 2.5)


func _ai(delta: float, dist: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)

	if _dash_time > 0.0:
		_dash_time -= delta
		velocity.x = _dash_dir.x * DASH_SPEED
		velocity.z = _dash_dir.z * DASH_SPEED
		if not _has_hit and is_instance_valid(target):
			var flat: Vector3 = target.global_position - global_position
			if Vector2(flat.x, flat.z).length() <= HIT_REACH and absf(flat.y) < 2.2:
				_has_hit = true
				_hit_player(target, damage())
		if _dash_time <= 0.0:
			velocity.x *= 0.2
			velocity.z *= 0.2
			if _chain_left > 0:
				_chain_left -= 1
				_begin_aim(TELEGRAPH * 0.6)
			else:
				_recover = 0.5
				_cooldown = DASH_COOLDOWN
		return

	if _aim_time > 0.0:
		_aim_time -= delta
		_brake(40.0, delta)
		_face_dir(_dash_dir, delta, 16.0)
		if _aim_time <= 0.0:
			_dash_time = DASH_TIME
			_has_hit = false
			Game.sfx_at(&"enemy_dash", global_position, -6.0, 0.1)
		return

	if _cooldown <= 0.0 and dist > 4.0 and dist < 26.0 and _has_line_of_sight(target.global_position):
		_chain_left = 1 if is_elite else 0
		_begin_aim(TELEGRAPH)
		return
	_keep_range(delta, dist, ORBIT_RANGE, 18.0)


func _begin_aim(seconds: float) -> void:
	_dash_dir = _to_target()
	if _dash_dir.length() < 0.1:
		_dash_dir = -global_transform.basis.z
	_aim_time = seconds
	var reach: float = DASH_SPEED * DASH_TIME
	_warn_line(global_position, global_position + _dash_dir * reach, 2.2, seconds, Color(1.0, 0.25, 0.1))
	_flare(seconds)
