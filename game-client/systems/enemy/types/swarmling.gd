extends EnemyBase

# "broodling" — tiny, fast, weak, and never alone. weaves as it runs so a
# pack is hard to line up.

const REACH: float = 0.9

var _cooldown: float = 0.0
var _weave: float = 0.0


func _setup() -> void:
	_weave = randf() * TAU


func _ai(delta: float, dist: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_weave += delta * 7.0
	if dist <= REACH + body_radius + 0.5 and _cooldown <= 0.0:
		_cooldown = 0.9
		_start_melee(0.2, REACH, damage(), 5.0, 0.2)
		return
	var dir: Vector3 = _to_target()
	var side: Vector3 = dir.cross(Vector3.UP) * sin(_weave) * 0.55
	var move_dir: Vector3 = _steer((dir + side).normalized())
	_move(move_dir, speed(), 30.0, delta)
	_face_dir(move_dir, delta, 14.0)
