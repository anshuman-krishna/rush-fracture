class_name MutationManager
extends Node

# applies mutations to the local player and runs their ongoing effects.
# stat changes live in the player's StatBlock under "mut:<name>", so they
# compose with upgrades and are removed cleanly on reset.

signal mutation_applied(mutation: Dictionary)

const T: Dictionary = MutationDefinitions.MutationType

var active_mutations: Array[Dictionary] = []

var _player: CharacterBody3D
var _weapon_manager: WeaponManager
var _types: Dictionary = {}
var _drain_timer: float = 0.0
var _in_fracture: bool = false
var _volatile_cooldown: float = 0.0
var _shield_filter: Callable


func bind(player: CharacterBody3D, weapon_manager: WeaponManager) -> void:
	_player = player
	_weapon_manager = weapon_manager
	_shield_filter = _momentum_filter


func has_mutation(type: MutationDefinitions.MutationType) -> bool:
	return _types.has(type)


func get_mutation_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for m: Dictionary in active_mutations:
		names.append(m.get("name", ""))
	return names


func owned_types() -> Array:
	return _types.keys()


func reset() -> void:
	active_mutations.clear()
	_types.clear()
	_drain_timer = 0.0
	_in_fracture = false
	_volatile_cooldown = 0.0
	if is_instance_valid(_player):
		_player.stats.remove_prefix("mut:")
		_player.damage_filters.erase(_shield_filter)


func apply(mutation: Dictionary) -> void:
	if mutation.is_empty() or not is_instance_valid(_player):
		return
	var type: MutationDefinitions.MutationType = mutation.get("type")
	if _types.has(type):
		return
	_types[type] = true
	active_mutations.append(mutation)

	var key: StringName = StringName("mut:%s" % String(mutation.get("name", "")).replace(" ", "_"))
	for mod: Array in mutation.get("mods", []):
		if mod[1] == "mul":
			_player.stats.set_mul(mod[0], key, float(mod[2]))
		else:
			_player.stats.set_add(mod[0], key, float(mod[2]))

	match type:
		T.MOMENTUM_SHIELD:
			if not _player.damage_filters.has(_shield_filter):
				_player.damage_filters.append(_shield_filter)
		T.FRACTURE_ECHO:
			_refresh_echo()

	mutation_applied.emit(mutation)


func _process(delta: float) -> void:
	if not is_instance_valid(_player) or _types.is_empty():
		return
	_volatile_cooldown = maxf(0.0, _volatile_cooldown - delta)
	if _types.has(T.BLOOD_PACT) and not _player.is_dead:
		_drain_timer += delta
		if _drain_timer >= 0.5:
			_drain_timer -= 0.5
			# a steady drain, applied directly so it never triggers hit
			# feedback, and never takes the last point of health
			if _player.health > 1:
				_player.health -= 1


func on_enemy_killed(_enemy: Node3D, _info: DamageInfo) -> void:
	if not is_instance_valid(_player):
		return
	if _types.has(T.BLOOD_PACT):
		_player.heal(8)
	if _types.has(T.TEMPORAL_DISTORTION):
		var feel: GameFeel = Game.feel()
		if feel:
			feel.request(&"distortion", 0.35, 0.5, GameFeel.PRIORITY_EFFECT, 0.12)


func on_enemy_hit(_enemy: Node3D, info: DamageInfo) -> void:
	if not _types.has(T.UNSTABLE_CORE) or not info or not info.can_proc or not is_instance_valid(_player):
		return
	if randf() < 0.2:
		var combat: Combat = Game.combat()
		if combat:
			var radius: float = 4.0 * _player.stats.value(&"blast_radius")
			Vfx.blast(info.position, radius, Color(1.0, 0.4, 0.9), false)
			combat.blast(info.position, radius, 20.0, {"can_proc": false})
	if randf() < 0.1:
		_player.take_damage(5, DamageInfo.make(5, DamageInfo.KIND_SELF, _player))


func on_player_damaged(amount: int, _info: DamageInfo) -> void:
	if amount <= 0 or not _types.has(T.VOLATILE_BLOOD) or _volatile_cooldown > 0.0 or not is_instance_valid(_player):
		return
	_volatile_cooldown = 1.5
	var combat: Combat = Game.combat()
	if combat:
		var radius: float = 5.5 * _player.stats.value(&"blast_radius")
		Vfx.blast(_player.global_position, radius, Color(1.0, 0.2, 0.25))
		Game.sfx(&"explosion_small", -5.0, 0.1)
		combat.blast(_player.global_position, radius, 45.0, {"can_proc": false, "knockback": 10.0})


func on_fracture_started() -> void:
	_in_fracture = true
	_refresh_echo()


func on_fracture_ended() -> void:
	_in_fracture = false
	_refresh_echo()


func _refresh_echo() -> void:
	if not is_instance_valid(_player):
		return
	if not _types.has(T.FRACTURE_ECHO):
		_player.stats.set_mul(&"damage", &"mut:echo", 1.0)
		return
	_player.stats.set_mul(&"damage", &"mut:echo", 1.35 if _in_fracture else 0.8)


func _momentum_filter(_info: DamageInfo) -> float:
	if not is_instance_valid(_player):
		return 1.0
	var speed: float = _player.horizontal_speed()
	if speed > 8.0:
		return 0.6
	if speed < 2.0:
		return 1.4
	return 1.0
