class_name PlayerSpawner
extends Node

# spawns and despawns player instances for each connected peer.
# local player gets input authority, remote players are puppets.

const PLAYER_SCENE_PATH: String = "res://scenes/player.tscn"
const SYNC_INTERVAL: float = 0.05  # 20 updates/sec

var _player_scene: PackedScene
var _spawn_root: Node
var _player_manager: PlayerManager
var _network_manager: NetworkManager
var _spawned_players: Dictionary = {}


func setup(spawn_root: Node, player_manager: PlayerManager, network_manager: NetworkManager) -> void:
	_spawn_root = spawn_root
	_player_manager = player_manager
	_network_manager = network_manager

	_player_scene = load(PLAYER_SCENE_PATH)

	network_manager.player_connected.connect(_on_player_connected)
	network_manager.player_disconnected.connect(_on_player_disconnected)
	network_manager.server_disconnected.connect(_on_server_disconnected)


func spawn_local_player() -> CharacterBody3D:
	return _spawn_player_for_peer(_network_manager.local_peer_id)


func spawn_all_connected() -> void:
	for peer_id: int in _network_manager.connected_peers:
		if peer_id not in _spawned_players:
			_spawn_player_for_peer(peer_id)


func despawn_all() -> void:
	for peer_id: int in _spawned_players.keys():
		_despawn_player(peer_id)
	_spawned_players.clear()


func get_player_for_peer(peer_id: int) -> CharacterBody3D:
	return _spawned_players.get(peer_id, null) as CharacterBody3D


func _spawn_player_for_peer(peer_id: int) -> CharacterBody3D:
	if peer_id in _spawned_players:
		return _spawned_players[peer_id]

	var instance: CharacterBody3D = _player_scene.instantiate() as CharacterBody3D
	instance.name = "Player_%d" % peer_id
	instance.set_multiplayer_authority(peer_id)

	# offset spawn position per player
	var player_index: int = _spawned_players.size()
	instance.global_position = Vector3(player_index * 3.0, 2, 0)

	# disable input for remote players
	var is_local: bool = peer_id == _network_manager.local_peer_id
	if not is_local:
		instance.input = _NullInputProvider.new()
		instance.set_process_unhandled_input(false)

	_spawn_root.add_child(instance, true)
	_spawned_players[peer_id] = instance

	# set up synchronizer for this player
	_add_synchronizer(instance, peer_id)

	# camera only on local player
	var cam: Camera3D = instance.get_node_or_null("Head/Camera3D") as Camera3D
	if cam:
		cam.current = is_local

	return instance


func _despawn_player(peer_id: int) -> void:
	if peer_id not in _spawned_players:
		return
	var player: CharacterBody3D = _spawned_players[peer_id]
	if is_instance_valid(player):
		player.queue_free()
	_spawned_players.erase(peer_id)


func _add_synchronizer(player: CharacterBody3D, peer_id: int) -> void:
	var sync: MultiplayerSynchronizer = MultiplayerSynchronizer.new()
	sync.name = "MultiplayerSync"
	sync.set_multiplayer_authority(peer_id)
	sync.replication_interval = SYNC_INTERVAL

	# sync interpolation targets + health (not raw position — player lerps to these)
	var config: SceneReplicationConfig = SceneReplicationConfig.new()
	config.add_property(NodePath("%s:sync_position" % player.get_path()))
	config.add_property(NodePath("%s:sync_rotation_y" % player.get_path()))
	config.add_property(NodePath("%s:sync_velocity" % player.get_path()))
	config.add_property(NodePath("%s:sync_head_rotation_x" % player.get_path()))
	config.add_property(NodePath("%s:health" % player.get_path()))

	sync.replication_config = config
	player.add_child(sync)


func _on_player_connected(peer_id: int) -> void:
	_spawn_player_for_peer(peer_id)


func _on_player_disconnected(peer_id: int) -> void:
	_despawn_player(peer_id)


func _on_server_disconnected() -> void:
	despawn_all()


# null input provider for remote players
class _NullInputProvider extends InputProvider:
	func get_move_vector() -> Vector2:
		return Vector2.ZERO

	func is_jump_pressed() -> bool:
		return false

	func is_dash_pressed() -> bool:
		return false

	func is_shoot_held() -> bool:
		return false

	func is_weapon_1_pressed() -> bool:
		return false

	func is_weapon_2_pressed() -> bool:
		return false

	func is_weapon_3_pressed() -> bool:
		return false
