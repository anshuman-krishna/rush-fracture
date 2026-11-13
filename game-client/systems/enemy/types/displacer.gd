extends EnemyBase

# "phase wraith" — blinks to your flank and strikes. the spot it is about to
# appear on is marked a moment before it arrives.

const BLINK_COOLDOWN: float = 3.6
const BLINK_DISTANCE: float = 4.5
const BLINK_TELEGRAPH: float = 0.45
const STRIKE_REACH: float = 1.6
const WARP_COLOR: Color = Color(0.7, 0.3, 1.0)

var _cooldown: float = 1.8
var _strike_cooldown: float = 0.0
var _blink: float = 0.0
var _blink_to: Vector3


func _setup() -> void:
	_cooldown = randf_range(1.2, 2.6)


func _ai(delta: float, dist: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_strike_cooldown = maxf(0.0, _strike_cooldown - delta)

	if _blink > 0.0:
		_blink -= delta
		_brake(40.0, delta)
		if _blink <= 0.0:
			_arrive()
		return

	if _cooldown <= 0.0 and dist > 5.0:
		_begin_blink()
		return

	if dist <= STRIKE_REACH + body_radius + 0.5 and _strike_cooldown <= 0.0:
		_strike_cooldown = 1.4
		_start_melee(0.3, STRIKE_REACH, damage(), 4.0)
	else:
		_chase(delta)


func _begin_blink() -> void:
	if not is_instance_valid(target):
		return
	# behind the target, relative to where they are looking, with some scatter
	var back: Vector3 = target.global_transform.basis.z
	back.y = 0.0
	back = back.normalized().rotated(Vector3.UP, randf_range(-0.9, 0.9))
	_blink_to = target.global_position + back * BLINK_DISTANCE
	_blink_to.y = 0.1
	var rooms: RoomController = Game.rooms()
	if rooms:
		_blink_to = rooms.clamp_to_arena(_blink_to, 1.0)
	_blink = BLINK_TELEGRAPH
	_cooldown = BLINK_COOLDOWN * (0.6 if is_elite else 1.0)
	Vfx.ring(global_position, 1.6, WARP_COLOR, BLINK_TELEGRAPH, 1.6, 0.4)
	_warn_circle(_blink_to, 1.4, BLINK_TELEGRAPH, WARP_COLOR)
	Game.sfx_at(&"warp", global_position, -8.0, 0.1)
	if model:
		var tw: Tween = create_tween()
		tw.tween_property(model, "scale", Vector3.ONE * 0.1, BLINK_TELEGRAPH)


func _arrive() -> void:
	global_position = _blink_to
	velocity = Vector3.ZERO
	Vfx.sparks(aim_point(), Vector3.UP, WARP_COLOR, 7.0, 180.0)
	Vfx.light(aim_point(), WARP_COLOR, 3.0, 0.2, 6.0)
	if model:
		var tw: Tween = create_tween()
		tw.tween_property(model, "scale", Vector3.ONE, 0.15).set_ease(Tween.EASE_OUT)
	_face_target(1.0, 100.0)
	_strike_cooldown = 0.0
	_recover = 0.15
