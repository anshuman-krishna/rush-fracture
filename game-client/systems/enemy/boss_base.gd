class_name BossBase
extends EnemyBase

# shared machinery for bosses, on top of the standard enemy body: health
# phases with a short invulnerable transition, a timed attack-sequence runner,
# and a kit of reusable attack pieces (warned blasts, shockwaves, projectile
# fans and rings, mortar rain, charges, summons).
#
# a concrete boss sets its numbers in _setup(), moves in _idle(), and picks
# its next attack in _pick_attack() by calling _run() with a list of timed
# steps. no coroutines: every step is a plain callable fired by the frame
# loop, so a boss dying or changing phase mid-attack just drops the list.

signal phase_changed(phase: int)
signal boss_defeated

var boss_id: StringName = &""
var title: String = ""
var phase: int = 1
## health ratios at which the boss enters phase 2, phase 3, ...
var phase_thresholds: Array[float] = [0.66, 0.33]
var attack_cooldown: float = 2.2
var core_radius: float = 0.6
var core_part: String = "phase_core"
var idle_color: Color = Color(0.62, 1.0, 0.36)

var _cooldown: float = 2.5
var _seq: Array = []
var _seq_clock: float = 0.0
var _seq_end: float = 0.0
var _seq_face: bool = true
var _timers: Array = []
var _transition: float = 0.0
var _charge: Dictionary = {}
var _core: MeshInstance3D
var _core_mat: StandardMaterial3D
var _last_attack: StringName = &""


func _ready() -> void:
	super._ready()
	add_to_group("boss")


func _build_visual() -> void:
	super._build_visual()
	_core = _find_part(core_part)
	if _core:
		var src: Material = _core.get_active_material(0)
		if src is StandardMaterial3D:
			_core_mat = (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			_core.set_surface_override_material(0, _core_mat)
			idle_color = _core_mat.emission


# --- overrides for concrete bosses --------------------------------------------

## override: movement between attacks.
func _idle(delta: float, _dist: float) -> void:
	_brake(10.0, delta)
	_face_target(delta, 4.0)


## override: start the next attack with _run() or _begin_charge().
func _pick_attack(_dist: float) -> void:
	pass


## override: react to entering a new phase (2, 3, ...).
func _on_phase(_new_phase: int) -> void:
	pass


# --- bosses shrug off crowd control --------------------------------------------

func stun(_seconds: float) -> void:
	pass


func apply_knockback(_dir: Vector3, _force: float) -> void:
	pass


func apply_status(id: StringName, seconds: float, power: float, source: Node = null, from_peer: int = 0) -> void:
	if id == &"slow":
		power = minf(power, 0.15)
	super.apply_status(id, seconds, power, source, from_peer)


func is_weak_point(hit_pos: Vector3) -> bool:
	if _core and is_instance_valid(_core):
		return hit_pos.distance_to(_core.global_position) <= core_radius * 1.3 * _base_scale
	return super.is_weak_point(hit_pos)


## fraction of attack cooldown for the current phase: later phases act faster.
func _tempo() -> float:
	return maxf(0.5, 1.0 - 0.18 * float(phase - 1))


# --- frame logic ------------------------------------------------------------------

func _ai(delta: float, dist: float) -> void:
	_check_phase()

	if _transition > 0.0:
		_transition -= delta
		_brake(30.0, delta)
		if _transition <= 0.0 and health:
			health.invulnerable = false
		return

	if not _charge.is_empty():
		_tick_charge(delta)
		return

	if _seq_clock < _seq_end:
		_seq_clock += delta
		_brake(30.0, delta)
		if _seq_face:
			_face_target(delta, 5.0)
		while not _seq.is_empty() and _seq[0][0] <= _seq_clock:
			var step: Array = _seq.pop_front()
			(step[1] as Callable).call()
			if _charge.is_empty() == false or _transition > 0.0:
				break
		return

	_cooldown -= delta
	_idle(delta, dist)
	if _cooldown <= 0.0:
		_cooldown = attack_cooldown * _tempo()
		_pick_attack(dist)


func _tick_always(delta: float) -> void:
	var i: int = 0
	while i < _timers.size():
		_timers[i][0] -= delta
		if _timers[i][0] <= 0.0:
			var cb: Callable = _timers[i][1]
			_timers.remove_at(i)
			cb.call()
		else:
			i += 1


## runs a list of [time, Callable] steps, in order, over `duration` seconds.
## the boss holds still (and by default keeps facing its target) meanwhile.
func _run(attack: StringName, steps: Array, duration: float, face: bool = true) -> void:
	_last_attack = attack
	_seq = steps.duplicate()
	_seq.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_seq_clock = 0.0
	_seq_end = duration
	_seq_face = face


## fires `callback` after `seconds`, independent of whatever the boss does next.
func _later(seconds: float, callback: Callable) -> void:
	_timers.append([seconds, callback])


func _cancel_actions() -> void:
	_seq.clear()
	_seq_end = 0.0
	_seq_clock = 0.0
	_charge.clear()
	_timers.clear()


func _check_phase() -> void:
	if not health or not health.is_alive():
		return
	var ratio: float = health.ratio()
	var changed: bool = false
	while phase - 1 < phase_thresholds.size() and ratio <= phase_thresholds[phase - 1]:
		phase += 1
		changed = true
	if changed:
		_begin_transition()


func _begin_transition() -> void:
	_cancel_actions()
	_transition = 1.1
	health.invulnerable = true
	_cooldown = 1.0
	velocity = Vector3.ZERO
	_fx_ring(global_position, 14.0, idle_color, 0.7)
	_fx_blast(aim_point(), 3.5, idle_color)
	Game.sfx_at(&"boss_phase", global_position, 0.0)
	Game.shake(9.0)
	if _core_mat:
		var tw: Tween = create_tween()
		tw.tween_property(_core_mat, "emission_energy_multiplier", 8.0, 0.15)
		tw.tween_property(_core_mat, "emission_energy_multiplier", 2.2, 0.6)
	phase_changed.emit(phase)
	_on_phase(phase)


## pulses the core's colour as a tell for the attack that is winding up.
func _signal_core(color: Color, seconds: float) -> void:
	if not _core_mat:
		return
	_core_mat.emission = color
	_core_mat.emission_energy_multiplier = 4.5
	_later(seconds, func() -> void:
		if _core_mat:
			_core_mat.emission = idle_color
			_core_mat.emission_energy_multiplier = 2.0
	)


# --- attack kit -------------------------------------------------------------------

## marks a circle, then damages everyone still inside it when the mark fills.
func _warned_blast(centre: Vector3, radius: float, windup: float, amount: int, color: Color, ground_only: bool = false) -> void:
	_warn_circle(centre, radius, windup, color)
	_later(windup, func() -> void:
		_fx_blast(centre + Vector3(0, 0.5, 0), radius, color)
		Game.sfx_at(&"explosion", centre, -3.0, 0.1)
		Game.shake(5.0, centre, 28.0)
		_hit_players_in_radius(centre, radius, amount, DamageInfo.KIND_BLAST, ground_only)
	)


## fan of projectiles centred on the target.
func _fan(kind: StringName, count: int, arc: float, shot_speed: float, amount: int, color: Color, lead: float = 0.3) -> void:
	var pm: ProjectileManager = Game.projectiles()
	if not pm or not is_instance_valid(target):
		return
	var from: Vector3 = _muzzle_position()
	var aim: Vector3 = target.global_position + Vector3(target.velocity.x, 0, target.velocity.z) * lead * (from.distance_to(target.global_position) / maxf(1.0, shot_speed))
	var base: Vector3 = (aim - from).normalized()
	for i: int in count:
		var t: float = 0.0 if count <= 1 else float(i) / float(count - 1) - 0.5
		pm.fire_enemy(kind, from, base.rotated(Vector3.UP, t * arc) * shot_speed, amount, color)
	Game.sfx_at(&"enemy_shot", from, -5.0, 0.1)


## flat ring of projectiles in every direction. `offset` rotates the ring so
## consecutive rings can leave gaps in different places.
func _ring_burst(kind: StringName, count: int, shot_speed: float, amount: int, color: Color, offset: float = 0.0, height: float = 1.2) -> void:
	var pm: ProjectileManager = Game.projectiles()
	if not pm:
		return
	var from: Vector3 = Vector3(global_position.x, global_position.y + height, global_position.z)
	for i: int in count:
		var a: float = TAU * float(i) / float(count) + offset
		pm.fire_enemy(kind, from + Vector3(cos(a), 0, sin(a)) * (body_radius + 0.4), Vector3(cos(a), 0, sin(a)) * shot_speed, amount, color)
	Game.sfx_at(&"enemy_shot", from, -4.0, 0.1)


## lobs mortars onto and around the target.
func _mortar_rain(count: int, scatter: float, flight: float, amount: int, color: Color, pool_seconds: float = 0.0, kind: StringName = &"mortar") -> void:
	var pm: ProjectileManager = Game.projectiles()
	if not pm or not is_instance_valid(target):
		return
	var rooms: RoomController = Game.rooms()
	for i: int in count:
		var land: Vector3 = target.global_position
		if i > 0:
			var a: float = randf() * TAU
			land += Vector3(cos(a), 0, sin(a)) * randf_range(scatter * 0.3, scatter)
		else:
			land += Vector3(target.velocity.x, 0, target.velocity.z) * flight * 0.5
		land.y = 0.1
		if rooms:
			land = rooms.clamp_to_arena(land, 1.0)
		pm.fire_enemy_mortar(_muzzle_position(), land, flight + float(i) * 0.12, amount, color, kind, pool_seconds)
	Game.sfx_at(&"spit", global_position, -3.0, 0.1)


func _summon(type_id: StringName, count: int, spread: float = 4.0) -> void:
	var rooms: RoomController = Game.rooms()
	if not rooms:
		return
	for i: int in count:
		var a: float = randf() * TAU
		var at: Vector3 = global_position + Vector3(cos(a), 0, sin(a)) * (body_radius + randf_range(1.5, spread))
		rooms.spawn_add(type_id, at, false)
	Game.sfx_at(&"spawn", global_position, -5.0, 0.1)


## warns a lane, then rushes down it. anyone the boss touches takes `amount`.
func _begin_charge(windup: float, charge_speed: float, seconds: float, amount: int, width: float, color: Color, recover: float = 0.7) -> void:
	var dir: Vector3 = _to_target()
	if dir.length() < 0.1:
		dir = -global_transform.basis.z
	_charge = {"windup": windup, "time": seconds, "speed": charge_speed, "dir": dir, "damage": amount, "hit": {}, "reach": width * 0.5 + 0.6, "recover": recover}
	_warn_line(global_position, global_position + dir * charge_speed * seconds, width, windup, color)
	_signal_core(color, windup)
	Game.sfx_at(&"heavy_windup", global_position, -3.0, 0.05)


func _tick_charge(delta: float) -> void:
	if _charge.windup > 0.0:
		_charge.windup -= delta
		_brake(40.0, delta)
		_face_dir(_charge.dir, delta, 12.0)
		if _charge.windup <= 0.0:
			Game.sfx_at(&"enemy_dash", global_position, -2.0, 0.05)
		return
	_charge.time -= delta
	velocity.x = _charge.dir.x * _charge.speed
	velocity.z = _charge.dir.z * _charge.speed
	var pm: PlayerManager = Game.players()
	if pm:
		for p: CharacterBody3D in pm.get_all_players():
			if not is_instance_valid(p) or _charge.hit.has(p.get_instance_id()):
				continue
			if _flat_distance(p.global_position) <= _charge.reach + body_radius and absf(p.global_position.y - 0.9 - global_position.y) < body_height:
				_charge.hit[p.get_instance_id()] = true
				_hit_player(p, _charge.damage)
				if p.has_method("apply_impulse"):
					p.apply_impulse(_charge.dir * 12.0 + Vector3(0, 6.0, 0))
	if _charge.time <= 0.0 or is_on_wall():
		if is_on_wall():
			Game.shake(6.0, global_position, 30.0)
			_fx_ring(global_position, 6.0, idle_color, 0.3)
		velocity.x = 0.0
		velocity.z = 0.0
		_recover = _charge.get("recover", 0.7)
		_charge.clear()


## warns a straight lane between two points, then damages everyone inside it.
func _line_strike(from: Vector3, to: Vector3, width: float, windup: float, amount: int, color: Color) -> void:
	_warn_line(from, to, width, windup, color)
	_later(windup, func() -> void:
		Vfx.tracer(from + Vector3(0, 1.0, 0), to + Vector3(0, 1.0, 0), color, 0.3, width * 0.22, width * 0.22)
		Game.sfx_at(&"sniper_fire", from, -2.0, 0.1)
		var pm: PlayerManager = Game.players()
		if not pm:
			return
		for p: CharacterBody3D in pm.get_all_players():
			if not is_instance_valid(p) or p.get("is_dead") == true:
				continue
			var flat: Vector3 = Vector3(p.global_position.x, from.y, p.global_position.z)
			var closest: Vector3 = Geometry3D.get_closest_point_to_segment(flat, from, Vector3(to.x, from.y, to.z))
			if closest.distance_to(flat) <= width * 0.5 + 0.35:
				_hit_player(p, amount, DamageInfo.KIND_BLAST)
	)


## enemies currently alive in the room, to cap how many a boss summons.
func _minion_count() -> int:
	return maxi(0, Combat.living_enemies(get_tree()).size() - 1)


## instantly relocates, with an effect at both ends.
func _blink_to(point: Vector3, color: Color) -> void:
	_fx_ring(global_position, 3.0, color, 0.3)
	global_position = Vector3(point.x, global_position.y, point.z)
	velocity = Vector3.ZERO
	_fx_ring(global_position, 3.0, color, 0.3)
	Game.sfx_at(&"warp", global_position, -4.0, 0.08)


# --- death ------------------------------------------------------------------------

func _on_health_died(info: DamageInfo) -> void:
	if is_dying:
		return
	is_dying = true
	collision_layer = 0
	_cancel_actions()
	boss_defeated.emit()
	Game.sfx_at(&"boss_death", global_position, 0.0)

	if _is_local_authority():
		_on_death(info)
		var rooms: RoomController = Game.rooms()
		if rooms:
			rooms.on_enemy_dropped(self, info)

	# a string of bursts up the body, then it collapses
	var glow: Color = Skins.glow(skin_id)
	for i: int in 6:
		var delay: float = 0.18 * float(i)
		var at: Vector3 = global_position + Vector3(randf_range(-1.0, 1.0) * body_radius, body_height * randf_range(0.2, 0.9), randf_range(-1.0, 1.0) * body_radius)
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			Vfx.blast(at, 2.2, glow)
			Vfx.chunks(at, glow.darkened(0.3), 9.0)
		)
	var tw: Tween = create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(self, "scale", Vector3(_base_scale * 1.2, 0.05, _base_scale * 1.2), 0.5).set_ease(Tween.EASE_IN)
	for g: GeometryInstance3D in _meshes:
		if is_instance_valid(g):
			tw.parallel().tween_property(g, "transparency", 1.0, 0.5)
	tw.tween_callback(queue_free)
