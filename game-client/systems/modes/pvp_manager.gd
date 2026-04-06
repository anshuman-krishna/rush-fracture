class_name PvPManager
extends Node

# handles player-vs-player combat during pvp encounters.
# manages damage authority, hit detection, and match state.

signal player_eliminated(peer_id: int)
signal match_over(winner_peer_id: int)

var _game_mode: GameModeManager
var _player_manager: PlayerManager
var _network_manager: NetworkManager
var _active: bool = false
var _eliminated: Dictionary = {}  # peer_id -> true
var _pvp_health: Dictionary = {}  # peer_id -> current health
var _pvp_max_health: int = 200  # pvp health pool (separate from pve)


func setup(game_mode: GameModeManager, player_manager: PlayerManager, network_manager: NetworkManager) -> void:
	_game_mode = game_mode
	_player_manager = player_manager
	_network_manager = network_manager


func start_pvp() -> void:
	_active = true
	_eliminated.clear()
	_pvp_health.clear()

	# set pvp health for all players
	var players: Array[CharacterBody3D] = _player_manager.get_all_players()
	for p in players:
		if p is CharacterBody3D:
			var peer_id: int = _get_peer_id(p)
			_pvp_health[peer_id] = _pvp_max_health
			# reset player to full health for the encounter
			p.health = p.max_health


func stop_pvp() -> void:
	_active = false


func is_active() -> bool:
	return _active


func try_pvp_damage(attacker: CharacterBody3D, target: CharacterBody3D, base_damage: int) -> bool:
	if not _active:
		return false

	if not target.is_in_group("player"):
		return false

	var attacker_peer: int = _get_peer_id(attacker)
	var target_peer: int = _get_peer_id(target)

	# can't damage yourself
	if attacker_peer == target_peer:
		return false

	# can't damage eliminated players
	if target_peer in _eliminated:
		return false

	var scaled_damage: int = _game_mode.get_pvp_damage(base_damage)
	_apply_pvp_damage(target_peer, scaled_damage, attacker_peer)

	return true


func _apply_pvp_damage(target_peer: int, damage: int, attacker_peer: int) -> void:
	_pvp_health[target_peer] = maxi(_pvp_health.get(target_peer, 0) - damage, 0)
	_game_mode.register_damage_dealt(attacker_peer, damage)

	# apply visual damage to the actual player (fraction of pvp damage)
	var target_player: CharacterBody3D = _find_player_by_peer(target_peer)
	if target_player and target_player.has_method("take_damage"):
		target_player.take_damage(ceili(damage / 3))

	if _pvp_health[target_peer] <= 0:
		_on_player_eliminated(target_peer, attacker_peer)


func _on_player_eliminated(eliminated_peer: int, killer_peer: int) -> void:
	_eliminated[eliminated_peer] = true
	_game_mode.register_pvp_kill(killer_peer)
	player_eliminated.emit(eliminated_peer)

	# check if match is over (only one player standing)
	var alive_peers: Array[int] = []
	for peer_id: int in _pvp_health:
		if peer_id not in _eliminated:
			alive_peers.append(peer_id)

	if alive_peers.size() <= 1:
		var winner: int = alive_peers[0] if alive_peers.size() > 0 else killer_peer
		match_over.emit(winner)


func get_pvp_health(peer_id: int) -> int:
	return _pvp_health.get(peer_id, 0)


func get_pvp_max_health() -> int:
	return _pvp_max_health


func _find_player_by_peer(peer_id: int) -> CharacterBody3D:
	var players: Array[CharacterBody3D] = _player_manager.get_all_players()
	for p in players:
		if p is CharacterBody3D and _get_peer_id(p) == peer_id:
			return p
	return null


func _get_peer_id(player: CharacterBody3D) -> int:
	var mp: MultiplayerAPI = player.get_tree().get_multiplayer() if player.get_tree() else null
	if not mp or not mp.has_multiplayer_peer():
		return 1
	return player.get_multiplayer_authority()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_pvp_damage(target_peer: int, damage: int, attacker_peer: int) -> void:
	if not _active:
		return
	_apply_pvp_damage(target_peer, damage, attacker_peer)


@rpc("authority", "call_remote", "reliable")
func _rpc_pvp_elimination(eliminated_peer: int, killer_peer: int) -> void:
	_eliminated[eliminated_peer] = true
	player_eliminated.emit(eliminated_peer)


@rpc("authority", "call_remote", "reliable")
func _rpc_match_over(winner_peer: int) -> void:
	match_over.emit(winner_peer)
