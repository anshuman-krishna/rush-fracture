extends BossBase

# fracture core — the thing the hive grew around. it never moves. the room
# does: spirals of orbs, lances across the floor, and a pull toward the
# centre that ends in a blast.

const ORB_COLOR: Color = Color(1.0, 0.3, 0.85)
const LANCE_COLOR: Color = Color(0.6, 0.4, 1.0)
const PULL_COLOR: Color = Color(1.0, 0.5, 0.2)
const WAVE_COLOR: Color = Color(0.9, 0.3, 1.0)
const MAX_DRONES: int = 4

var _spin: float = 0.0
var _pull: float = 0.0
var _wave_timer: float = 4.0
var _rings: Array[Node3D] = []


func _setup() -> void:
	title = "fracture core"
	core_radius = 1.1
	attack_cooldown = 2.2
	phase_thresholds = [0.66, 0.33]
	mass = 1000.0


func _build_visual() -> void:
	super._build_visual()
	if model:
		for ring_name: String in ["ring_a", "ring_b", "ring_c"]:
			var ring: Node3D = model.find_child(ring_name, true, false) as Node3D
			if ring:
				_rings.append(ring)


func _tick_visual(delta: float) -> void:
	var rate: float = 0.6 + 0.5 * float(phase - 1)
	for i: int in _rings.size():
		_rings[i].rotate_y(delta * rate * (1.0 if i % 2 == 0 else -1.4))


func _idle(delta: float, _dist: float) -> void:
	_brake(60.0, delta)


func _tick_always(delta: float) -> void:
	super._tick_always(delta)
	if _pull > 0.0:
		_pull -= delta
		var pm: PlayerManager = Game.players()
		if pm:
			for p: CharacterBody3D in pm.get_all_players():
				if is_instance_valid(p) and p.has_method("apply_impulse"):
					var to_core: Vector3 = global_position - p.global_position
					to_core.y = 0.0
					if to_core.length() > 2.0:
						p.apply_impulse(to_core.normalized() * 22.0 * delta)
	# final phase: the floor keeps rippling whatever else is happening
	if phase >= 3 and _transition <= 0.0 and not is_dying:
		_wave_timer -= delta
		if _wave_timer <= 0.0:
			_wave_timer = 4.5
			_spawn_wave(global_position, 30.0, 13.0, damage(0.6), WAVE_COLOR, 2.5)


func _pick_attack(_dist: float) -> void:
	var options: Array[StringName] = [&"spiral", &"rings", &"lances"]
	if phase >= 2:
		options.append(&"implode")
		if _minion_count() < MAX_DRONES:
			options.append(&"drones")
	options.erase(_last_attack)
	match options[randi() % options.size()]:
		&"spiral": _spiral()
		&"rings": _rings_attack()
		&"lances": _lances()
		&"implode": _implode()
		&"drones": _drones()


func _spiral() -> void:
	var arms: int = 2 + phase
	var duration: float = 3.2
	var steps: Array = [[0.0, func() -> void: _signal_core(ORB_COLOR, duration)]]
	var t: float = 0.4
	while t < duration:
		steps.append([t, func() -> void:
			_spin += 0.26
			_ring_burst(&"bolt", arms, 9.5, damage(0.5), ORB_COLOR, _spin, 1.3)])
		t += 0.14
	_run(&"spiral", steps, duration + 0.3, false)


func _rings_attack() -> void:
	var steps: Array = [[0.0, func() -> void: _signal_core(ORB_COLOR, 0.5)]]
	for i: int in 2 + phase:
		steps.append([0.5 + float(i) * 0.55, func() -> void:
			_ring_burst(&"orb", 14, 10.0, damage(0.6), ORB_COLOR, randf() * TAU, 1.3)])
	_run(&"rings", steps, 1.0 + float(2 + phase) * 0.55, false)


func _lances() -> void:
	var count: int = 4 + phase * 2
	var base: float = randf() * TAU
	_run(&"lances", [
		[0.0, func() -> void:
			_signal_core(LANCE_COLOR, 1.0)
			for i: int in count:
				var a: float = base + TAU * float(i) / float(count) + randf_range(-0.12, 0.12)
				var dir: Vector3 = Vector3(cos(a), 0, sin(a))
				var from: Vector3 = Vector3(global_position.x, 0.1, global_position.z) + dir * 1.5
				_line_strike(from, from + dir * 34.0, 2.6, 1.0, damage(1.0), LANCE_COLOR)],
	], 1.4, false)


func _implode() -> void:
	var radius: float = 9.0
	var at: Vector3 = Vector3(global_position.x, 0.1, global_position.z)
	_run(&"implode", [
		[0.0, func() -> void:
			_signal_core(PULL_COLOR, 2.0)
			_pull = 2.0
			_warn_circle(at, radius, 2.0, PULL_COLOR)
			Game.sfx_at(&"heavy_windup", global_position, 0.0)],
		[2.0, func() -> void:
			_fx_blast(at + Vector3(0, 2.0, 0), radius, PULL_COLOR)
			Game.sfx_at(&"explosion", at, 2.0)
			Game.shake(12.0)
			_hit_players_in_radius(at, radius, damage(1.6), DamageInfo.KIND_BLAST)],
	], 2.5, false)


func _drones() -> void:
	_run(&"drones", [
		[0.0, func() -> void: _signal_core(Color(1.0, 0.8, 0.3), 0.6)],
		[0.6, func() -> void:
			var rooms: RoomController = Game.rooms()
			if rooms:
				for i: int in 2:
					var a: float = randf() * TAU
					rooms.spawn_add(&"drone", global_position + Vector3(cos(a) * 6.0, 5.0, sin(a) * 6.0), false)],
	], 1.0, false)
