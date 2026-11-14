extends BossBase

# the harrower — a plough with legs. it wants one thing, which is to be where
# you are, at speed. it circles until it has a line, takes the line, and
# shakes the floor when it misses.

const GORE_COLOR: Color = Color(1.0, 0.25, 0.1)
const DUST_COLOR: Color = Color(1.0, 0.7, 0.3)
const RAKE_COLOR: Color = Color(1.0, 0.45, 0.2)


func _setup() -> void:
	title = "the harrower"
	core_radius = 0.55
	attack_cooldown = 2.0
	phase_thresholds = [0.6, 0.3]


func _idle(delta: float, dist: float) -> void:
	# it does not walk in: the charge is how it closes the distance
	_keep_range(delta, dist, 13.0, 16.0)


func _pick_attack(dist: float) -> void:
	var options: Array[StringName] = [&"gore", &"gore", &"rake"]
	if dist < 11.0:
		options.append(&"stomp")
		options.append(&"stomp")
	if phase >= 2:
		options.append(&"stampede")
		options.append(&"stampede")
	if phase >= 3:
		options.append(&"quake")
		options.append(&"quake")
	options.erase(_last_attack)
	match options[randi() % options.size()]:
		&"gore":
			_begin_charge(0.75, 34.0, 0.85, damage(1.2), 3.8, GORE_COLOR)
			_last_attack = &"gore"
		&"rake": _rake()
		&"stomp": _stomp()
		&"stampede": _stampede()
		&"quake": _quake()


## three lanes fanned out in front of it, all at once.
func _rake() -> void:
	var windup: float = 0.85
	_run(&"rake", [
		[0.0, func() -> void:
			_signal_core(RAKE_COLOR, windup)
			var forward: Vector3 = _to_target()
			if forward.length() < 0.01:
				forward = -global_transform.basis.z
			var from: Vector3 = global_position + Vector3(0, 0.1, 0)
			var lanes: int = 3 + (2 if phase >= 3 else 0)
			for i: int in lanes:
				var offset: float = (float(i) - float(lanes - 1) * 0.5) * 0.36
				var dir: Vector3 = forward.rotated(Vector3.UP, offset)
				_line_strike(from, from + dir * 26.0, 2.6, windup, damage(1.0), RAKE_COLOR)],
	], windup + 0.45, false)


## the ground under it, then a ring of debris outward.
func _stomp() -> void:
	var radius: float = 6.5
	_run(&"stomp", [
		[0.0, func() -> void:
			_signal_core(DUST_COLOR, 0.8)
			_warn_circle(global_position, radius, 0.8, DUST_COLOR)],
		[0.8, func() -> void:
			_fx_blast(global_position + Vector3(0, 0.7, 0), radius, DUST_COLOR)
			Game.sfx_at(&"boss_slam", global_position, -1.0)
			Game.shake(9.0, global_position, 32.0)
			_hit_players_in_radius(global_position, radius, damage(1.2), DamageInfo.KIND_MELEE, true)
			_ring_burst(&"bolt", 10 + phase * 2, 12.0, damage(0.5), DUST_COLOR, randf() * TAU, 1.0)],
	], 1.25, false)


## one charge after another, each aimed fresh, and a wave where it ends up.
func _stampede() -> void:
	var count: int = 1 + phase
	var steps: Array = []
	for i: int in count:
		steps.append([0.05 + float(i) * 0.1, func() -> void:
			_begin_charge(0.5, 38.0, 0.6, damage(1.0), 3.6, GORE_COLOR, 0.15)])
	# the clock only runs between charges, so these fire one after another
	steps.append([0.1 + float(count) * 0.1, func() -> void:
		_spawn_wave(global_position, 24.0, 15.0, damage(0.6), DUST_COLOR, 2.0)
		Game.sfx_at(&"boss_shockwave", global_position, -2.0)])
	_run(&"stampede", steps, 0.6 + float(count) * 0.1, false)


## three waves across the whole floor: jump each one.
func _quake() -> void:
	var steps: Array = [[0.0, func() -> void:
		_signal_core(DUST_COLOR, 0.7)
		_warn_circle(global_position, 4.0, 0.7, DUST_COLOR)]]
	for i: int in 3:
		steps.append([0.7 + float(i) * 0.65, func() -> void:
			_spawn_wave(global_position, 30.0, 15.0, damage(0.7), DUST_COLOR, 2.0)
			Game.sfx_at(&"boss_shockwave", global_position, -2.0)
			Game.shake(6.0, global_position, 30.0)])
	_run(&"quake", steps, 2.5, false)
