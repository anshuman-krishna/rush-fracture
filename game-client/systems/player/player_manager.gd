class_name PlayerManager
extends Node

# tracks active players in the game.
# provides queries for systems that need player references.
# supports single player now, multiple players later.

signal player_registered(player: CharacterBody3D)
signal player_unregistered(player: CharacterBody3D)

var _players: Array[CharacterBody3D] = []
var _primary_index: int = 0


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
	if _primary_index >= _players.size():
		_primary_index = maxi(0, _players.size() - 1)
	player_unregistered.emit(player)


func get_primary_player() -> CharacterBody3D:
	if _players.size() == 0:
		return null
	return _players[_primary_index]


func get_all_players() -> Array[CharacterBody3D]:
	return _players


func get_player_count() -> int:
	return _players.size()


func get_nearest_player(position: Vector3) -> CharacterBody3D:
	if _players.size() == 0:
		return null
	if _players.size() == 1:
		return _players[0]

	var nearest: CharacterBody3D = null
	var best_dist: float = INF
	for p: CharacterBody3D in _players:
		var dist: float = p.global_position.distance_squared_to(position)
		if dist < best_dist:
			best_dist = dist
			nearest = p
	return nearest


func get_weapon_manager(player: CharacterBody3D) -> WeaponManager:
	if not player:
		return null
	var head: Node3D = player.get_node_or_null("Head") as Node3D
	if not head:
		return null
	return head.get_node_or_null("WeaponManager") as WeaponManager


func get_primary_weapon_manager() -> WeaponManager:
	return get_weapon_manager(get_primary_player())


func get_primary_camera() -> Camera3D:
	var player: CharacterBody3D = get_primary_player()
	if not player:
		return null
	var head: Node3D = player.get_node_or_null("Head") as Node3D
	if not head:
		return null
	return head.get_node_or_null("Camera3D") as Camera3D


func reset() -> void:
	_players.clear()
	_primary_index = 0
