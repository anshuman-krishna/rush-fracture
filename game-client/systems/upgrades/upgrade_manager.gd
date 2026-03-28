class_name UpgradeManager
extends Node

# applies upgrades to player and weapon without coupling to their internals.
# tracks accumulated modifiers so they can be queried or replayed.

var kill_heal_amount := 0
var has_unstable_rounds := false
var _player: CharacterBody3D
var _weapon: Node3D


func bind(player: CharacterBody3D, weapon: Node3D) -> void:
	_player = player
	_weapon = weapon


func apply(upgrade: Dictionary) -> void:
	var stat: String = upgrade.get("stat", "")
	var modifier = upgrade.get("modifier", 0)
	var mode: String = upgrade.get("apply_mode", "add")

	match stat:
		"damage":
			_apply_to(_weapon, stat, modifier, mode)
		"fire_rate":
			_apply_to(_weapon, stat, modifier, mode)
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


func on_enemy_killed() -> void:
	if kill_heal_amount > 0 and _player:
		_player.health = mini(_player.health + kill_heal_amount, _player.max_health)


func on_enemy_hit(hit_position: Vector3) -> void:
	if has_unstable_rounds and _weapon:
		_apply_aoe_damage(hit_position)


func reset() -> void:
	kill_heal_amount = 0
	has_unstable_rounds = false


func _apply_overdrive() -> void:
	if _weapon:
		_weapon.fire_rate *= 0.4
		_weapon.shake_on_fire *= 1.2


func _apply_aoe_damage(position: Vector3) -> void:
	var aoe_radius := 3.0
	var aoe_damage := int(_weapon.damage * 0.5)
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not enemy is Node3D:
			continue
		if enemy.global_position.distance_to(position) < aoe_radius:
			var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
			if health and health.is_alive():
				health.take_damage(aoe_damage)


static func _apply_to(target: Node, property: String, modifier, mode: String) -> void:
	if not target or not property in target:
		return

	var current = target.get(property)
	match mode:
		"multiply":
			target.set(property, current * modifier)
		"add":
			target.set(property, current + modifier)
		"set":
			target.set(property, modifier)
