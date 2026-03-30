class_name BaseWeapon
extends Node3D

# base class for all weapons. defines the shared interface
# that weapon_manager relies on for type-safe access.

signal enemy_killed
signal enemy_hit(position: Vector3)
signal player_hit(target: CharacterBody3D, damage: int)

var base_damage: int = 0
var base_fire_rate: float = 0.0
var shake_on_fire: float = 0.0

# pvp combat reference — set by game_manager when pvp is active
var pvp_manager: Node = null


func try_fire(_effective_damage: int, _effective_fire_rate: float) -> bool:
	return false


func get_weapon_name() -> String:
	return ""


func _get_collision_mask() -> int:
	# layer 2 = enemies, layer 1 = players
	if pvp_manager and pvp_manager.is_active():
		return 3
	return 2


func _handle_hit(collider: Object, hit_pos: Vector3, damage: int) -> void:
	if not collider is CharacterBody3D:
		return

	var body: CharacterBody3D = collider as CharacterBody3D

	# pvp: check if target is another player
	if pvp_manager and pvp_manager.is_active() and body.is_in_group("player"):
		var owner_player: CharacterBody3D = _get_owner_player()
		if owner_player and owner_player != body:
			pvp_manager.try_pvp_damage(owner_player, body, damage)
			player_hit.emit(body, damage)
		return

	# pve: standard enemy damage
	var health: HealthComponent = body.get_node_or_null("HealthComponent") as HealthComponent
	if health:
		var was_alive: bool = health.is_alive()
		health.take_damage(damage)
		enemy_hit.emit(hit_pos)
		if was_alive and not health.is_alive():
			enemy_killed.emit()


func _get_owner_player() -> CharacterBody3D:
	# weapon → head → player
	var player: CharacterBody3D = get_parent().get_parent() as CharacterBody3D
	return player


func _get_owner_exclude() -> Array[RID]:
	var player: CharacterBody3D = _get_owner_player()
	if player:
		return [player.get_rid()]
	return []
