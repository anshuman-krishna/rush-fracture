extends BossBase

# the choir — three mouths on one stem. it keeps its distance and fills the
# room with patterns: rings to thread, a line of blasts walking toward you,
# spokes that leave only the gaps between them.

const SONG_COLOR: Color = Color(1.0, 0.85, 0.4)
const VERSE_COLOR: Color = Color(1.0, 0.45, 0.75)
const HUSH_COLOR: Color = Color(0.6, 0.8, 1.0)
const MAX_MINIONS: int = 5

var _turn: float = 0.0


func _setup() -> void:
	title = "the choir"
	core_radius = 0.6
	attack_cooldown = 2.3
	phase_thresholds = [0.66, 0.33]


func _idle(delta: float, dist: float) -> void:
	_keep_range(delta, dist, 16.0, 9.0)


func _pick_attack(_dist: float) -> void:
	var options: Array[StringName] = [&"chorus", &"chorus", &"verse", &"refrain"]
	if phase >= 2 and _minion_count() < MAX_MINIONS:
		options.append(&"call")
	if phase >= 3:
		options.append(&"crescendo")
		options.append(&"crescendo")
	options.erase(_last_attack)
	match options[randi() % options.size()]:
		&"chorus": _chorus()
		&"verse": _verse()
		&"refrain": _refrain()
		&"call": _call()
		&"crescendo": _crescendo()


## rings of shots, each turned a little from the last so the gaps move.
func _chorus() -> void:
	var rings: int = 2 + phase
	var count: int = 10 + phase * 2
	var steps: Array = [[0.0, func() -> void: _signal_core(SONG_COLOR, 0.5)]]
	for i: int in rings:
		steps.append([0.5 + float(i) * 0.45, func() -> void:
			_turn += 0.31
			_ring_burst(&"orb", count, 11.0, damage(0.5), SONG_COLOR, _turn, 1.3)
			Game.sfx_at(&"enemy_shot", global_position, -4.0, 0.1)])
	_run(&"chorus", steps, 0.8 + float(rings) * 0.45)


## a row of blasts that walks from the choir to wherever you are standing.
func _verse() -> void:
	if not is_instance_valid(target):
		return
	var from: Vector3 = global_position
	var to: Vector3 = target.global_position
	var steps: Array = [[0.0, func() -> void: _signal_core(VERSE_COLOR, 0.4)]]
	var count: int = 5 + phase
	for i: int in count:
		var t: float = float(i + 1) / float(count)
		steps.append([0.3 + float(i) * 0.16, func() -> void:
			# past the target by the end: backing straight up does not save you
			var at: Vector3 = from.lerp(to, t * 1.25)
			at.y = 0.1
			var rooms: RoomController = Game.rooms()
			if rooms:
				at = rooms.clamp_to_arena(at, 1.5)
			_warned_blast(at, 3.4, 0.95, damage(0.9), VERSE_COLOR)])
	_run(&"verse", steps, 0.6 + float(count) * 0.16)


## spokes out from the choir. later, a second set between the first.
func _refrain() -> void:
	var windup: float = 0.9
	var base: float = randf() * TAU
	var centre: Vector3 = global_position + Vector3(0, 0.1, 0)
	var spokes: int = 4 + (phase - 1)
	var steps: Array = [[0.0, func() -> void:
		_signal_core(HUSH_COLOR, windup)
		for k: int in spokes:
			var dir: Vector3 = Vector3(cos(base + TAU * float(k) / float(spokes)), 0, sin(base + TAU * float(k) / float(spokes)))
			_line_strike(centre + dir * 2.0, centre + dir * 30.0, 2.8, windup, damage(1.0), HUSH_COLOR)]]
	if phase >= 2:
		steps.append([windup * 0.6, func() -> void:
			for k: int in spokes:
				var a: float = base + TAU * (float(k) + 0.5) / float(spokes)
				var dir: Vector3 = Vector3(cos(a), 0, sin(a))
				_line_strike(centre + dir * 2.0, centre + dir * 30.0, 2.8, windup, damage(1.0), HUSH_COLOR)])
	_run(&"refrain", steps, windup * 1.6 + 0.4, false)


func _call() -> void:
	_run(&"call", [
		[0.0, func() -> void: _signal_core(Color(0.4, 1.0, 0.3), 0.7)],
		[0.7, func() -> void: _summon(&"drone", 2 if phase == 2 else 3, 7.0)],
	], 1.1)


## everything at once: mortars on you while the rings go out.
func _crescendo() -> void:
	var steps: Array = [
		[0.0, func() -> void: _signal_core(VERSE_COLOR, 0.6)],
		[0.6, func() -> void: _mortar_rain(5, 8.0, 1.5, damage(0.9), VERSE_COLOR)],
	]
	for i: int in 3:
		steps.append([0.9 + float(i) * 0.5, func() -> void:
			_turn += 0.4
			_ring_burst(&"bolt", 16, 12.5, damage(0.45), SONG_COLOR, _turn, 1.3)])
	_run(&"crescendo", steps, 2.6)
