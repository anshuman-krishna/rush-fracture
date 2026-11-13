class_name PlayerSpawner
extends Node

# creates and removes a player body for every connected peer. the body this
# peer owns takes input; the rest are puppets driven by replicated state.

const PLAYER_SCENE_PATH: String = "res://scenes/player.tscn"
const SYNC_INTERVAL: float = 0.05

var _player_scene: PackedScene
var _spawn_root: Node
var _network_manager: NetworkManager
var _spawned_players: Dictionary = {}
var _replicating: bool = false


func setup(spawn_root: Node, network_manager: NetworkManager) -> void:
	_spawn_root = spawn_root
	_network_manager = network_manager
	_player_scene = load(PLAYER_SCENE_PATH)
	network_manager.player_connected.connect(_on_player_connected)
	network_manager.player_disconnected.connect(_on_player_disconnected)
	network_manager.server_disconnected.connect(despawn_all)


## registers a body that already exists in the scene (the local player) so it
## replicates like the spawned ones.
func adopt_player(peer_id: int, player: CharacterBody3D) -> void:
	# replication matches nodes by path, so a body has to be called the same
	# thing on every peer: named after whoever owns it
	player.name = "Player_%d" % peer_id
	player.set_multiplayer_authority(peer_id)
	add_synchronizer(player, peer_id)
	_spawned_players[peer_id] = player


func spawn_for_peer(peer_id: int) -> CharacterBody3D:
	if peer_id in _spawned_players:
		return _spawned_players[peer_id]
	var instance: CharacterBody3D = _player_scene.instantiate() as CharacterBody3D
	instance.name = "Player_%d" % peer_id
	instance.set_multiplayer_authority(peer_id)

	var is_local: bool = peer_id == _network_manager.local_peer_id
	if not is_local:
		instance.input = NullInput.new()

	var index: int = _spawned_players.size()
	instance.position = Vector3(index * 2.5, 2.0, 0)
	instance.sync_position = instance.position
	_spawn_root.add_child(instance)
	_spawned_players[peer_id] = instance
	add_synchronizer(instance, peer_id)

	var cam: Camera3D = instance.get_node_or_null("Head/Camera3D") as Camera3D
	if cam:
		cam.current = is_local
	return instance


## turns state replication on or off for every body. it stays off until the
## run starts, because until then some peers are still loading the scene and
## have nothing to receive it.
func set_replicating(on: bool) -> void:
	_replicating = on
	for player: Variant in _spawned_players.values():
		if is_instance_valid(player):
			var sync: MultiplayerSynchronizer = (player as Node).get_node_or_null("MultiplayerSync") as MultiplayerSynchronizer
			if sync:
				sync.public_visibility = on


func despawn_all() -> void:
	for peer_id: int in _spawned_players.keys():
		_despawn(peer_id)
	_spawned_players.clear()


func get_player_for_peer(peer_id: int) -> CharacterBody3D:
	return _spawned_players.get(peer_id, null) as CharacterBody3D


func add_synchronizer(player: CharacterBody3D, peer_id: int) -> void:
	if player.has_node("MultiplayerSync"):
		return
	var sync: MultiplayerSynchronizer = MultiplayerSynchronizer.new()
	sync.name = "MultiplayerSync"
	sync.set_multiplayer_authority(peer_id)
	sync.replication_interval = SYNC_INTERVAL
	sync.public_visibility = _replicating

	# paths are relative to the synchronizer's root, which is the body itself
	var config: SceneReplicationConfig = SceneReplicationConfig.new()
	for prop: String in ["sync_position", "sync_rotation_y", "sync_velocity", "sync_head_rotation_x", "sync_flags", "health", "is_dead"]:
		config.add_property(NodePath(".:%s" % prop))
	sync.replication_config = config
	player.add_child(sync)


func _despawn(peer_id: int) -> void:
	if peer_id not in _spawned_players:
		return
	var player: CharacterBody3D = _spawned_players[peer_id]
	if is_instance_valid(player):
		player.queue_free()
	_spawned_players.erase(peer_id)


func _on_player_connected(peer_id: int) -> void:
	spawn_for_peer(peer_id)


func _on_player_disconnected(peer_id: int) -> void:
	_despawn(peer_id)


## input source for puppets: nothing is ever pressed.
class NullInput extends InputProvider:
	func get_move_vector() -> Vector2:
		return Vector2.ZERO

	func get_look_vector() -> Vector2:
		return Vector2.ZERO

	func is_jump_pressed() -> bool:
		return false

	func is_dash_pressed() -> bool:
		return false

	func is_slide_held() -> bool:
		return false

	func is_slide_pressed() -> bool:
		return false

	func is_shoot_held() -> bool:
		return false

	func is_ability_pressed() -> bool:
		return false

	func is_interact_pressed() -> bool:
		return false

	func is_weapon_1_pressed() -> bool:
		return false

	func is_weapon_2_pressed() -> bool:
		return false

	func is_weapon_3_pressed() -> bool:
		return false

	func get_weapon_cycle() -> int:
		return 0
