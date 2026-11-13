extends EnemyBase

# "brood mother" — barely moves, soaks damage, and keeps laying broodlings
# until she is dead. everything she spawned dies with the room.

const LAY_COOLDOWN: float = 5.0
const BROOD_PER_LAY: int = 2
const MAX_BROOD: int = 8
const BOLT_COOLDOWN: float = 3.0
const BILE_COLOR: Color = Color(0.6, 1.0, 0.3)

var _lay: float = 2.5
var _bolt: float = 2.0
var _brood: Array[Node] = []


func _setup() -> void:
	weak_ratio = 0.0


func _ai(delta: float, dist: float) -> void:
	_lay -= delta
	_bolt = maxf(0.0, _bolt - delta)

	if dist > 12.0:
		_chase(delta, 1.0, 6.0)
	else:
		_brake(10.0, delta)
		_face_target(delta, 3.0)

	if _lay <= 0.0:
		_lay = LAY_COOLDOWN * (0.7 if is_elite else 1.0)
		_lay_brood()

	if _bolt <= 0.0 and dist < 30.0 and _has_line_of_sight(target.global_position):
		_bolt = BOLT_COOLDOWN
		_shoot(&"orb", 16.0, damage(), BILE_COLOR, 0.4, 0.06)


func _lay_brood() -> void:
	var rooms: RoomController = Game.rooms()
	if not rooms:
		return
	var alive: Array[Node] = []
	for b: Node in _brood:
		if is_instance_valid(b) and not b.get("is_dying"):
			alive.append(b)
	_brood = alive
	var room: int = MAX_BROOD - _brood.size()
	if room <= 0:
		return
	_flare(0.4)
	Game.sfx_at(&"spawn", global_position, -7.0, 0.1)
	for i: int in mini(BROOD_PER_LAY, room):
		var angle: float = randf() * TAU
		var at: Vector3 = global_position + Vector3(cos(angle), 0, sin(angle)) * (body_radius + 1.2)
		var add: EnemyBase = rooms.spawn_add(&"swarmling", at, false)
		if add:
			_brood.append(add)
