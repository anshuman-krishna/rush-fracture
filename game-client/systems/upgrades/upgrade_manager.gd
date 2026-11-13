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
var _plating_filter: Callable
var _combo_multiplier: int = 1


func bind(player: CharacterBody3D, weapon_manager: WeaponManager) -> void:
	_player = player
	_weapon_manager = weapon_manager
	_plating_filter = _kinetic_filter


func has(special: StringName) -> bool:
	return _specials.get(special, 0) > 0


func stacks(id: StringName) -> int:
	return int(owned.get(id, 0))


func reset() -> void:
	owned.clear()
	_specials.clear()
	enemy_speed_bonus = 0.0
	_slide_hits.clear()
	_combo_multiplier = 1
	_chain_budget = CHAIN_BUDGET
	if is_instance_valid(_player):
		_player.stats.remove_prefix("up:")
		_player.damage_filters.erase(_plating_filter)
	var combat: Combat = Game.combat()
	if combat:
		combat.pre_damage_hooks.erase(_executioner_hook)
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
		&"heal_full":
			_player.heal(_player.max_health)
		&"second_wind":
			_player.lethal_guards += 1
		&"kinetic_plating":
			if not _player.damage_filters.has(_plating_filter):
				_player.damage_filters.append(_plating_filter)
		&"executioner":
			var combat: Combat = Game.combat()
			if combat and not combat.pre_damage_hooks.has(_executioner_hook):
				combat.pre_damage_hooks.append(_executioner_hook)
		&"power_surge":
			enemy_speed_bonus += 0.2
			enemy_speed_bonus_changed.emit(enemy_speed_bonus)


# --- per-frame effects --------------------------------------------------------

func _process(delta: float) -> void:
	if not is_instance_valid(_player) or _specials.is_empty():
		return

	_chain_refill += delta
	if _chain_refill >= 0.25:
		_chain_refill = 0.0
		_chain_budget = CHAIN_BUDGET

	if has(&"momentum_rounds"):
		var over: float = clampf((_player.horizontal_speed() - 8.0) / 14.0, 0.0, 1.0)
		_player.stats.set_mul(&"damage", &"up:momentum", 1.0 + over * 0.35)

	if has(&"berserker_pact"):
		var low: bool = float(_player.health) / float(_player.max_health) <= 0.4
		_player.stats.set_mul(&"damage", &"up:berserker", 1.35 if low else 1.0)

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

	if has(&"chain_reaction") and _chain_budget > 0 and is_instance_valid(enemy):
		_chain_budget -= 1
		var at: Vector3 = enemy.aim_point() if enemy.has_method("aim_point") else enemy.global_position
		var radius: float = 4.0 * _player.stats.value(&"blast_radius")
		Vfx.blast(at, radius, Color(1.0, 0.55, 0.15))
		Game.sfx_at(&"explosion_small", at, -6.0, 0.2)
		var combat: Combat = Game.combat()
		if combat:
			# these kills can chain again; the per-quarter-second budget is what
			# stops one kill from clearing the room in a single frame
			combat.blast(at, radius, 35.0, {"can_proc": false, "weapon": info.weapon if info else &""})


func on_enemy_hit(_enemy: Node3D, info: DamageInfo) -> void:
	if not info or not is_instance_valid(_player):
		return
	if info.crit:
		var leech: int = int(_specials.get(&"leech", 0))
		if leech > 0:
			_player.heal(2 * leech)
	if info.can_proc and has(&"unstable_rounds") and randf() < 0.2:
		var combat: Combat = Game.combat()
		if combat:
			var radius: float = 3.0 * _player.stats.value(&"blast_radius")
			Vfx.blast(info.position, radius, Color(1.0, 0.7, 0.3), false)
			combat.blast(info.position, radius, 15.0, {"can_proc": false})


func on_player_dashed() -> void:
	if not is_instance_valid(_player):
		return
	if has(&"phase_dash"):
		_player.grant_invulnerability(0.45)
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


func on_combo_changed(multiplier: int) -> void:
	_combo_multiplier = multiplier
	if has(&"adrenaline_surge") and is_instance_valid(_player):
		_player.stats.set_mul(&"move_speed", &"up:adrenaline", 1.0 + 0.06 * float(maxi(0, multiplier - 1)))


func on_combo_reset() -> void:
	_combo_multiplier = 1
	if is_instance_valid(_player):
		_player.stats.set_mul(&"move_speed", &"up:adrenaline", 1.0)


# --- conditional effects ------------------------------------------------------

func _kinetic_filter(_info: DamageInfo) -> float:
	if not is_instance_valid(_player):
		return 1.0
	return 0.7 if _player.horizontal_speed() > _player.stats.value(&"move_speed") + 1.0 else 1.0


func _executioner_hook(target: Node, _info: DamageInfo, amount: float) -> float:
	var hc: HealthComponent = target.get_node_or_null("HealthComponent") as HealthComponent
	if hc and hc.ratio() < 0.3:
		return amount * 1.4
	return amount
