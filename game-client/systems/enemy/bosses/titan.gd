extends BossBase

# fracture titan — the end of act three. everything it does is big enough to
# see coming: the question is whether you are still fast enough to care.

const SLAM_COLOR: Color = Color(1.0, 0.3, 0.05)
const CHARGE_COLOR: Color = Color(1.0, 0.1, 0.1)
const ROCK_COLOR: Color = Color(1.0, 0.6, 0.15)
const RUIN_COLOR: Color = Color(1.0, 0.25, 0.6)
const MAX_MINIONS: int = 6


func _setup() -> void:
	title = "fracture titan"
	core_radius = 0.75
	attack_cooldown = 2.5
	phase_thresholds = [0.66, 0.33]


func _idle(delta: float, _dist: float) -> void:
	_chase(delta, 1.0 + 0.2 * float(phase - 1), 8.0)


func _pick_attack(dist: float) -> void:
	var options: Array[StringName] = [&"boulders"]
	if dist < 10.0:
		options.append(&"slam")
		options.append(&"slam")
	if dist > 7.0:
		options.append(&"charge")
		options.append(&"charge")
	if phase >= 2 and _minion_count() < MAX_MINIONS:
		options.append(&"summon")
	if phase >= 3:
		options.append(&"ruin")
		options.append(&"ruin")
	options.erase(_last_attack)
	match options[randi() % options.size()]:
		&"slam": _slam()
		&"charge": _begin_charge(0.8, 30.0, 0.9, damage(1.2), 4.4, CHARGE_COLOR)
		&"boulders": _boulders()
		&"summon": _summon_brood()
		&"ruin": _ruin()
	if _last_attack != &"charge" and not _charge.is_empty():
		_last_attack = &"charge"


func _slam() -> void:
	var radius: float = 7.0
	var steps: Array = [
		[0.0, func() -> void:
			_signal_core(SLAM_COLOR, 0.9)
			_warn_circle(global_position, radius, 0.9, SLAM_COLOR)],
		[0.9, func() -> void:
			_fx_blast(global_position + Vector3(0, 0.8, 0), radius, SLAM_COLOR)
			Game.sfx_at(&"boss_slam", global_position, 0.0)
			Game.shake(11.0, global_position, 36.0)
			_hit_players_in_radius(global_position, radius, damage(1.3), DamageInfo.KIND_MELEE, true)
			_spawn_wave(global_position, 26.0, 16.0, damage(0.7), SLAM_COLOR, radius)],
	]
	var duration: float = 1.5
	for extra: int in phase - 1:
		var t: float = 1.4 + float(extra) * 0.5
		steps.append([t, func() -> void:
			_spawn_wave(global_position, 26.0, 16.0, damage(0.7), SLAM_COLOR, 2.0)
			Game.sfx_at(&"boss_shockwave", global_position, -2.0)])
		duration = t + 0.4
	_run(&"slam", steps, duration, false)


func _boulders() -> void:
	var count: int = 3 + (phase - 1)
	_run(&"boulders", [
		[0.0, func() -> void: _signal_core(ROCK_COLOR, 0.6)],
		[0.6, func() -> void: _mortar_rain(count, 7.0, 1.5, damage(1.0), ROCK_COLOR, 0.0, &"big_mortar")],
	], 1.2)


func _summon_brood() -> void:
	_run(&"summon", [
		[0.0, func() -> void: _signal_core(Color(0.4, 1.0, 0.3), 0.7)],
		[0.7, func() -> void:
			_summon(&"chaser", 2, 6.0)
			_summon(&"exploder", 1 if phase == 2 else 2, 6.0)],
	], 1.1)


func _ruin() -> void:
	# the floor itself: a spread of marked circles going off one after another
	var steps: Array = [[0.0, func() -> void: _signal_core(RUIN_COLOR, 0.5)]]
	var rooms: RoomController = Game.rooms()
	for i: int in 9:
		steps.append([0.3 + float(i) * 0.22, func() -> void:
			if not is_instance_valid(target):
				return
			var at: Vector3 = target.global_position + Vector3(randf_range(-9.0, 9.0), 0, randf_range(-9.0, 9.0))
			at.y = 0.1
			if rooms:
				at = rooms.clamp_to_arena(at, 2.0)
			_warned_blast(at, 4.2, 1.2, damage(1.0), RUIN_COLOR)])
	_run(&"ruin", steps, 2.6)
