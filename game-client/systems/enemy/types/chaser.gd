extends EnemyBase

# "ripper hound" — runs you down and bites. the bite has a short wind-up, so
# a dash or a step back makes it whiff.

const REACH: float = 1.5
const ATTACK_COOLDOWN: float = 1.1

var _cooldown: float = 0.0


func _ai(delta: float, dist: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if dist <= REACH + body_radius + 0.5 and _cooldown <= 0.0:
		_cooldown = ATTACK_COOLDOWN
		_start_melee(0.32, REACH, damage(), 7.0)
	else:
		_chase(delta)
