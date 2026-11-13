extends EnemyBase

# "brood hulk" — slow, enormous, and hard to move. its ground slam covers a
# wide circle but only hurts what is touching the floor: jump it.

const SLAM_RANGE: float = 5.0
const SLAM_RADIUS: float = 5.5
const SLAM_WINDUP: float = 0.9
const SLAM_COOLDOWN: float = 3.6
const ROCK_COOLDOWN: float = 5.0
const SLAM_COLOR: Color = Color(1.0, 0.3, 0.05)

var _cooldown: float = 1.0
var _rock: float = 3.0
var _slam: float = 0.0


func _ai(delta: float, dist: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_rock = maxf(0.0, _rock - delta)

	if _slam > 0.0:
		_slam -= delta
		_brake(40.0, delta)
		if _slam <= 0.0:
			_do_slam()
		return

	if dist <= SLAM_RANGE and _cooldown <= 0.0:
		_slam = SLAM_WINDUP
		_cooldown = SLAM_COOLDOWN
		_warn_circle(global_position, SLAM_RADIUS, SLAM_WINDUP, SLAM_COLOR)
		_flare(SLAM_WINDUP)
		Game.sfx_at(&"heavy_windup", global_position, -5.0, 0.05)
		return

	# elites also throw debris when you kite them
	if is_elite and dist > 9.0 and _rock <= 0.0:
		_rock = ROCK_COOLDOWN
		var pm: ProjectileManager = Game.projectiles()
		if pm:
			var land: Vector3 = target.global_position
			land.y = 0.1
			pm.fire_enemy_mortar(aim_point() + Vector3(0, 1.0, 0), land, 1.3, damage(0.7), SLAM_COLOR, &"mortar")

	_chase(delta, 1.0, 10.0)


func _do_slam() -> void:
	_recover = 0.6
	Vfx.ring(global_position, SLAM_RADIUS, SLAM_COLOR, 0.35, 0.6, 0.35)
	Vfx.disc(global_position, SLAM_RADIUS * 0.9, Color(1.0, 0.35, 0.1, 0.5), 0.3)
	Game.sfx_at(&"boss_slam", global_position, -3.0, 0.08)
	Game.shake(7.0, global_position, 24.0)
	_hit_players_in_radius(global_position, SLAM_RADIUS, damage(), DamageInfo.KIND_MELEE, true)
