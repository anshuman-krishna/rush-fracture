extends EnemyBase

# "sting drone" — hovers overhead and circles, firing needle bursts down at
# you. it is the reason to look up.

const ORBIT_RADIUS: float = 10.0
const HOVER_MIN: float = 4.0
const HOVER_MAX: float = 6.5
const NEEDLE_SPEED: float = 30.0
const COOLDOWN: float = 2.2
const NEEDLE_COLOR: Color = Color(1.0, 0.75, 0.2)

var _cooldown: float = 1.2
var _burst_left: int = 0
var _burst_timer: float = 0.0
var _orbit_angle: float = 0.0
var _orbit_dir: float = 1.0
var _hover: float = 5.0
var _bob: float = 0.0


func _setup() -> void:
	_orbit_angle = randf() * TAU
	_orbit_dir = 1.0 if randf() < 0.5 else -1.0
	_hover = randf_range(HOVER_MIN, HOVER_MAX)
	_cooldown = randf_range(0.8, 2.0)
	weak_ratio = 0.0


func _ai(delta: float, _dist: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_orbit_angle += _orbit_dir * delta * 0.6

	var goal: Vector3 = target.global_position + Vector3(cos(_orbit_angle), 0, sin(_orbit_angle)) * ORBIT_RADIUS
	goal.y = maxf(target.global_position.y - 0.9, 0.0) + _hover
	var rooms: RoomController = Game.rooms()
	if rooms:
		var clamped: Vector3 = rooms.clamp_to_arena(goal, 1.5)
		goal.x = clamped.x
		goal.z = clamped.z
	var to_goal: Vector3 = goal - global_position
	var desired: Vector3 = to_goal.limit_length(1.0) * speed()
	velocity = velocity.move_toward(desired, 14.0 * delta)
	_face_target(delta, 8.0)

	if _burst_left > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_burst_timer = 0.12
			_burst_left -= 1
			_shoot(&"needle", NEEDLE_SPEED, damage(), NEEDLE_COLOR, 0.6, 0.05)
			if _burst_left <= 0:
				_cooldown = COOLDOWN
	elif _cooldown <= 0.0 and _has_line_of_sight(target.global_position):
		_burst_left = 5 if is_elite else 3
		_burst_timer = 0.3
		_flare(0.3)


func _tick_visual(delta: float) -> void:
	# wing buzz: a fast shallow bob on the model only
	_bob += delta * 22.0
	if model and not is_dying and _spawn_timer <= 0.0:
		model.position.y = -body_height * 0.5 + sin(_bob) * 0.04


func _build_visual() -> void:
	super._build_visual()
	if model:
		# the model's origin is its lowest point; a flyer's body origin is its centre
		model.position.y = -body_height * 0.5
