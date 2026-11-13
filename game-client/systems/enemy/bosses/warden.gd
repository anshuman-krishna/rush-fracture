extends BossBase

# brood warden — act one's gatekeeper. holds its ground behind pulses you
# have to jump, calls for help, and once hurt starts dropping onto you.

const PULSE_COLOR: Color = Color(0.2, 0.9, 0.9)
const SLAM_COLOR: Color = Color(1.0, 0.4, 0.1)
const WARP_COLOR: Color = Color(0.75, 0.3, 1.0)
const BOLT_COLOR: Color = Color(0.5, 1.0, 0.6)
const MAX_MINIONS: int = 5


func _setup() -> void:
	title = "brood warden"
	core_part = "warden_core"
	core_radius = 0.55
	attack_cooldown = 2.6
	phase_thresholds = [0.66, 0.33]


func _idle(delta: float, dist: float) -> void:
	if phase == 1:
		_keep_range(delta, dist, 11.0, 8.0)
	else:
		_chase(delta, 1.25, 10.0)


func _pick_attack(dist: float) -> void:
	var options: Array[StringName] = [&"pulse", &"volley"]
	if _minion_count() < MAX_MINIONS and phase < 3:
		options.append(&"summon")
	if phase >= 2:
		options.append(&"drop")
		options.append(&"drop")
	if dist < 6.0:
		options.append(&"pulse")
	options.erase(_last_attack)
	match options[randi() % options.size()]:
		&"pulse": _pulse()
		&"volley": _volley()
		&"summon": _call_brood()
		&"drop": _drop()


func _pulse() -> void:
	var steps: Array = [
		[0.0, func() -> void:
			_signal_core(PULSE_COLOR, 0.7)
			_warn_circle(global_position, 3.0, 0.7, PULSE_COLOR)],
		[0.7, func() -> void: _emit_pulse()],
	]
	var duration: float = 1.2
	if phase >= 3:
		steps.append([1.25, func() -> void: _emit_pulse()])
		duration = 1.8
	_run(&"pulse", steps, duration)


func _emit_pulse() -> void:
	_spawn_wave(global_position, 24.0, 15.0, damage(), PULSE_COLOR, 2.0)
	Game.sfx_at(&"boss_shockwave", global_position, -2.0)
	Game.shake(5.0, global_position, 30.0)


func _volley() -> void:
	var count: int = 7 if phase >= 3 else 5
	var steps: Array = [
		[0.0, func() -> void: _signal_core(BOLT_COLOR, 0.5)],
		[0.5, func() -> void: _fan(&"bolt", count, 0.7, 24.0, damage(0.6), BOLT_COLOR)],
	]
	if phase >= 2:
		steps.append([0.95, func() -> void: _fan(&"bolt", count - 1, 0.55, 26.0, damage(0.6), BOLT_COLOR)])
	_run(&"volley", steps, 1.4)


func _call_brood() -> void:
	_run(&"summon", [
		[0.0, func() -> void: _signal_core(Color(0.4, 1.0, 0.3), 0.6)],
		[0.6, func() -> void:
			_summon(&"chaser", 2)
			if phase >= 2:
				_summon(&"shooter", 1)],
	], 1.0)


func _drop() -> void:
	if not is_instance_valid(target):
		return
	var at: Vector3 = target.global_position
	at.y = 0.1
	var radius: float = 5.5
	_run(&"drop", [
		[0.0, func() -> void:
			_signal_core(WARP_COLOR, 0.85)
			_warn_circle(at, radius, 0.85, SLAM_COLOR)],
		[0.85, func() -> void:
			_blink_to(at, WARP_COLOR)
			_fx_blast(at + Vector3(0, 0.6, 0), radius, SLAM_COLOR)
			Game.sfx_at(&"boss_slam", at, 0.0)
			Game.shake(8.0, at, 30.0)
			_hit_players_in_radius(at, radius, damage(1.3), DamageInfo.KIND_MELEE)
			if phase >= 3:
				_spawn_wave(at, 16.0, 14.0, damage(0.7), SLAM_COLOR, radius)],
	], 1.5, false)
