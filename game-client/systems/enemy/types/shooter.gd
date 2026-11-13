extends EnemyBase

# "spore marksman" — holds mid range and fires short bursts of bolts. the
# bolts travel, so strafing and cover both work.

const PREFERRED_RANGE: float = 13.0
const BOLT_SPEED: float = 27.0
const COOLDOWN: float = 2.4
const BOLT_COLOR: Color = Color(0.6, 0.35, 1.0)

var _cooldown: float = 1.0
var _burst_left: int = 0
var _burst_timer: float = 0.0
var _windup: float = 0.0


func _setup() -> void:
	_cooldown = randf_range(0.6, 1.8)


func _ai(delta: float, dist: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)

	if _windup > 0.0:
		_windup -= delta
		_brake(30.0, delta)
		_face_target(delta, 12.0)
		if _windup <= 0.0:
			_burst_left = 5 if is_elite else 3
			_burst_timer = 0.0
		return

	if _burst_left > 0:
		_brake(30.0, delta)
		_face_target(delta, 12.0)
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_burst_timer = 0.13
			_burst_left -= 1
			_shoot(&"bolt", BOLT_SPEED, damage(), BOLT_COLOR, 0.5, 0.04)
			if _burst_left <= 0:
				_cooldown = COOLDOWN
		return

	var sees: bool = _has_line_of_sight(target.global_position)
	if not sees:
		# no shot from here: walk until there is one
		_chase(delta, 0.9, 16.0)
		return
	_keep_range(delta, dist, PREFERRED_RANGE)
	if _cooldown <= 0.0 and dist < 40.0:
		_windup = 0.4
		_flare(0.4)
