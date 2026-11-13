extends BossBase

# rift stalker — a duelist. it is fast, it is never where you last shot, and
# every attack is a lane or a circle you have to already be leaving.

const BLADE_COLOR: Color = Color(1.0, 0.3, 0.85)
const MINE_COLOR: Color = Color(0.7, 0.3, 1.0)
const NEEDLE_COLOR: Color = Color(1.0, 0.6, 0.9)


func _setup() -> void:
	title = "rift stalker"
	core_radius = 0.4
	attack_cooldown = 2.0
	phase_thresholds = [0.6, 0.3]


func _idle(delta: float, dist: float) -> void:
	_keep_range(delta, dist, 9.0, 22.0)


func _pick_attack(_dist: float) -> void:
	var options: Array[StringName] = [&"strikes", &"strikes", &"fan", &"mines"]
	if phase >= 2:
		options.append(&"cross")
		options.append(&"cross")
	options.erase(_last_attack)
	match options[randi() % options.size()]:
		&"strikes": _blink_strikes()
		&"fan": _blade_fan()
		&"mines": _rift_mines()
		&"cross": _cross_slash()


func _blink_strikes() -> void:
	var count: int = 2 + phase
	var steps: Array = []
	for i: int in count:
		steps.append([0.05 + float(i) * 0.1, func() -> void: _one_strike()])
	# the clock only runs between charges, so the steps fire one after another
	_run(&"strikes", steps, 0.2 + float(count) * 0.1, false)


func _one_strike() -> void:
	if not is_instance_valid(target):
		return
	var angle: float = randf() * TAU
	var point: Vector3 = target.global_position + Vector3(cos(angle), 0, sin(angle)) * 8.0
	var rooms: RoomController = Game.rooms()
	if rooms:
		point = rooms.clamp_to_arena(point, 1.5)
	_blink_to(point, BLADE_COLOR)
	_begin_charge(0.42, 42.0, 0.34, damage(), 2.6, BLADE_COLOR, 0.12)


func _blade_fan() -> void:
	var steps: Array = [
		[0.0, func() -> void: _signal_core(NEEDLE_COLOR, 0.45)],
		[0.45, func() -> void: _fan(&"needle", 7, 0.9, 32.0, damage(0.5), NEEDLE_COLOR)],
		[0.75, func() -> void: _fan(&"needle", 6, 0.75, 34.0, damage(0.5), NEEDLE_COLOR)],
	]
	if phase >= 3:
		steps.append([1.05, func() -> void: _fan(&"needle", 9, 1.2, 30.0, damage(0.5), NEEDLE_COLOR)])
	_run(&"fan", steps, 1.4)


func _rift_mines() -> void:
	var count: int = 3 + phase
	var steps: Array = [[0.0, func() -> void: _signal_core(MINE_COLOR, 0.4)]]
	for i: int in count:
		steps.append([0.2 + float(i) * 0.22, func() -> void:
			if is_instance_valid(target):
				var at: Vector3 = target.global_position + Vector3(randf_range(-3.5, 3.5), 0, randf_range(-3.5, 3.5))
				at.y = 0.1
				_warned_blast(at, 3.4, 1.0, damage(0.9), MINE_COLOR)])
	_run(&"mines", steps, 0.5 + float(count) * 0.22)


func _cross_slash() -> void:
	if not is_instance_valid(target):
		return
	var centre: Vector3 = target.global_position
	centre.y = 0.1
	var a: float = randf() * TAU
	var windup: float = 0.85
	_run(&"cross", [
		[0.0, func() -> void:
			_signal_core(BLADE_COLOR, windup)
			for k: int in 2:
				var dir: Vector3 = Vector3(cos(a + k * PI * 0.5), 0, sin(a + k * PI * 0.5))
				_line_strike(centre - dir * 18.0, centre + dir * 18.0, 3.2, windup, damage(1.1), BLADE_COLOR)],
		[windup + 0.15, func() -> void:
			if phase >= 3 and is_instance_valid(target):
				# a second, rotated cross on wherever they ran to
				var c2: Vector3 = target.global_position
				c2.y = 0.1
				for k: int in 2:
					var dir: Vector3 = Vector3(cos(a + PI * 0.25 + k * PI * 0.5), 0, sin(a + PI * 0.25 + k * PI * 0.5))
					_line_strike(c2 - dir * 18.0, c2 + dir * 18.0, 3.2, 0.7, damage(1.1), BLADE_COLOR)],
	], windup + 0.5)
