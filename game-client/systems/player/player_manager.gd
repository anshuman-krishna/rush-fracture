class_name PlayerManager
extends Node

# registry of the players in the scene, with the queries other systems need
# (nearest player, the local player's weapon and camera).

signal player_registered(player: CharacterBody3D)
signal player_unregistered(player: CharacterBody3D)

var _players: Array[CharacterBody3D] = []


func register_player(player: CharacterBody3D) -> void:
	if player in _players:
		return
	_players.append(player)
	player_registered.emit(player)


func unregister_player(player: CharacterBody3D) -> void:
	var idx: int = _players.find(player)
	if idx < 0:
		return
	_players.remove_at(idx)
	player_unregistered.emit(player)


## the player this peer controls. in a solo game that is the only player.
func get_primary_player() -> CharacterBody3D:
	for p: CharacterBody3D in _players:
		if not is_instance_valid(p):
			continue
		if not Game.is_online() or p.is_multiplayer_authority():
			return p
	return _players[0] if not _players.is_empty() and is_instance_valid(_players[0]) else null


func get_all_players() -> Array[CharacterBody3D]:
	return _players


func get_player_count() -> int:
	return _players.size()


## players who are still up.
func get_living_players() -> Array[CharacterBody3D]:
	var out: Array[CharacterBody3D] = []
	for p: CharacterBody3D in _players:
		if is_instance_valid(p) and p.get("is_dead") != true:
			out.append(p)
	return out


func get_nearest_player(position: Vector3) -> CharacterBody3D:
	var nearest: CharacterBody3D = null
	var best: float = INF
	for p: CharacterBody3D in _players:
		if not is_instance_valid(p) or p.get("is_dead") == true:
			continue
		var d: float = p.global_position.distance_squared_to(position)
		if d < best:
			best = d
			nearest = p
	return nearest


func get_weapon_manager(player: CharacterBody3D) -> WeaponManager:
	if not is_instance_valid(player):
		return null
	return player.get_node_or_null("Head/WeaponManager") as WeaponManager


func get_primary_weapon_manager() -> WeaponManager:
	return get_weapon_manager(get_primary_player())


func get_primary_camera() -> Camera3D:
	var player: CharacterBody3D = get_primary_player()
	if not is_instance_valid(player):
		return null
	return player.get_node_or_null("Head/Camera3D") as Camera3D


func reset() -> void:
	_players.clear()
