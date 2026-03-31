class_name UpgradeManager
extends Node

# applies upgrades to player and weapon systems.
# tracks accumulated modifiers and special flags.

var kill_heal_amount: int = 0
var has_unstable_rounds: bool = false
var has_chain_reaction: bool = false
var has_adrenaline_surge: bool = false
var has_temporal_break: bool = false
var has_berserker: bool = false
var has_explosive_dash: bool = false
var has_enemy_slow_aura: bool = false
var enemy_speed_bonus: float = 0.0
var damage_taken_multiplier: float = 1.0
var _slow_aura_radius: float = 8.0
var _slow_aura_timer: float = 0.0

var _player: CharacterBody3D
var _weapon_manager: WeaponManager
var _adrenaline_active: bool = false
var _adrenaline_bonus: float = 0.0


func _process(delta: float) -> void:
	if has_enemy_slow_aura and _player:
		_slow_aura_timer -= delta
		if _slow_aura_timer <= 0:
			_slow_aura_timer = 0.5
			_apply_slow_aura()


func bind(player: CharacterBody3D, weapon_manager: WeaponManager) -> void:
	_player = player
	_weapon_manager = weapon_manager


func apply(upgrade: Dictionary) -> void:
	var stat: String = upgrade.get("stat", "")
	var modifier: Variant = upgrade.get("modifier", 0)
	var mode: String = upgrade.get("apply_mode", "add")

	match stat:
		"damage":
			_apply_to(_weapon_manager, stat, modifier, mode)
		"fire_rate":
			_apply_to(_weapon_manager, stat, modifier, mode)
		"max_health":
			_apply_to(_player, stat, modifier, mode)
			_player.health = mini(_player.health + int(modifier), _player.max_health)
		"dash_cooldown":
			_apply_to(_player, stat, modifier, mode)
		"move_speed":
			_apply_to(_player, stat, modifier, mode)
		"air_friction":
			_apply_to(_player, stat, modifier, mode)
		"kill_heal":
			kill_heal_amount += int(modifier)
		"overdrive":
			_apply_overdrive()
		"unstable_rounds":
			has_unstable_rounds = true
		"burst_fire":
			_apply_weapon_flag("PulseRifle", "burst_mode", true)
		"armor_piercing":
			_apply_weapon_flag("PulseRifle", "armor_piercing", true)
		"tight_spread":
			_apply_weapon_flag("ScatterCannon", "tight_spread", true)
		"double_blast":
			_apply_weapon_flag("ScatterCannon", "double_blast", true)
		"beam_chain":
			_apply_weapon_flag("BeamEmitter", "chain_beam", true)
		"heat_capacity":
			_apply_beam_capacity()
		"chain_reaction":
			has_chain_reaction = true
		"adrenaline_surge":
			has_adrenaline_surge = true
		"temporal_break":
			has_temporal_break = true
		"ricochet_rounds":
			_apply_weapon_flag("PulseRifle", "ricochet", true)
		"piercing_beam":
			_apply_weapon_flag("BeamEmitter", "piercing", true)
		"explosive_dash":
			has_explosive_dash = true
		"enemy_slow_aura":
			has_enemy_slow_aura = true
		"power_surge":
			_apply_power_surge()
		"fragile_speed":
			_apply_fragile_speed()
		"berserker_pact":
			_apply_berserker_pact()


func on_enemy_killed() -> void:
	if kill_heal_amount > 0 and _player:
		_player.health = mini(_player.health + kill_heal_amount, _player.max_health)

	if has_chain_reaction and _weapon_manager:
		_trigger_chain_reaction()

	if has_temporal_break:
		_trigger_temporal_break()


func on_enemy_hit(hit_position: Vector3) -> void:
	if has_unstable_rounds and _weapon_manager:
		_apply_aoe_damage(hit_position)


func on_combo_changed(multiplier: int) -> void:
	if has_adrenaline_surge and _player and multiplier >= 2:
		_apply_adrenaline(multiplier)


func on_combo_reset() -> void:
	if _adrenaline_active:
		_revert_adrenaline()


func get_effective_damage(base_damage: int) -> int:
	if has_berserker and _player:
		var hp_ratio: float = float(_player.health) / float(_player.max_health)
		if hp_ratio <= 0.4:
			return int(base_damage * 1.25)
	return base_damage


func on_player_dashed() -> void:
	if has_explosive_dash and _player:
		_trigger_explosive_dash()


func reset() -> void:
	kill_heal_amount = 0
	has_unstable_rounds = false
	has_chain_reaction = false
	has_adrenaline_surge = false
	has_temporal_break = false
	has_berserker = false
	has_explosive_dash = false
	has_enemy_slow_aura = false
	enemy_speed_bonus = 0.0
	damage_taken_multiplier = 1.0
	_adrenaline_active = false
	_adrenaline_bonus = 0.0
	_slow_aura_timer = 0.0


func _apply_overdrive() -> void:
	if _weapon_manager:
		_weapon_manager.fire_rate *= 0.4
		_weapon_manager.shake_on_fire *= 1.2


func _apply_weapon_flag(weapon_name: String, flag: String, value: bool) -> void:
	if not _weapon_manager:
		return
	var weapon: Node = _weapon_manager.get_node_or_null(weapon_name)
	if weapon and flag in weapon:
		weapon.set(flag, value)


func _apply_beam_capacity() -> void:
	if not _weapon_manager:
		return
	var beam: BeamEmitter = _weapon_manager.get_node_or_null("BeamEmitter") as BeamEmitter
	if beam:
		beam.max_heat *= 1.5
		beam.overheat_threshold *= 1.5


func _apply_aoe_damage(position: Vector3) -> void:
	var aoe_radius: float = 3.0
	var aoe_damage: int = int(_weapon_manager.damage * 0.5)
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not enemy is Node3D:
			continue
		if enemy.global_position.distance_to(position) < aoe_radius:
			var health: HealthComponent = enemy.get_node_or_null("HealthComponent") as HealthComponent
			if health and health.is_alive():
				health.take_damage(aoe_damage)


func _trigger_chain_reaction() -> void:
	# explosion at the last killed enemy position is handled via game_manager
	pass


func _trigger_temporal_break() -> void:
	var tree: SceneTree = get_tree()
	Engine.time_scale = 0.3
	tree.create_timer(0.4, true, false, true).timeout.connect(func():
		Engine.time_scale = 1.0
	)


func _apply_adrenaline(multiplier: int) -> void:
	if _adrenaline_active:
		_revert_adrenaline()

	_adrenaline_bonus = 0.1 * (multiplier - 1)
	_player.move_speed *= (1.0 + _adrenaline_bonus)
	_adrenaline_active = true


func _revert_adrenaline() -> void:
	if not _player or _adrenaline_bonus <= 0:
		return
	_player.move_speed /= (1.0 + _adrenaline_bonus)
	_adrenaline_bonus = 0.0
	_adrenaline_active = false


func _apply_power_surge() -> void:
	if _weapon_manager:
		_weapon_manager.damage_multiplier *= 1.4
	enemy_speed_bonus += 0.2


func _apply_fragile_speed() -> void:
	if _player:
		_player.move_speed *= 1.3
	damage_taken_multiplier *= 1.25


func _apply_berserker_pact() -> void:
	has_berserker = true
	if _player:
		_player.max_health = maxi(_player.max_health - 20, 20)
		_player.health = mini(_player.health, _player.max_health)


func _apply_slow_aura() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not enemy is Node3D or not "move_speed" in enemy:
			continue
		var dist: float = enemy.global_position.distance_to(_player.global_position)
		var is_slowed: bool = enemy.get_meta("slow_aura_active", false)
		if dist < _slow_aura_radius and not is_slowed:
			enemy.move_speed *= 0.8
			enemy.set_meta("slow_aura_active", true)
		elif dist >= _slow_aura_radius and is_slowed:
			enemy.move_speed /= 0.8
			enemy.set_meta("slow_aura_active", false)


func _trigger_explosive_dash() -> void:
	var radius: float = 4.0
	var damage: int = 20
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not enemy is Node3D:
			continue
		if enemy.global_position.distance_to(_player.global_position) < radius:
			var h: HealthComponent = enemy.get_node_or_null("HealthComponent") as HealthComponent
			if h and h.is_alive():
				h.take_damage(damage)


static func _apply_to(target: Node, property: String, modifier, mode: String) -> void:
	if not target or not property in target:
		return

	var current: Variant = target.get(property)
	match mode:
		"multiply":
			target.set(property, current * modifier)
		"add":
			target.set(property, current + modifier)
		"set":
			target.set(property, modifier)
