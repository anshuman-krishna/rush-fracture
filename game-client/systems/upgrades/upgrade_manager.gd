class_name UpgradeManager
extends Node

# applies in-run upgrades to the local player and runs their ongoing effects.
# stat changes go into the player's StatBlock under a key per upgrade
# ("up:<id>"), so resetting a run is just removing that prefix.

signal upgrade_applied(upgrade: Dictionary)
## raised when a cursed upgrade changes how fast enemies should move
signal enemy_speed_bonus_changed(total: float)

const KILL_HEAL_PER_STACK: int = 3
const NULL_FIELD_RADIUS: float = 8.0
const CHAIN_BUDGET: int = 6
const PLATE_REGROW: float = 12.0
const PULSE_COOLDOWN: float = 8.0
const RUSH_TIME: float = 3.0
const LUST_TIME: float = 5.0
const LUST_MAX: int = 10
const STORM_EVERY: int = 6
const THORN_REACH: float = 6.0
const FAMILIAR_INTERVAL: float = 1.1
const FAMILIAR_RANGE: float = 24.0
const FAMILIAR_DAMAGE: float = 16.0
const AFTERBURN_TIME: float = 2.0
const DRUM_EVERY: int = 10

const BURN_COLOR: Color = Color(1.0, 0.5, 0.15)
const STORM_COLOR: Color = Color(0.7, 0.85, 1.0)
const BONE_COLOR: Color = Color(0.95, 0.9, 0.75)
const FAMILIAR_COLOR: Color = Color(0.7, 1.0, 0.35)

## id -> how many times it has been taken this run
var owned: Dictionary = {}
var enemy_speed_bonus: float = 0.0

var _player: CharacterBody3D
var _weapon_manager: WeaponManager
var _specials: Dictionary = {}
var _aura_timer: float = 0.0
var _slide_hits: Dictionary = {}
var _chain_budget: int = CHAIN_BUDGET
var _chain_refill: float = 0.0
var _combo_multiplier: int = 1

var _plates: int = 0
var _plate_timer: float = 0.0
var _rush_timer: float = 0.0
var _lust_stacks: int = 0
var _lust_timer: float = 0.0
var _pulse_cooldown: float = 0.0
var _hit_counter: int = 0
var _familiars: Array[MeshInstance3D] = []
var _familiar_timer: float = 0.0
var _familiar_phase: float = 0.0
var _familiar_turn: int = 0
var _burn_timer: float = 0.0
var _regen: float = 0.0
var _drain: float = 0.0
var _kill_counter: int = 0
var _cascade_armed: bool = false
var _last_word_used: bool = false


func bind(player: CharacterBody3D, weapon_manager: WeaponManager) -> void:
	_player = player
	_weapon_manager = weapon_manager


func has(special: StringName) -> bool:
	return _specials.get(special, 0) > 0


func stacks(id: StringName) -> int:
	return int(owned.get(id, 0))


## bone plates ready to soak a hit, and how many the build has in total.
func plates_ready() -> int:
	return _plates


func plates_max() -> int:
	return int(_specials.get(&"bone_plating", 0))


## 0..1 progress of the plate that is growing back.
func plate_regrow_ratio() -> float:
	return clampf(_plate_timer / PLATE_REGROW, 0.0, 1.0)


func reset() -> void:
	owned.clear()
	_specials.clear()
	enemy_speed_bonus = 0.0
	_slide_hits.clear()
	_combo_multiplier = 1
	_chain_budget = CHAIN_BUDGET
	_plates = 0
	_plate_timer = 0.0
	_rush_timer = 0.0
	_lust_stacks = 0
	_lust_timer = 0.0
	_pulse_cooldown = 0.0
	_hit_counter = 0
	_burn_timer = 0.0
	_regen = 0.0
	_drain = 0.0
	_kill_counter = 0
	_cascade_armed = false
	_last_word_used = false
	for f: MeshInstance3D in _familiars:
		if is_instance_valid(f):
			f.free()
	_familiars.clear()
	if is_instance_valid(_player):
		_player.stats.remove_prefix("up:")
		_player.damage_filters.erase(_incoming_filter)
	var combat: Combat = Game.combat()
	if combat:
		combat.pre_damage_hooks.erase(_target_hook)
	enemy_speed_bonus_changed.emit(0.0)


func apply(upgrade: Dictionary) -> void:
	if upgrade.is_empty() or not is_instance_valid(_player):
		return
	var id: StringName = upgrade.get("id", &"")
	if stacks(id) >= UpgradeDefinitions.max_stacks(upgrade):
		return
	owned[id] = stacks(id) + 1
	var key: StringName = StringName("up:%s" % id)

	for mod: Array in upgrade.get("mods", []):
		if mod[1] == "mul":
			_player.stats.stack_mul(mod[0], key, float(mod[2]))
		else:
			_player.stats.stack_add(mod[0], key, float(mod[2]))

	var flag: Array = upgrade.get("flag", [])
	if flag.size() == 3 and _weapon_manager:
		var value: Variant = flag[2]
		if value is int:
			# numeric flags (extra jumps, extra bounces) add up across stacks
			var weapon: BaseWeapon = _weapon_manager.get_weapon(flag[0])
			value = int(weapon.flag_value(flag[1], 0)) + int(flag[2]) if weapon else int(flag[2])
		_weapon_manager.set_weapon_flag(flag[0], flag[1], value)

	var special: StringName = upgrade.get("special", &"")
	if special != &"":
		_specials[special] = int(_specials.get(special, 0)) + 1
		_on_special_gained(special)

	upgrade_applied.emit(upgrade)


func _on_special_gained(special: StringName) -> void:
	match special:
		&"heal_25":
			_player.heal(25)
		&"heal_40":
			_player.heal(40)
		&"heal_10":
			_player.heal(10)
		&"heal_full":
			_player.heal(_player.max_health)
		&"second_wind":
			_player.lethal_guards += 1
		&"borrowed_time":
			_player.lethal_guards += 2
		&"kinetic_plating":
			_watch_incoming()
		&"bone_plating":
			# a new plate arrives ready
			_plates = mini(_plates + 1, plates_max())
			_watch_incoming()
		&"executioner", &"opening_shot", &"elite_hunter", &"pyromaniac":
			var combat: Combat = Game.combat()
			if combat and not combat.pre_damage_hooks.has(_target_hook):
				combat.pre_damage_hooks.append(_target_hook)
		&"power_surge":
			enemy_speed_bonus += 0.2
			enemy_speed_bonus_changed.emit(enemy_speed_bonus)
		&"brood_familiar":
			_familiars.append(_make_familiar())


func _watch_incoming() -> void:
	if not _player.damage_filters.has(_incoming_filter):
		_player.damage_filters.append(_incoming_filter)


# --- per-frame effects --------------------------------------------------------

func _process(delta: float) -> void:
	if not is_instance_valid(_player) or _specials.is_empty():
		return

	_chain_refill += delta
	if _chain_refill >= 0.25:
		_chain_refill = 0.0
		_chain_budget = CHAIN_BUDGET

	_tick_timers(delta)
	_tick_conditions()

	if has(&"null_field"):
		_aura_timer -= delta
		if _aura_timer <= 0.0:
			_aura_timer = 0.35
			for e: Node3D in Combat.enemies_in_radius(get_tree(), _player.global_position, NULL_FIELD_RADIUS):
				if e.has_method("apply_status"):
					e.apply_status(&"slow", 0.6, 0.25, _player)

	if has(&"razor_slide") and _player.get("is_sliding") == true:
		for key: Variant in _slide_hits.keys():
			_slide_hits[key] -= delta
			if _slide_hits[key] <= 0.0:
				_slide_hits.erase(key)
		var combat: Combat = Game.combat()
		if combat:
			var feet: Vector3 = _player.global_position - Vector3(0, 0.6, 0)
			for e: Node3D in Combat.enemies_in_radius(get_tree(), feet, 1.7):
				var id: int = e.get_instance_id()
				if _slide_hits.has(id):
					continue
				_slide_hits[id] = 0.5
				combat.deal(e, 25.0 + _player.horizontal_speed(), {"kind": DamageInfo.KIND_MELEE, "can_proc": false, "knockback": 5.0})

	if not _familiars.is_empty():
		_tick_familiars(delta)


## buffs and cooldowns that simply run out.
func _tick_timers(delta: float) -> void:
	_pulse_cooldown = maxf(0.0, _pulse_cooldown - delta)

	if _rush_timer > 0.0:
		_rush_timer -= delta
		if _rush_timer <= 0.0:
			_player.stats.set_mul(&"move_speed", &"up:rush", 1.0)
			_player.stats.set_mul(&"fire_rate", &"up:rush", 1.0)

	if _lust_stacks > 0:
		_lust_timer -= delta
		if _lust_timer <= 0.0:
			_lust_stacks = 0
			_player.stats.set_mul(&"fire_rate", &"up:bloodlust", 1.0)

	if _burn_timer > 0.0:
		_burn_timer -= delta
		if _burn_timer <= 0.0:
			_player.stats.set_mul(&"move_speed", &"up:afterburner", 1.0)

	# health that trickles in or out, a whole point at a time
	var regrowth: int = int(_specials.get(&"regrowth", 0))
	if regrowth > 0 and not _player.is_dead:
		_regen += delta * float(regrowth)
		if _regen >= 1.0:
			_player.heal(int(_regen))
			_regen -= floorf(_regen)
	if has(&"hunger") and not _player.is_dead:
		_drain += delta
		if _drain >= 1.0:
			_drain -= 1.0
			if _player.health > 1:
				_player.health -= 1

	if _plates < plates_max():
		_plate_timer += delta
		if _plate_timer >= PLATE_REGROW:
			_plate_timer = 0.0
			_plates += 1
			if _player.is_inside_tree():
				Vfx.ring(_player.global_position, 1.6, BONE_COLOR, 0.3)
				Game.sfx(&"shield_block", -12.0, 0.1)


## damage bonuses that depend on what the player is doing right now.
func _tick_conditions() -> void:
	var stats: StatBlock = _player.stats

	if has(&"momentum_rounds"):
		var over: float = clampf((_player.horizontal_speed() - 8.0) / 14.0, 0.0, 1.0)
		stats.set_mul(&"damage", &"up:momentum", 1.0 + over * 0.35)

	if has(&"berserker_pact"):
		var low: bool = float(_player.health) / float(_player.max_health) <= 0.4
		stats.set_mul(&"damage", &"up:berserker", 1.35 if low else 1.0)

	if has(&"sky_hunter"):
		stats.set_mul(&"damage", &"up:sky", 1.0 if _player.is_on_floor() else 1.25)

	if has(&"full_bloom"):
		stats.set_mul(&"damage", &"up:bloom", 1.2 if _player.health >= _player.max_health else 1.0)

	if has(&"gilded_marrow"):
		var run: RunManager = Game.run()
		var essence: int = run.data.essence if run and run.data else 0
		stats.set_mul(&"damage", &"up:gilded", 1.0 + minf(0.3, floorf(float(essence) / 5.0) * 0.01))


# --- event hooks (wired by game_manager) --------------------------------------

func on_enemy_killed(enemy: Node3D, info: DamageInfo) -> void:
	if not is_instance_valid(_player):
		return
	var heal_stacks: int = int(_specials.get(&"kill_heal", 0))
	if heal_stacks > 0:
		_player.heal(KILL_HEAL_PER_STACK * heal_stacks)

	if has(&"temporal_break"):
		var feel: GameFeel = Game.feel()
		if feel:
			feel.request(&"temporal", 0.35, 0.4, GameFeel.PRIORITY_EFFECT, 0.1)

	if has(&"bloodlust"):
		_lust_stacks = mini(LUST_MAX, _lust_stacks + 1)
		_lust_timer = LUST_TIME
		_player.stats.set_mul(&"fire_rate", &"up:bloodlust", 1.0 + 0.04 * float(_lust_stacks))

	if has(&"predator_reflex"):
		_player.refund_dash(0.5)

	if has(&"combo_feast") and _combo_multiplier >= 3:
		_player.heal(2)

	if has(&"war_drum"):
		_kill_counter += 1
		if _kill_counter >= DRUM_EVERY:
			_kill_counter = 0
			_player.refund_dash(10.0)
			_player.grant_invulnerability(1.5)
			if _player.is_inside_tree():
				Vfx.ring(_player.global_position, 5.0, STORM_COLOR, 0.35)
				Game.sfx(&"shield_block", -6.0, 0.1)

	# the kill that empties a room can take the body out of the scene before
	# this runs, and then it has no position to explode or throw shards from
	var combat: Combat = Game.combat()
	if not combat or not _in_scene(enemy):
		return
	var at: Vector3 = enemy.aim_point() if enemy.has_method("aim_point") else enemy.global_position

	if has(&"chain_reaction") and _chain_budget > 0:
		_chain_budget -= 1
		var radius: float = 4.0 * _player.stats.value(&"blast_radius")
		Vfx.blast(at, radius, Color(1.0, 0.55, 0.15))
		Game.sfx_at(&"explosion_small", at, -6.0, 0.2)
		# these kills can chain again; the per-quarter-second budget is what
		# stops one kill from clearing the room in a single frame
		combat.blast(at, radius, 35.0, {"can_proc": false, "weapon": info.weapon if info else &""})

	var shards: int = int(_specials.get(&"shrapnel", 0))
	if shards > 0 and randf() < 0.35:
		var struck: Array = [enemy]
		for n: int in 3:
			var next: Node3D = Combat.nearest_enemy(get_tree(), at, 9.0, struck)
			if not next:
				break
			struck.append(next)
			var to: Vector3 = next.aim_point() if next.has_method("aim_point") else next.global_position
			Vfx.tracer(at, to, BONE_COLOR, 0.12, 0.02)
			combat.deal(next, 22.0 * float(shards), {
				"position": to, "direction": to - at, "kind": DamageInfo.KIND_PROJECTILE,
				"can_proc": false, "can_crit": false, "knockback": 3.0,
			})


func on_enemy_hit(enemy: Node3D, info: DamageInfo) -> void:
	if not info or not is_instance_valid(_player):
		return
	if info.crit:
		var leech: int = int(_specials.get(&"leech", 0))
		if leech > 0:
			_player.heal(2 * leech)

	# cascade: a crit arms one guaranteed crit; that one does not arm another
	if has(&"crit_cascade") and info.kind != DamageInfo.KIND_DOT:
		if _cascade_armed:
			_cascade_armed = false
			_player.stats.set_add(&"crit_chance", &"up:cascade", 0.0)
		elif info.crit:
			_cascade_armed = true
			_player.stats.set_add(&"crit_chance", &"up:cascade", 1.0)

	var afflict: bool = is_instance_valid(enemy) and enemy.has_method("apply_status")
	if afflict:
		if info.crit and info.kind != DamageInfo.KIND_DOT and has(&"ignition"):
			enemy.apply_status(&"burn", 3.0, 14.0, _player)
		if info.weak and has(&"hunter_mark"):
			enemy.apply_status(&"mark", 4.0, 0.25, _player)
		if info.can_proc and has(&"cryo_rounds") and randf() < 0.25:
			enemy.apply_status(&"slow", 2.0, 0.35, _player)

	if not info.can_proc:
		return
	var combat: Combat = Game.combat()
	if not combat:
		return
	if has(&"unstable_rounds") and randf() < 0.2:
		var radius: float = 3.0 * _player.stats.value(&"blast_radius")
		Vfx.blast(info.position, radius, Color(1.0, 0.7, 0.3), false)
		combat.blast(info.position, radius, 15.0, {"can_proc": false})
	if has(&"storm_caller"):
		_hit_counter += 1
		if _hit_counter >= STORM_EVERY:
			_hit_counter = 0
			_call_storm(combat, enemy)


## lightning from above onto `first`, then on to two more nearby.
func _call_storm(combat: Combat, first: Node3D) -> void:
	if not _in_scene(first):
		return
	var struck: Array = []
	var current: Node3D = first
	var amount: float = 55.0
	var from: Vector3 = (first.aim_point() if first.has_method("aim_point") else first.global_position) + Vector3(0, 10.0, 0)
	for n: int in 3:
		var to: Vector3 = current.aim_point() if current.has_method("aim_point") else current.global_position
		Vfx.lightning(from, to, STORM_COLOR, 0.14, 0.5, 0.03 if n == 0 else 0.016)
		combat.deal(current, amount, {"position": to, "kind": DamageInfo.KIND_BEAM, "can_proc": false, "can_crit": false})
		struck.append(current)
		from = to
		amount *= 0.6
		var next: Node3D = Combat.nearest_enemy(get_tree(), to, 8.0, struck)
		if not next:
			break
		current = next
	Vfx.light(from, STORM_COLOR, 4.0, 0.18, 9.0)
	Game.sfx_at(&"arc_fire", from, -3.0, 0.1)


func on_player_dashed() -> void:
	if not is_instance_valid(_player):
		return
	if has(&"phase_dash"):
		_player.grant_invulnerability(0.45)
	if has(&"afterburner"):
		_burn_timer = AFTERBURN_TIME
		_player.stats.set_mul(&"move_speed", &"up:afterburner", 1.25)
	if has(&"explosive_dash"):
		var combat: Combat = Game.combat()
		if combat:
			var radius: float = 4.5 * _player.stats.value(&"blast_radius")
			Vfx.blast(_player.global_position, radius, Color(1.0, 0.5, 0.2))
			Game.sfx(&"explosion_small", -8.0, 0.15)
			combat.blast(_player.global_position, radius, 30.0, {"can_proc": false, "knockback": 8.0})


func on_player_slammed(at: Vector3, fall_speed: float) -> void:
	if not has(&"impact_slam"):
		return
	var combat: Combat = Game.combat()
	if not combat or not is_instance_valid(_player):
		return
	var radius: float = 5.5 * _player.stats.value(&"blast_radius")
	var amount: float = 45.0 + clampf(fall_speed, 0.0, 40.0)
	Vfx.blast(at + Vector3(0, 0.4, 0), radius, Color(0.6, 0.9, 1.0))
	for e: Node3D in Combat.enemies_in_radius(get_tree(), at, radius):
		if e.has_method("stun"):
			e.stun(1.0)
	combat.blast(at, radius, amount, {"can_proc": false, "knockback": 10.0})


## the player lost health. `info` is null when the hit was reported by
## another peer, which is every enemy hit for a co-op client.
func on_player_damaged(amount: int, info: DamageInfo) -> void:
	if amount <= 0 or not is_instance_valid(_player):
		return
	_plate_timer = 0.0

	if has(&"adrenal_rush"):
		_rush_timer = RUSH_TIME
		_player.stats.set_mul(&"move_speed", &"up:rush", 1.3)
		_player.stats.set_mul(&"fire_rate", &"up:rush", 1.3)

	var combat: Combat = Game.combat()

	if has(&"last_word") and not _last_word_used and _player.health > 0 \
			and float(_player.health) / float(maxi(1, _player.max_health)) <= 0.3:
		_last_word_used = true
		_player.grant_invulnerability(2.0)
		if combat and _player.is_inside_tree():
			Vfx.blast(_player.global_position + Vector3(0, 0.6, 0), 8.0, BURN_COLOR)
			Game.sfx(&"explosion", -3.0, 0.1)
			combat.blast(_player.global_position, 8.0, 80.0, {"can_proc": false, "knockback": 14.0})

	if not combat or (info and info.kind == DamageInfo.KIND_SELF):
		return

	var thorns: int = int(_specials.get(&"thorns", 0))
	if thorns > 0:
		var attacker: Node3D = _attacker_of(info)
		if attacker:
			var at: Vector3 = attacker.aim_point() if attacker.has_method("aim_point") else attacker.global_position
			Vfx.sparks(at, Vector3.UP, BONE_COLOR, 6.0, 90.0)
			combat.deal(attacker, 40.0 * float(thorns), {
				"position": at, "kind": DamageInfo.KIND_MELEE, "can_proc": false, "can_crit": false, "knockback": 9.0,
			})

	if has(&"recoil_pulse") and _pulse_cooldown <= 0.0:
		_pulse_cooldown = PULSE_COOLDOWN
		var centre: Vector3 = _player.global_position
		Vfx.ring(centre, 7.0, STORM_COLOR, 0.35)
		Game.sfx(&"shield_break", -6.0, 0.1)
		for e: Node3D in Combat.enemies_in_radius(get_tree(), centre, 7.0):
			if e.has_method("stun"):
				e.stun(1.2)
		combat.blast(centre, 7.0, 20.0, {"can_proc": false, "knockback": 12.0, "min_ratio": 1.0})


## the enemy behind a hit, if it is close enough to hit back.
func _attacker_of(info: DamageInfo) -> Node3D:
	var from: Vector3 = _player.global_position
	if info == null:
		return Combat.nearest_enemy(get_tree(), from, 4.5)
	var source: Node3D = info.source as Node3D if is_instance_valid(info.source) else null
	if _in_scene(source) and source.is_in_group("enemies") and source.global_position.distance_to(from) <= THORN_REACH:
		return source
	return null


## a new room: the once-per-room effects are ready again.
func on_room_entered() -> void:
	_last_word_used = false


func on_combo_changed(multiplier: int) -> void:
	_combo_multiplier = multiplier
	if has(&"adrenaline_surge") and is_instance_valid(_player):
		_player.stats.set_mul(&"move_speed", &"up:adrenaline", 1.0 + 0.06 * float(maxi(0, multiplier - 1)))


func on_combo_reset() -> void:
	_combo_multiplier = 1
	if is_instance_valid(_player):
		_player.stats.set_mul(&"move_speed", &"up:adrenaline", 1.0)


func _in_scene(node: Node3D) -> bool:
	return is_instance_valid(node) and node.is_inside_tree()


# --- conditional effects ------------------------------------------------------

## scales a hit on the player before it lands. returning 0 soaks it whole.
func _incoming_filter(info: DamageInfo) -> float:
	if not is_instance_valid(_player):
		return 1.0
	var mult: float = 1.0
	if has(&"kinetic_plating") and _player.horizontal_speed() > _player.stats.value(&"move_speed") + 1.0:
		mult = 0.7

	# a plate stops what an enemy does to you, not a fall or your own blast
	var plateable: bool = info == null or not (info.ignore_invulnerable or info.kind == DamageInfo.KIND_SELF)
	if _plates > 0 and plateable:
		_plates -= 1
		_plate_timer = 0.0
		if _player.is_inside_tree():
			Vfx.ring(_player.global_position, 2.4, BONE_COLOR, 0.3)
			Vfx.text(_player.global_position + Vector3(0, 1.2, 0) - _player.global_transform.basis.z * 1.5, "plate", BONE_COLOR)
			Game.sfx(&"shield_block", -3.0, 0.1)
		return 0.0
	return mult


## bonuses that depend on the state of what is being hit.
func _target_hook(target: Node, _info: DamageInfo, amount: float) -> float:
	var hc: HealthComponent = target.get_node_or_null("HealthComponent") as HealthComponent
	if hc:
		if has(&"executioner") and hc.ratio() < 0.3:
			amount *= 1.4
		if has(&"opening_shot") and hc.ratio() >= 0.999:
			amount *= 1.6
	if has(&"elite_hunter") and (target.get("is_elite") == true or target is BossBase):
		amount *= 1.3
	if has(&"pyromaniac") and target.has_method("has_status") and target.has_status(&"burn"):
		amount *= 1.3
	return amount


# --- brood familiar -------------------------------------------------------------

func _make_familiar() -> MeshInstance3D:
	var f: MeshInstance3D = MeshInstance3D.new()
	var ball: SphereMesh = SphereMesh.new()
	ball.radius = 0.07
	ball.height = 0.14
	ball.radial_segments = 10
	ball.rings = 5
	f.mesh = ball
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = FAMILIAR_COLOR
	f.material_override = mat
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.visible = false
	# this manager is a plain node, so the spore's position is a world position
	add_child(f)
	return f


func _tick_familiars(delta: float) -> void:
	var count: int = _familiars.size()
	var active: bool = not _player.is_dead and _player.is_inside_tree()
	_familiar_phase += delta * 2.2
	for i: int in count:
		var f: MeshInstance3D = _familiars[i]
		f.visible = active
		var a: float = _familiar_phase + TAU * float(i) / float(count)
		# small and above eye level: close enough to see when you look up, never a blob across the view
		f.position = _player.global_position + Vector3(cos(a) * 1.0, 1.7 + sin(_familiar_phase * 1.7 + float(i)) * 0.1, sin(a) * 1.0)

	_familiar_timer -= delta
	if _familiar_timer > 0.0 or not active:
		return
	# they take turns, so two spores fire twice as often as one
	_familiar_timer = FAMILIAR_INTERVAL / float(count)
	var combat: Combat = Game.combat()
	if not combat:
		return
	var shooter: MeshInstance3D = _familiars[_familiar_turn % count]
	_familiar_turn += 1
	var target: Node3D = _familiar_target(shooter.position)
	if not target:
		return
	var to: Vector3 = target.aim_point() if target.has_method("aim_point") else target.global_position
	Vfx.tracer(shooter.position, to, FAMILIAR_COLOR, 0.1, 0.02)
	Game.sfx_at(&"spit", shooter.position, -14.0, 0.15)
	combat.deal(target, FAMILIAR_DAMAGE, {
		"position": to, "direction": to - shooter.position, "kind": DamageInfo.KIND_PROJECTILE, "weapon": &"familiar",
	})


## the nearest enemy the spore has a clear line to.
func _familiar_target(from: Vector3) -> Node3D:
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var tried: Array = []
	for n: int in 4:
		var e: Node3D = Combat.nearest_enemy(get_tree(), from, FAMILIAR_RANGE, tried)
		if not e:
			return null
		tried.append(e)
		var hc: HealthComponent = e.get_node_or_null("HealthComponent") as HealthComponent
		if hc and hc.invulnerable:
			continue
		var to: Vector3 = e.aim_point() if e.has_method("aim_point") else e.global_position
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = Layers.WORLD
		query.collide_with_areas = false
		if space.intersect_ray(query).is_empty():
			return e
	return null
