extends SceneTree

# two-peer playtest. start one copy as the host and one as the client, on the
# same machine, and a bot plays each side through a real network session.
#
#   godot --headless --max-fps 60 --path game-client -s res://tests/run_net.gd -- --role=host [options]
#   godot --headless --max-fps 60 --path game-client -s res://tests/run_net.gd -- --role=join [options]
#
# options (after the bare "--"), the same on both sides:
#   --role=host|join  which end this copy plays (required)
#   --port=N          udp port (default 27101)
#   --versus=NAME     coop | race | pvp (default coop)
#   --mode=NAME       run shape for co-op: standard | sprint | ... (default sprint)
#   --ascension=N     difficulty tier (default 0)
#   --seed=N          fixed run seed (default 4242)
#   --god=0|1         keep this side's bot at full health (default 1)
#   --rooms=N         host only: end the run after N cleared rooms
#   --upgrades=a,b|all  upgrade ids both bots start the run with
#   --max-sim=SEC     give up after this long (default 600)
#   --leave-after=SEC drop out this long after the run starts (join side),
#                     to test what the others do about it
#   --leave-in-duel   drop out a moment after the duel begins (join side)
#   --verbose         log every reward pick
#
# do not pass --fixed-fps: both copies have to run in real time or their
# clocks drift apart. give each copy its own APPDATA so they do not share a
# save file. exits 0 when this side reached the summary screen.

const BotDriver := preload("res://tests/bot/bot_driver.gd")
const Smoke := preload("res://tests/run_smoke.gd")

const VERSUS: Dictionary = {
	"coop": GameModeManager.GameMode.COOP,
	"race": GameModeManager.GameMode.RACE,
	"pvp": GameModeManager.GameMode.PVP_ENCOUNTER,
}

var _opts: Dictionary
var _role: String
var _port: int
var _net: NetworkManager
var _driver: Node
var _start_in: float = -1.0
var _rejoin_in: float = -1.0
var _quit_in: float = -1.0
var _exit_code: int = 1
var _clock_usec: int = 0
var _connected: bool = false
var _in_run: float = 0.0
var _in_duel: float = 0.0


func _initialize() -> void:
	_opts = Smoke.parse_args()
	_role = String(_opts.get("role", ""))
	_port = int(_opts.get("port", 27101))
	if _role != "host" and _role != "join":
		print("[net] FAIL: pass --role=host or --role=join")
		quit(1)
		return

	var modes: GameModeManager = GameModeManager.new()
	modes.name = "GameModeManager"
	root.add_child(modes)

	_net = NetworkManager.new()
	_net.name = "NetworkManager"
	root.add_child(_net)
	_net.player_connected.connect(_on_player_connected)
	_net.player_disconnected.connect(func(id: int) -> void: print("[net] %s: peer %d left" % [_role, id]))
	_net.connection_succeeded.connect(func() -> void: print("[net] %s: online as peer %d" % [_role, _net.local_peer_id]))
	_net.connection_failed.connect(_on_connection_failed)
	_net.server_disconnected.connect(_on_host_gone)
	_net.match_starting.connect(func(versus: int, mode: String, asc: int, seed_value: int) -> void:
		print("[net] %s: match starting versus=%d mode=%s ascension=%d seed=%d" % [_role, versus, mode, asc, seed_value]))

	_driver = BotDriver.new()
	_driver.name = "BotDriver"
	_driver.max_runs = 1
	_driver.god_mode = int(_opts.get("god", 1)) != 0
	_driver.max_sim_seconds = float(_opts.get("max-sim", 600.0))
	_driver.room_limit = int(_opts.get("rooms", 0)) if _role == "host" else 0
	_driver.verbose = _opts.has("verbose")
	_driver.grant_upgrades = String(_opts.get("upgrades", "")).split(",", false)
	_driver.force_condition = String(_opts.get("condition", ""))
	_driver.finished.connect(_on_finished)
	root.add_child(_driver)

	_clock_usec = Time.get_ticks_usec()


## the tree is not running yet inside _initialize, and the network needs it,
## so the session opens on the first frame instead.
func _connect() -> void:
	if _role == "host":
		var err: Error = _net.host_game(_port)
		if err != OK:
			print("[net] FAIL: could not host on port %d: %s" % [_port, error_string(err)])
			quit(1)
			return
		print("[net] host: listening on port %d" % _port)
	else:
		_join()


func _join() -> void:
	var err: Error = _net.join_game("127.0.0.1", _port)
	print("[net] join: connecting to port %d (%s)" % [_port, error_string(err)])
	if err != OK:
		_rejoin_in = 1.0


## a client has nothing left to test once the host is gone.
func _on_host_gone() -> void:
	print("[net] %s: the host went away" % _role)
	if not _driver.get("_done"):
		print("[net] %s: FAIL (host left before this side finished)" % _role)
		_quit_in = 0.5


func _on_connection_failed() -> void:
	print("[net] join: connection failed, trying again")
	_rejoin_in = 1.0


func _on_player_connected(id: int) -> void:
	print("[net] %s: peer %d joined (%d in the session)" % [_role, id, _net.connected_peers.size()])
	if _role == "host" and _start_in < 0.0:
		# give the client a moment to settle before changing scene under it
		_start_in = 1.0


func _on_finished(passed: bool, reason: String) -> void:
	Engine.time_scale = 1.0
	_exit_code = 0 if passed else 1
	print("[net] %s: %s (%s)" % [_role, "PASS" if passed else "FAIL", reason])
	_report()
	# stay connected a little longer so the other side sees the end as well
	_quit_in = 4.0


## what this side saw, to compare against the other side's log.
func _report() -> void:
	var combat: Combat = Game.combat()
	if combat:
		print("[net] %s: dealt %d damage in %d hits" % [_role, combat.total_damage, combat.shots_landed])
	var players: PlayerManager = Game.players()
	if players:
		for p: CharacterBody3D in players.get_all_players():
			if is_instance_valid(p):
				print("[net] %s: sees %s (owner %d) at %s hp %d" % [_role, p.name, p.get_multiplayer_authority(), p.global_position.snappedf(0.1), p.health])
	var modes: GameModeManager = root.get_node_or_null("GameModeManager") as GameModeManager
	if modes:
		var summary: Dictionary = modes.get_score_summary()
		for peer_id: int in summary:
			var s: Dictionary = summary[peer_id]
			print("[net] %s: score for %d: kills %d damage %d rooms %d duel kills %d duel wins %d total %d" % [
				_role, peer_id, s.enemy_kills, s.damage_dealt, s.rooms_cleared, s.pvp_kills, s.pvp_wins, s.total])


func _process(_delta: float) -> bool:
	var now: int = Time.get_ticks_usec()
	var delta: float = float(now - _clock_usec) / 1000000.0
	_clock_usec = now
	if not _connected:
		_connected = true
		_connect()

	if _start_in >= 0.0:
		_start_in -= delta
		if _start_in < 0.0:
			var versus: int = VERSUS.get(String(_opts.get("versus", "coop")), GameModeManager.GameMode.COOP)
			_net.start_match(versus, String(_opts.get("mode", "sprint")), int(_opts.get("ascension", 0)), int(_opts.get("seed", 4242)))
	if _rejoin_in >= 0.0:
		_rejoin_in -= delta
		if _rejoin_in < 0.0:
			_join()
	if _role == "join" and _quit_in < 0.0:
		var manager: Node = Game.manager()
		if manager and manager.run_manager.is_active:
			_in_run += delta
			if manager.get("_pvp_active") == true:
				_in_duel += delta
		var leave_after: float = float(_opts.get("leave-after", 0.0))
		if (leave_after > 0.0 and _in_run >= leave_after) or (_opts.has("leave-in-duel") and _in_duel >= 1.5):
			# gone without a word, the way a crash or a pulled cable looks
			print("[net] join: dropping out on purpose after %.1fs in the run" % _in_run)
			quit(0)
			return true
	if _quit_in >= 0.0:
		_quit_in -= delta
		if _quit_in < 0.0:
			quit(_exit_code)
	return false
