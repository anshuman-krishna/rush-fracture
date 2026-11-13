extends EnemyBase

# "choir spore" — hangs back and keeps the rest alive: periodic heals and a
# speed boost for everything near it. kill it first.

const PREFERRED_RANGE: float = 17.0
const PULSE_RADIUS: float = 9.0
const PULSE_COOLDOWN: float = 4.0
const HEAL_RATIO: float = 0.12
const HASTE: float = 0.25
const HASTE_SECONDS: float = 3.0
const BOLT_COOLDOWN: float = 2.8
const PULSE_COLOR: Color = Color(0.3, 1.0, 0.45)

var _pulse: float = 2.0
var _bolt: float = 1.5


func _ai(delta: float, dist: float) -> void:
	_pulse -= delta
	_bolt = maxf(0.0, _bolt - delta)
	_keep_range(delta, dist, PREFERRED_RANGE, 12.0)

	if _pulse <= 0.0:
		_pulse = PULSE_COOLDOWN * (0.7 if is_elite else 1.0)
		_buff_allies()

	if _bolt <= 0.0 and dist < 30.0 and _has_line_of_sight(target.global_position):
		_bolt = BOLT_COOLDOWN
		_shoot(&"bolt", 22.0, damage(), PULSE_COLOR, 0.3, 0.05)


func _buff_allies() -> void:
	var touched: int = 0
	for e: Node3D in Combat.enemies_in_radius(get_tree(), aim_point(), PULSE_RADIUS):
		if e == self or not e is EnemyBase:
			continue
		var ally: EnemyBase = e as EnemyBase
		if ally.health and ally.health.is_alive():
			ally.health.heal(int(ally.health.max_health * HEAL_RATIO * (1.5 if is_elite else 1.0)))
		# a timed stat modifier owned by the ally itself: it expires on the
		# ally's own clock, so nothing here has to remember a speed to restore
		ally.apply_haste(HASTE, HASTE_SECONDS)
		Vfx.lightning(aim_point(), ally.aim_point(), PULSE_COLOR, 0.25, 0.3, 0.014)
		touched += 1
	if touched > 0:
		Vfx.ring(global_position, PULSE_RADIUS, PULSE_COLOR, 0.5, 0.5, 0.12)
		Game.sfx_at(&"heal_pulse", global_position, -8.0, 0.1)
