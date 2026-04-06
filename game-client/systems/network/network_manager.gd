class_name NetworkManager
extends Node

# manages multiplayer connections using godot high-level api.
# host starts enet server, clients connect via ip.
# tracks connection state and peer ids.

signal connection_succeeded
signal connection_failed
signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal server_disconnected

enum State { OFFLINE, HOSTING, JOINING, CONNECTED }

const DEFAULT_PORT: int = 27015
const MAX_CLIENTS: int = 4

var state: State = State.OFFLINE
var local_peer_id: int = 0
var connected_peers: Array[int] = []


func _ready() -> void:
	print("network manager ready")


func is_ready() -> bool:
	return get_tree() != null and get_tree().get_multiplayer() != null


func _get_mp() -> MultiplayerAPI:
	if not is_ready():
		push_error("multiplayer api not available")
		return null
	return get_tree().get_multiplayer()


func host_game(port: int = DEFAULT_PORT) -> Error:
	var mp: MultiplayerAPI = _get_mp()
	if mp == null:
		push_error("multiplayer api is null — cannot host")
		return ERR_UNAVAILABLE

	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		push_error("enet create_server failed: %s" % error_string(err))
		return err

	mp.multiplayer_peer = peer

	# verify peer assignment succeeded
	if not mp.has_multiplayer_peer():
		push_error("multiplayer peer assignment failed after host")
		return ERR_UNAVAILABLE

	state = State.HOSTING
	local_peer_id = mp.get_unique_id()
	connected_peers = [local_peer_id]

	mp.peer_connected.connect(_on_peer_connected)
	mp.peer_disconnected.connect(_on_peer_disconnected)

	print("hosting on port %d — peer id: %d" % [port, local_peer_id])
	connection_succeeded.emit()
	return OK


func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	var mp: MultiplayerAPI = _get_mp()
	if mp == null:
		push_error("multiplayer api is null — cannot join")
		return ERR_UNAVAILABLE

	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, port)
	if err != OK:
		push_error("enet create_client failed: %s" % error_string(err))
		return err

	mp.multiplayer_peer = peer

	# verify peer assignment succeeded
	if not mp.has_multiplayer_peer():
		push_error("multiplayer peer assignment failed after join")
		return ERR_UNAVAILABLE

	state = State.JOINING

	mp.connected_to_server.connect(_on_connected_to_server)
	mp.connection_failed.connect(_on_connection_failed)
	mp.server_disconnected.connect(_on_server_disconnected)
	mp.peer_connected.connect(_on_peer_connected)
	mp.peer_disconnected.connect(_on_peer_disconnected)

	print("joining %s:%d" % [address, port])
	return OK


func disconnect_game() -> void:
	if state == State.OFFLINE:
		return

	var mp: MultiplayerAPI = _get_mp()
	if mp:
		mp.multiplayer_peer = null
	state = State.OFFLINE
	local_peer_id = 0
	connected_peers.clear()

	_disconnect_signals()
	print("disconnected")


func is_host() -> bool:
	return state == State.HOSTING


func is_online() -> bool:
	return state == State.HOSTING or state == State.CONNECTED


func is_local_authority(peer_id: int) -> bool:
	return peer_id == local_peer_id


var estimated_ping_ms: float = 0.0
var _ping_send_time: float = 0.0
var _ping_timer: float = 0.0

const PING_INTERVAL: float = 1.0


func _process(delta: float) -> void:
	if not is_online():
		return
	_ping_timer -= delta
	if _ping_timer <= 0:
		_ping_timer = PING_INTERVAL
		_send_ping()


func _send_ping() -> void:
	if not is_online() or not is_ready():
		return
	_ping_send_time = Time.get_ticks_msec()
	if is_host():
		_rpc_ping.rpc()
	else:
		_rpc_ping.rpc_id(1)


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_ping() -> void:
	var mp: MultiplayerAPI = _get_mp()
	if not mp:
		return
	var sender: int = mp.get_remote_sender_id()
	_rpc_pong.rpc_id(sender)


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_pong() -> void:
	estimated_ping_ms = Time.get_ticks_msec() - _ping_send_time


func get_state_name() -> String:
	return ["offline", "hosting", "joining", "connected"][state]


func _on_connected_to_server() -> void:
	var mp: MultiplayerAPI = _get_mp()
	if not mp:
		return
	state = State.CONNECTED
	local_peer_id = mp.get_unique_id()
	connected_peers.append(local_peer_id)
	print("connected as peer %d" % local_peer_id)
	connection_succeeded.emit()


func _on_connection_failed() -> void:
	state = State.OFFLINE
	local_peer_id = 0
	print("connection failed")
	connection_failed.emit()
	_disconnect_signals()


func _on_server_disconnected() -> void:
	state = State.OFFLINE
	local_peer_id = 0
	connected_peers.clear()
	print("server disconnected")
	server_disconnected.emit()
	_disconnect_signals()


func _on_peer_connected(id: int) -> void:
	if id not in connected_peers:
		connected_peers.append(id)
	print("peer connected: %d" % id)
	player_connected.emit(id)


func _on_peer_disconnected(id: int) -> void:
	connected_peers.erase(id)
	print("peer disconnected: %d" % id)
	player_disconnected.emit(id)


func _disconnect_signals() -> void:
	if not is_inside_tree():
		return
	var mp: MultiplayerAPI = _get_mp()
	if not mp:
		return
	if mp.connected_to_server.is_connected(_on_connected_to_server):
		mp.connected_to_server.disconnect(_on_connected_to_server)
	if mp.connection_failed.is_connected(_on_connection_failed):
		mp.connection_failed.disconnect(_on_connection_failed)
	if mp.server_disconnected.is_connected(_on_server_disconnected):
		mp.server_disconnected.disconnect(_on_server_disconnected)
	if mp.peer_connected.is_connected(_on_peer_connected):
		mp.peer_connected.disconnect(_on_peer_connected)
	if mp.peer_disconnected.is_connected(_on_peer_disconnected):
		mp.peer_disconnected.disconnect(_on_peer_disconnected)
