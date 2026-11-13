extends BossBase

# hive matriarch — act two. she fills the floor: acid that lingers, broodlings
# that never stop, and scythes for anyone who thinks close is safe.

const BILE_COLOR: Color = Color(0.6, 1.0, 0.2)
const SCYTHE_COLOR: Color = Color(1.0, 0.3, 0.15)
const LEAP_COLOR: Color = Color(1.0, 0.5, 0.1)
const ORB_COLOR: Color = Color(0.9, 0.4, 1.0)
const MAX_BROOD: int = 12


func _setup() -> void:
	title = "hive matriarch"
	core_radius = 0.6
	attack_cooldown = 2.8
	phase_thresholds = [0.66, 0.33]


func _idle(delta: float, dist: float) -> void:
	if dist > 10.0:
		_chase(delta, 1.0, 7.0)
	else:
		_brake(8.0, delta)
		_face_target(delta, 3.5)


func _pick_attack(dist: float) -> void:
	var options: Array[StringName] = [&"rain", &"rain"]
	if dist < 9.0:
		options.append(&"sweep")
		options.append(&"sweep")
	if _minion_count() < MAX_BROOD:
		options.append(&"hatch")
	if phase >= 2:
		options.append(&"leap")
	options.erase(_last_attack)
	match options[randi() % options.size()]:
		&"rain": _acid_rain()
		&"sweep": _sweep()
		&"hatch": _hatch()
		&"leap": _leap()


func _after_attack() -> void:
	# phase three: every attack is followed by a slow ring to weave through
	if phase >= 3:
		_ring_burst(&"orb", 12, 8.0, damage(0.5), ORB_COLOR, randf() * TAU, 1.4)


func _acid_rain() -> void:
	var count: int = 5 + (phase - 1) * 2
	_run(&"rain", [
		[0.0, func() -> void: _signal_core(BILE_COLOR, 0.55)],
		[0.55, func() -> void: _mortar_rain(count, 8.0, 1.3, damage(0.8), BILE_COLOR, 5.0)],
		[1.1, func() -> void: _after_attack()],
	], 1.5)


func _sweep() -> void:
	var facing: Vector3 = _to_target()
	if facing.length() < 0.1:
		facing = -global_transform.basis.z
	var at: Vector3 = global_position + facing * 4.5
	at.y = 0.1
	var radius: float = 5.8
	_run(&"sweep", [
		[0.0, func() -> void:
			_signal_core(SCYTHE_COLOR, 0.8)
			_warn_circle(at, radius, 0.8, SCYTHE_COLOR)],
		[0.8, func() -> void:
			_fx_ring(at, radius, SCYTHE_COLOR, 0.25)
			Game.sfx_at(&"enemy_swing", at, -1.0, 0.05)
			Game.shake(6.0, at, 26.0)
			_hit_players_in_radius(at, radius, damage(1.2), DamageInfo.KIND_MELEE)],
		[1.1, func() -> void: _after_attack()],
	], 1.4, false)


func _hatch() -> void:
	var count: int = 3 + (phase - 1)
	_run(&"hatch", [
		[0.0, func() -> void: _signal_core(Color(0.4, 1.0, 0.3), 0.7)],
		[0.7, func() -> void: _summon(&"swarmling", count, 6.0)],
		[1.0, func() -> void: _after_attack()],
	], 1.2)


func _leap() -> void:
	if not is_instance_valid(target):
		return
	var at: Vector3 = target.global_position
	at.y = 0.1
	var rooms: RoomController = Game.rooms()
	if rooms:
		at = rooms.clamp_to_arena(at, 3.0)
	var radius: float = 7.0
	_run(&"leap", [
		[0.0, func() -> void:
			_signal_core(LEAP_COLOR, 1.0)
			_warn_circle(at, radius, 1.0, LEAP_COLOR)
			_hop(1.0)],
		[1.0, func() -> void:
			_blink_to(at, LEAP_COLOR)
			_fx_blast(at + Vector3(0, 0.8, 0), radius, LEAP_COLOR)
			Game.sfx_at(&"boss_slam", at, 0.0)
			Game.shake(10.0, at, 34.0)
			_hit_players_in_radius(at, radius, damage(1.4), DamageInfo.KIND_MELEE)
			_spawn_wave(at, 22.0, 15.0, damage(0.7), LEAP_COLOR, radius)],
		[1.5, func() -> void: _after_attack()],
	], 1.9, false)


## lifts the model so the jump reads as a jump, not a teleport.
func _hop(seconds: float) -> void:
	if not model:
		return
	var tw: Tween = create_tween()
	tw.tween_property(model, "position:y", 9.0, seconds * 0.85).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(model, "position:y", 0.0, seconds * 0.15).set_ease(Tween.EASE_IN)
