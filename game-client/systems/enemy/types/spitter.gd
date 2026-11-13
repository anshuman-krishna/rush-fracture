extends EnemyBase

# "bile spitter" — lobs acid over cover. each shot marks where it will land
# and leaves a burning pool there, so it punishes standing still.

const PREFERRED_RANGE: float = 16.0
const COOLDOWN: float = 3.2
const FLIGHT_TIME: float = 1.25
const POOL_SECONDS: float = 4.5
const BILE_COLOR: Color = Color(0.6, 1.0, 0.2)

var _cooldown: float = 1.5
var _windup: float = 0.0


func _setup() -> void:
	_cooldown = randf_range(1.0, 2.5)
	weak_ratio = 0.0


func _ai(delta: float, dist: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)

	if _windup > 0.0:
		_windup -= delta
		_brake(30.0, delta)
		_face_target(delta, 10.0)
		if _windup <= 0.0:
			_lob()
			_cooldown = COOLDOWN * (0.7 if is_elite else 1.0)
		return

	_keep_range(delta, dist, PREFERRED_RANGE, 10.0)
	if _cooldown <= 0.0 and dist < 34.0:
		_windup = 0.5
		_flare(0.5)


func _lob() -> void:
	var pm: ProjectileManager = Game.projectiles()
	if not pm or not is_instance_valid(target):
		return
	# aim at where the target will be, at floor level under them
	var lead: Vector3 = Vector3(target.velocity.x, 0, target.velocity.z) * FLIGHT_TIME * 0.6
	var land: Vector3 = target.global_position + lead
	land.y = 0.1
	var rooms: RoomController = Game.rooms()
	if rooms:
		land = rooms.clamp_to_arena(land, 1.0)
	pm.fire_enemy_mortar(_muzzle_position(), land, FLIGHT_TIME, damage(), BILE_COLOR, &"mortar", POOL_SECONDS)
	Game.sfx_at(&"spit", global_position, -6.0, 0.12)
	if is_elite:
		# a second glob to one side
		var offset: Vector3 = Vector3(randf_range(-4.0, 4.0), 0, randf_range(-4.0, 4.0))
		pm.fire_enemy_mortar(_muzzle_position(), land + offset, FLIGHT_TIME + 0.2, damage(), BILE_COLOR, &"mortar", POOL_SECONDS)
