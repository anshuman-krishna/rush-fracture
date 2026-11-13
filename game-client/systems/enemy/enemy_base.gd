class_name EnemyBase
extends CharacterBody3D

# shared body for every standard enemy: spawn-in, targeting, movement
# helpers, telegraphed melee, ranged fire, status effects, knockback, elite
# affixes, hit feedback and death.
#
# a concrete enemy overrides _setup() to set its numbers and _ai() to decide
# what to do each frame. origins sit at the feet, so aim_point() and
# is_weak_point() work the same for every type.
#
# only the peer that owns the enemy (the host in multiplayer) runs ai;
# everyone else just sees the replicated transform and health.

const STEER_PROBE: float = 1.6
const STEER_ANGLES: PackedFloat32Array = [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5]
const FALL_DEATH_Y: float = -20.0
const RETARGET_INTERVAL: float = 0.5
const SPAWN_TIME: float = 0.55
const FLASH_TIME: float = 0.07

const AFFIX_COLORS: Dictionary = {
	&"volatile": Color(1.0, 0.45, 0.1),
	&"regenerating": Color(0.3, 1.0, 0.4),
	&"swift": Color(0.3, 0.8, 1.0),
	&"shielded": Color(0.5, 0.6, 1.0),
	&"vampiric": Color(1.0, 0.15, 0.3),
}

# filled in by EnemyTypes.create() from the type table
var type_id: StringName = &""
var display_name: String = ""
var body_radius: float = 0.4
var body_height: float = 1.6
var model_path: String = ""
var essence_value: int = 1
var mass: float = 1.0
## hits above this fraction of body height count as weak-point hits (0 = none)
var weak_ratio: float = 0.72
var flying: bool = false

var stats: StatBlock = StatBlock.new()
var target: CharacterBody3D
var is_dying: bool = false
var is_elite: bool = false
var affix: StringName = &""
var difficulty: float = 1.0
var model: Node3D
var skin_id: StringName = &"default"
## counts toward clearing the room (summoned adds can opt out)
var counts_for_room: bool = true

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _spawn_timer: float = 0.0
var _stun: float = 0.0
var _knock: Vector3 = Vector3.ZERO
var _statuses: Dictionary = {}
var _dot_timer: float = 0.0
var _flash_timer: float = 0.0
var _retarget_timer: float = 0.0
var _melee: Dictionary = {}
var _recover: float = 0.0
var _meshes: Array[GeometryInstance3D] = []
var _sep_timer: float = 0.0
var _base_scale: float = 1.0
var _muzzle: Node3D
var _aura: OmniLight3D

static var _flash_material: StandardMaterial3D

@onready var health: HealthComponent = $HealthComponent


func _ready() -> void:
	add_to_group("enemies")
	# the factory seeds these from the type table before the node enters the tree
	if not stats.has(&"move_speed"):
		stats.set_base(&"move_speed", 4.0)
	if not stats.has(&"damage"):
		stats.set_base(&"damage", 10.0)
	_setup()
	health.died.connect(_on_health_died)
	health.damaged.connect(_on_health_damaged)
	_build_visual()
	_sep_timer = randf() * 0.2
	_retarget_timer = randf() * RETARGET_INTERVAL


## override: set stats and tuning. runs before the visual is built.
func _setup() -> void:
	pass


## override: decide what to do this frame. `dist` is the distance to target.
func _ai(_delta: float, _dist: float) -> void:
	pass


## override: runs on every peer each frame, for purely visual motion.
func _tick_visual(_delta: float) -> void:
	pass


## override: runs every frame on the owning peer, whatever the ai is doing.
func _tick_always(_delta: float) -> void:
	pass


## override: extra behaviour when this enemy dies.
func _on_death(_info: DamageInfo) -> void:
	pass


## override: extra reaction to being hit.
func _on_hurt(_amount: int, _info: DamageInfo) -> void:
	pass


# --- public api -------------------------------------------------------------

func aim_point() -> Vector3:
	if flying:
		return global_position
	return global_position + Vector3(0, body_height * 0.55 * _base_scale, 0)


func is_weak_point(hit_pos: Vector3) -> bool:
	if weak_ratio <= 0.0:
		return false
	if flying:
		return hit_pos.y - global_position.y >= body_height * 0.15
	return hit_pos.y - global_position.y >= body_height * weak_ratio * _base_scale


func speed() -> float:
	return stats.value(&"move_speed")


func damage(mult: float = 1.0) -> int:
	return maxi(1, int(round(stats.value(&"damage") * mult)))


## applies difficulty scaling. call before the node enters the tree.
func scale_for(room_difficulty: float, health_node: HealthComponent) -> void:
	difficulty = room_difficulty
	var d: float = maxf(0.0, room_difficulty - 1.0)
	health_node.max_health = maxi(1, int(health_node.max_health * (1.0 + d * 0.9)))
	stats.set_mul(&"damage", &"difficulty", 1.0 + d * 0.28)
	stats.set_mul(&"move_speed", &"difficulty", 1.0 + d * 0.07)


func make_elite(affix_id: StringName = &"") -> void:
	is_elite = true
	affix = affix_id
	_base_scale = 1.35
	scale = Vector3.ONE * _base_scale
	stats.set_mul(&"damage", &"elite", 1.5)
	stats.set_mul(&"move_speed", &"elite", 1.12)
	essence_value *= 4
	mass *= 2.0
	var hc: HealthComponent = get_node_or_null("HealthComponent") as HealthComponent
	if hc:
		hc.max_health = int(hc.max_health * 2.6)
		hc.current_health = hc.max_health
		match affix_id:
			&"shielded":
				hc.set_shield(int(hc.max_health * 0.45))
			&"swift":
				stats.set_mul(&"move_speed", &"affix", 1.35)


## fades the enemy in over a moment instead of popping into existence.
func begin_spawn(duration: float = SPAWN_TIME) -> void:
	_spawn_timer = duration
	if health:
		health.invulnerable = true
	if model:
		model.scale = Vector3.ONE * 0.15
		var tw: Tween = create_tween()
		tw.tween_property(model, "scale", Vector3.ONE, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	Vfx.ring(global_position, body_radius * 3.5, Skins.glow(skin_id), duration, 0.2, 0.25)


func apply_knockback(dir: Vector3, force: float) -> void:
	if is_dying or not _is_local_authority():
		return
	var d: Vector3 = Vector3(dir.x, 0.0 if not flying else dir.y, dir.z)
	if d.length() < 0.01:
		return
	_knock += d.normalized() * force / maxf(0.3, mass)


func stun(seconds: float) -> void:
	if _is_local_authority():
		_stun = maxf(_stun, seconds / maxf(1.0, mass * 0.6))
		_melee.clear()


## timed effects: &"slow" (power = 0..1 speed loss), &"burn" (power = damage
## per second), &"mark" (power = extra damage taken, 0.25 = +25%).
func apply_status(id: StringName, seconds: float, power: float, source: Node = null) -> void:
	if is_dying:
		return
	if not _is_local_authority():
		_rpc_status.rpc_id(1, String(id), seconds, power)
		return
	var existing: Dictionary = _statuses.get(id, {})
	_statuses[id] = {
		"time": maxf(seconds, existing.get("time", 0.0)),
		"power": maxf(power, existing.get("power", 0.0)),
		"source": source,
	}
	_refresh_status_mods()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_status(id: String, seconds: float, power: float) -> void:
	if _is_local_authority():
		apply_status(StringName(id), clampf(seconds, 0.0, 10.0), clampf(power, 0.0, 200.0), null)


## temporary speed boost from an ally (power 0.25 = +25%). expires on this
## enemy's own clock.
func apply_haste(bonus: float, seconds: float) -> void:
	apply_status(&"haste", seconds, bonus, null)


func has_status(id: StringName) -> bool:
	return _statuses.has(id)


func is_attacking() -> bool:
	return not _melee.is_empty() or _recover > 0.0


# --- frame loop -------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if global_position.y < FALL_DEATH_Y:
		if not is_dying and health and health.is_alive() and _is_local_authority():
			health.kill()
		return

	_tick_flash(delta)
	_tick_visual(delta)
	if is_dying or not _is_local_authority():
		return

	_tick_statuses(delta)
	_tick_affix(delta)
	_tick_always(delta)

	if _spawn_timer > 0.0:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			health.invulnerable = false
		_fall(delta)
		move_and_slide()
		return

	_fall(delta)

	if _stun > 0.0:
		_stun -= delta
		_brake(30.0, delta)
		_finish_move(delta)
		return

	_retarget_timer -= delta
	if _retarget_timer <= 0.0 or not is_instance_valid(target) or target.get("is_dead") == true:
		_retarget_timer = RETARGET_INTERVAL
		_find_target()

	if _recover > 0.0:
		_recover -= delta
		_brake(25.0, delta)
	elif not _melee.is_empty():
		_tick_melee(delta)
	elif is_instance_valid(target):
		_ai(delta, _flat_distance(target.global_position))
	else:
		_brake(20.0, delta)

	_finish_move(delta)


func _finish_move(delta: float) -> void:
	_sep_timer -= delta
	if _sep_timer <= 0.0:
		_sep_timer = 0.15
		_separate()
	if _knock.length() > 0.05:
		velocity.x += _knock.x
		velocity.z += _knock.z
		if flying:
			velocity.y += _knock.y
		_knock = _knock.lerp(Vector3.ZERO, clampf(9.0 * delta, 0.0, 1.0))
	move_and_slide()
	if _knock.length() > 0.05:
		velocity.x -= _knock.x
		velocity.z -= _knock.z
		if flying:
			velocity.y -= _knock.y
	_contain()


func _fall(delta: float) -> void:
	if flying:
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0


# --- movement helpers ---------------------------------------------------------

func _find_target() -> void:
	var pm: PlayerManager = Game.players()
	if not pm:
		target = null
		return
	var best: CharacterBody3D = null
	var best_d: float = INF
	for p: CharacterBody3D in pm.get_all_players():
		if not is_instance_valid(p) or p.get("is_dead") == true:
			continue
		var d: float = p.global_position.distance_squared_to(global_position)
		if d < best_d:
			best_d = d
			best = p
	target = best


## horizontal distance to a point, ignoring height.
func _flat_distance(to_pos: Vector3) -> float:
	return Vector2(to_pos.x - global_position.x, to_pos.z - global_position.z).length()


## flat direction to the target (zero if there is none).
func _to_target() -> Vector3:
	if not is_instance_valid(target):
		return Vector3.ZERO
	var d: Vector3 = target.global_position - global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3.ZERO


func _move(dir: Vector3, move_speed: float, accel: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, dir.x * move_speed, accel * delta)
	velocity.z = move_toward(velocity.z, dir.z * move_speed, accel * delta)


func _brake(decel: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, decel * delta)
	velocity.z = move_toward(velocity.z, 0.0, decel * delta)
	if flying:
		velocity.y = move_toward(velocity.y, 0.0, decel * delta)


## walks toward the target, steering around obstacles, and faces the way it moves.
func _chase(delta: float, speed_mult: float = 1.0, accel: float = 22.0) -> void:
	var dir: Vector3 = _steer(_to_target())
	_move(dir, speed() * speed_mult, accel, delta)
	_face_dir(dir, delta)


## backs away from / circles the target to hold roughly `preferred` range.
func _keep_range(delta: float, dist: float, preferred: float, accel: float = 14.0) -> void:
	var dir: Vector3 = _to_target()
	if dist < preferred * 0.7:
		_move(_steer(-dir), speed(), accel, delta)
	elif dist > preferred * 1.3:
		_move(_steer(dir), speed(), accel, delta)
	else:
		var strafe: Vector3 = dir.cross(Vector3.UP) * (1.0 if get_instance_id() % 2 == 0 else -1.0)
		_move(_steer(strafe), speed() * 0.6, accel * 0.7, delta)
	_face_target(delta)


func _face_target(delta: float, turn_speed: float = 9.0) -> void:
	_face_dir(_to_target(), delta, turn_speed)


func _face_dir(dir: Vector3, delta: float, turn_speed: float = 9.0) -> void:
	if dir.length() < 0.05:
		return
	var yaw: float = atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, yaw, clampf(turn_speed * delta, 0.0, 1.0))


## first clear direction in a widening fan around the desired one. not real
## pathfinding, but enough to stop walkers pinning themselves on a pillar.
func _steer(desired: Vector3) -> Vector3:
	var flat: Vector3 = Vector3(desired.x, 0, desired.z)
	if flat.length() < 0.01 or flying:
		return flat
	flat = flat.normalized()
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = global_position + Vector3(0, 0.5, 0)
	for angle: float in STEER_ANGLES:
		var probe: Vector3 = flat.rotated(Vector3.UP, angle)
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + probe * (STEER_PROBE + body_radius), Layers.WORLD)
		query.exclude = [get_rid()]
		if space.intersect_ray(query).is_empty():
			return probe
	return flat


func _has_line_of_sight(to_pos: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(aim_point(), to_pos, Layers.WORLD)
	query.exclude = [get_rid()]
	return space.intersect_ray(query).is_empty()


## soft push away from neighbours so a pack doesn't collapse into one spot.
func _separate() -> void:
	var push: Vector3 = Vector3.ZERO
	var reach: float = body_radius * 2.4
	for other: Node in get_tree().get_nodes_in_group("enemies"):
		if other == self or not other is Node3D:
			continue
		var d: Vector3 = global_position - (other as Node3D).global_position
		d.y = 0.0
		var gap: float = d.length()
		var min_d: float = reach + (other.get("body_radius") if other.get("body_radius") != null else 0.4)
		if gap < min_d and gap > 0.01:
			push += d / gap * (min_d - gap)
	if push.length() > 0.01:
		velocity.x += clampf(push.x * 3.0, -4.0, 4.0)
		velocity.z += clampf(push.z * 3.0, -4.0, 4.0)


func _contain() -> void:
	var rooms: RoomController = Game.rooms()
	if rooms:
		var fixed: Vector3 = rooms.clamp_to_arena(global_position, body_radius)
		if fixed != global_position:
			global_position = fixed


# --- attacks ------------------------------------------------------------------

## starts a telegraphed melee swing: the enemy plants, flares, then strikes.
## the hit only lands if the target is still within `reach` when it resolves,
## so backing off or dashing through is a real answer.
func _start_melee(windup: float, reach: float, amount: int, lunge: float = 0.0, recover: float = 0.35) -> void:
	_melee = {"time": windup, "total": windup, "reach": reach, "damage": amount, "lunge": lunge, "recover": recover}
	_flare(windup)


func _tick_melee(delta: float) -> void:
	_melee.time -= delta
	_brake(40.0, delta)
	_face_target(delta, 6.0)
	if _melee.time > 0.0:
		return
	var m: Dictionary = _melee
	_melee = {}
	_recover = m.recover
	if not is_instance_valid(target):
		return
	var dir: Vector3 = _to_target()
	if m.lunge > 0.0:
		velocity.x = dir.x * m.lunge
		velocity.z = dir.z * m.lunge
	var reach: float = m.reach * _base_scale + body_radius
	var facing: Vector3 = -global_transform.basis.z
	var height_gap: float = absf(target.global_position.y - 0.9 - global_position.y)
	if _flat_distance(target.global_position) <= reach + 0.6 and height_gap < 2.4 and facing.dot(dir) > 0.2:
		_hit_player(target, m.damage, DamageInfo.KIND_MELEE)
		Vfx.sparks(target.global_position, -dir, Color(1.0, 0.3, 0.2), 6.0, 60.0)
	Game.sfx_at(&"enemy_swing", global_position, -10.0, 0.15)


func _hit_player(player: CharacterBody3D, amount: int, kind: StringName = DamageInfo.KIND_MELEE) -> void:
	if not is_instance_valid(player) or not player.has_method("take_damage"):
		return
	var info: DamageInfo = DamageInfo.make(amount, kind, self)
	info.position = player.global_position
	info.direction = _to_target()
	player.take_damage(amount, info)
	if affix == &"vampiric" and health:
		health.heal(int(health.max_health * 0.08))


## damages every player within `radius` of `centre` (host decides, owners apply).
func _hit_players_in_radius(centre: Vector3, radius: float, amount: int, kind: StringName = DamageInfo.KIND_BLAST,
		ignore_airborne: bool = false) -> int:
	var hits: int = 0
	var pm: PlayerManager = Game.players()
	if not pm:
		return 0
	for p: CharacterBody3D in pm.get_all_players():
		if not is_instance_valid(p) or p.get("is_dead") == true:
			continue
		if Vector2(p.global_position.x - centre.x, p.global_position.z - centre.z).length() > radius + 0.4:
			continue
		if ignore_airborne and not p.is_on_floor():
			continue
		_hit_player(p, amount, kind)
		hits += 1
	return hits


func _muzzle_position() -> Vector3:
	if _muzzle and is_instance_valid(_muzzle):
		return _muzzle.global_position
	return global_position + Vector3(0, body_height * 0.7 * _base_scale, 0) - global_transform.basis.z * (body_radius + 0.2)


## fires a dodgeable projectile at the target. `lead` (0..1) aims ahead of a
## moving target; `spread` is random error in radians.
func _shoot(kind: StringName, shot_speed: float, amount: int, color: Color, lead: float = 0.0, spread: float = 0.0) -> void:
	var pm: ProjectileManager = Game.projectiles()
	if not pm or not is_instance_valid(target):
		return
	var from: Vector3 = _muzzle_position()
	var aim: Vector3 = target.global_position
	if lead > 0.0:
		var t: float = from.distance_to(aim) / maxf(1.0, shot_speed)
		aim += Vector3(target.velocity.x, 0, target.velocity.z) * t * lead
	var dir: Vector3 = (aim - from).normalized()
	if spread > 0.0:
		dir = dir.rotated(Vector3.UP, randf_range(-spread, spread)).rotated(dir.cross(Vector3.UP).normalized(), randf_range(-spread, spread) * 0.5)
	pm.fire_enemy(kind, from, dir * shot_speed, amount, color)
	Game.sfx_at(&"enemy_shot", from, -9.0, 0.15)


## brightens the glow parts for `seconds`: the universal "about to attack" tell.
func _flare(seconds: float) -> void:
	if not model:
		return
	var tw: Tween = create_tween()
	tw.tween_property(model, "scale", Vector3.ONE * 1.12, seconds * 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(model, "scale", Vector3.ONE, seconds * 0.4).set_ease(Tween.EASE_IN)
	Vfx.light(aim_point(), Color(1.0, 0.3, 0.15), 2.5, seconds, 4.0)


# --- replicated warnings ------------------------------------------------------
# attack warnings have to be visible to every player, not just the host that
# decided on the attack, so they go through the room's replicated effect call.

func _warn_circle(centre: Vector3, radius: float, seconds: float, color: Color = Color(1.0, 0.25, 0.1)) -> void:
	_net_fx(&"circle", centre, Vector3.ZERO, radius, seconds, color)


func _warn_line(from: Vector3, to: Vector3, width: float, seconds: float, color: Color = Color(1.0, 0.25, 0.1)) -> void:
	_net_fx(&"line", from, to, width, seconds, color)


func _fx_blast(centre: Vector3, radius: float, color: Color) -> void:
	_net_fx(&"blast", centre, Vector3.ZERO, radius, 0.0, color)


func _fx_ring(centre: Vector3, radius: float, color: Color, seconds: float = 0.4) -> void:
	_net_fx(&"ring", centre, Vector3.ZERO, radius, seconds, color)


## travelling ring of force; see Shockwave.
func _spawn_wave(centre: Vector3, max_radius: float, wave_speed: float, amount: int, color: Color,
		start_radius: float = 1.0, jumpable: bool = true) -> void:
	_net_fx(&"wave", centre, Vector3(float(amount), 1.0 if jumpable else 0.0, start_radius), max_radius, wave_speed, color)


func _net_fx(kind: StringName, a: Vector3, b: Vector3, f1: float, f2: float, color: Color) -> void:
	var rooms: RoomController = Game.rooms()
	if rooms:
		rooms.net_fx(kind, a, b, f1, f2, color)


# --- status effects -----------------------------------------------------------

func _tick_statuses(delta: float) -> void:
	if _statuses.is_empty():
		return
	var changed: bool = false
	for id: Variant in _statuses.keys():
		_statuses[id].time -= delta
		if _statuses[id].time <= 0.0:
			_statuses.erase(id)
			changed = true
	if changed:
		_refresh_status_mods()

	if _statuses.has(&"burn"):
		_dot_timer -= delta
		if _dot_timer <= 0.0:
			_dot_timer = 0.5
			var burn: Dictionary = _statuses[&"burn"]
			var amount: float = burn.power * 0.5
			var combat: Combat = Game.combat()
			if combat and is_instance_valid(burn.source) and burn.source == combat.player:
				combat.deal(self, amount, {"kind": DamageInfo.KIND_DOT, "can_crit": false, "can_proc": false, "position": aim_point()})
			elif health:
				health.take_damage(maxi(1, int(amount)), DamageInfo.make(int(amount), DamageInfo.KIND_DOT))
			Vfx.sparks(aim_point(), Vector3.UP, Color(1.0, 0.5, 0.1), 2.5, 60.0)


func _refresh_status_mods() -> void:
	var slow: float = _statuses.get(&"slow", {}).get("power", 0.0)
	stats.set_mul(&"move_speed", &"slow", clampf(1.0 - slow, 0.2, 1.0))
	stats.set_mul(&"move_speed", &"haste", 1.0 + _statuses.get(&"haste", {}).get("power", 0.0))
	if health:
		health.damage_scale = 1.0 + _statuses.get(&"mark", {}).get("power", 0.0)


func _tick_affix(delta: float) -> void:
	if affix != &"regenerating" or not health or not health.is_alive():
		return
	if Time.get_ticks_msec() - health.last_damage_msec > 2500:
		health.heal(maxi(1, int(health.max_health * 0.06 * delta)))


# --- damage and death ---------------------------------------------------------

func _on_health_damaged(amount: int, _current: int, info: DamageInfo) -> void:
	_flash_timer = FLASH_TIME
	for g: GeometryInstance3D in _meshes:
		if is_instance_valid(g):
			g.material_overlay = _get_flash_material()
	_on_hurt(amount, info)


func _tick_flash(delta: float) -> void:
	if _flash_timer <= 0.0:
		return
	_flash_timer -= delta
	if _flash_timer <= 0.0:
		for g: GeometryInstance3D in _meshes:
			if is_instance_valid(g):
				g.material_overlay = null


func _on_health_died(info: DamageInfo) -> void:
	if is_dying:
		return
	is_dying = true
	collision_layer = 0
	collision_mask = Layers.WORLD
	_melee.clear()
	if _aura:
		_aura.visible = false

	var glow: Color = Skins.glow(skin_id)
	Vfx.chunks(aim_point(), glow.darkened(0.2), 5.0 + body_radius * 4.0)
	Vfx.sparks(aim_point(), Vector3.UP, glow, 6.0, 120.0)
	Game.sfx_at(&"enemy_death", global_position, -6.0, 0.2)

	if _is_local_authority():
		if affix == &"volatile":
			_volatile_burst()
		_on_death(info)
		var rooms: RoomController = Game.rooms()
		if rooms:
			rooms.on_enemy_dropped(self, info)

	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector3(_base_scale * 1.3, 0.08, _base_scale * 1.3), 0.16)
	for g: GeometryInstance3D in _meshes:
		if is_instance_valid(g):
			tw.tween_property(g, "transparency", 1.0, 0.2)
	if _is_local_authority():
		tw.chain().tween_callback(queue_free)
	else:
		# a client may have got here first, by predicting its own kill. the
		# host keeps sending this enemy's state until it agrees, so stay around
		# unseen for a moment to receive it.
		tw.chain().tween_callback(hide)
		tw.chain().tween_interval(1.5)
		tw.chain().tween_callback(queue_free)


func _volatile_burst() -> void:
	var at: Vector3 = global_position
	var radius: float = 4.2
	_warn_circle(at, radius, 0.7, AFFIX_COLORS[&"volatile"])
	var amount: int = damage(1.4)
	# the timer belongs to the tree, not this node, because this node is about
	# to be freed; it only captures plain values
	var tree: SceneTree = get_tree()
	tree.create_timer(0.7).timeout.connect(func() -> void:
		Vfx.blast(at + Vector3(0, 0.6, 0), radius, Color(1.0, 0.45, 0.1))
		Game.sfx_at(&"explosion", at, -3.0, 0.1)
		var pm: PlayerManager = Game.players()
		if pm:
			for p: CharacterBody3D in pm.get_all_players():
				if is_instance_valid(p) and p.global_position.distance_to(at) <= radius + 0.5:
					p.take_damage(amount, DamageInfo.make(amount, DamageInfo.KIND_BLAST))
	)


# --- visuals --------------------------------------------------------------------

func _build_visual() -> void:
	if model_path.is_empty() or not ResourceLoader.exists(model_path):
		return
	var scene: PackedScene = load(model_path) as PackedScene
	if not scene:
		return
	model = scene.instantiate() as Node3D
	add_child(model)
	Skins.apply(model, &"strain_elite" if is_elite and skin_id == &"default" else skin_id)
	_collect_meshes(model)
	_muzzle = model.find_child("anchor_muzzle", true, false) as Node3D
	if is_elite:
		_build_aura()


func set_skin(id: StringName) -> void:
	skin_id = id
	if model:
		Skins.apply(model, id)


func _build_aura() -> void:
	_aura = OmniLight3D.new()
	_aura.light_color = AFFIX_COLORS.get(affix, Color(1.0, 0.4, 0.1))
	_aura.light_energy = 2.2
	_aura.omni_range = 5.0
	_aura.shadow_enabled = false
	_aura.position.y = body_height * 0.6
	add_child(_aura)


func _collect_meshes(root: Node) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is GeometryInstance3D:
			_meshes.append(n as GeometryInstance3D)
		for child: Node in n.get_children():
			stack.append(child)


## first mesh under the model with this node name (models keep their part names).
func _find_part(part_name: String) -> MeshInstance3D:
	if not model:
		return null
	return model.find_child(part_name, true, false) as MeshInstance3D


static func _get_flash_material() -> StandardMaterial3D:
	if not _flash_material:
		_flash_material = StandardMaterial3D.new()
		_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_flash_material.albedo_color = Color(0.32, 0.32, 0.32)
	return _flash_material


func _is_local_authority() -> bool:
	if not Game.is_online():
		return true
	return is_multiplayer_authority()
