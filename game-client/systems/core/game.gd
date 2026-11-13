class_name Game
extends RefCounted

# registry of the live game scene's shared systems.
#
# game_manager fills this in when the run scene loads and clears it on exit,
# so any script can reach "the audio manager" or "the room controller"
# without a hard-coded node path. every accessor returns null when the
# system is not there (menus, tests that build a partial scene), and callers
# are expected to cope with that.

static var _manager: Node
static var _players: Node
static var _rooms: Node
static var _audio: Node
static var _feel: Node
static var _combat: Node
static var _fx_root: Node3D
static var _run: Node
static var _hud: Node
static var _projectiles: Node


static func register(manager: Node, players: Node, rooms: Node, audio_mgr: Node,
		feel_mgr: Node, combat_mgr: Node, fx_root: Node3D, run_mgr: Node) -> void:
	_manager = manager
	_players = players
	_rooms = rooms
	_audio = audio_mgr
	_feel = feel_mgr
	_combat = combat_mgr
	_fx_root = fx_root
	_run = run_mgr


## lets a scene without a full run setup (the menus) provide audio.
static func set_audio(node: Node) -> void:
	_audio = node


static func set_hud(node: Node) -> void:
	_hud = node


static func set_projectiles(node: Node) -> void:
	_projectiles = node


static func clear() -> void:
	_manager = null
	_players = null
	_rooms = null
	_audio = null
	_feel = null
	_combat = null
	_fx_root = null
	_run = null
	_hud = null
	_projectiles = null


static func manager() -> Node:
	return _manager if is_instance_valid(_manager) else null


static func players() -> PlayerManager:
	return _players as PlayerManager if is_instance_valid(_players) else null


static func rooms() -> RoomController:
	return _rooms as RoomController if is_instance_valid(_rooms) else null


static func audio() -> AudioManager:
	return _audio as AudioManager if is_instance_valid(_audio) else null


static func feel() -> GameFeel:
	return _feel as GameFeel if is_instance_valid(_feel) else null


static func combat() -> Combat:
	return _combat as Combat if is_instance_valid(_combat) else null


static func run() -> RunManager:
	return _run as RunManager if is_instance_valid(_run) else null


static func hud() -> Node:
	return _hud if is_instance_valid(_hud) else null


static func projectiles() -> ProjectileManager:
	return _projectiles as ProjectileManager if is_instance_valid(_projectiles) else null


## parent for transient world effects. lives inside the run scene, so
## anything spawned under it is freed with the scene instead of leaking
## into the menu.
static func fx_root() -> Node3D:
	return _fx_root if is_instance_valid(_fx_root) else null


## plays a sound if audio exists. position is optional (non-positional when omitted).
static func sfx(sound: StringName, volume_db: float = 0.0, pitch_variance: float = 0.0) -> void:
	var a: AudioManager = audio()
	if a:
		a.play(sound, volume_db, pitch_variance)


static func sfx_at(sound: StringName, world_pos: Vector3, volume_db: float = 0.0, pitch_variance: float = 0.0) -> void:
	var a: AudioManager = audio()
	if a:
		a.play_at(sound, world_pos, volume_db, pitch_variance)


## the local player, or null.
static func local_player() -> CharacterBody3D:
	var p: PlayerManager = players()
	return p.get_primary_player() if p else null


static func local_camera() -> Camera3D:
	var p: PlayerManager = players()
	return p.get_primary_camera() if p else null


## shakes the local camera. distance falloff is applied when a position is given.
static func shake(amount: float, world_pos: Variant = null, falloff_radius: float = 30.0) -> void:
	var cam: Camera3D = local_camera()
	if not cam or not cam.has_method("add_shake"):
		return
	var k: float = 1.0
	if world_pos is Vector3:
		k = clampf(1.0 - cam.global_position.distance_to(world_pos) / falloff_radius, 0.0, 1.0)
	if k > 0.0:
		cam.add_shake(amount * k)


static func is_online() -> bool:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree:
		return false
	var mp: MultiplayerAPI = tree.get_multiplayer()
	return mp != null and mp.has_multiplayer_peer() and not (mp.multiplayer_peer is OfflineMultiplayerPeer)


static func is_host_or_solo() -> bool:
	if not is_online():
		return true
	return (Engine.get_main_loop() as SceneTree).get_multiplayer().is_server()
