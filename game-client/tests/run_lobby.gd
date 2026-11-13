extends SceneTree

# two-peer playtest that starts where a player does: the main menu. one copy
# presses "host" and prints the room code, the other types that code and
# presses "join", the host presses "start", and a bot plays each side.
#
#   godot --headless --max-fps 60 --path game-client -s res://tests/run_lobby.gd -- --role=host [options]
#   godot --headless --max-fps 60 --path game-client -s res://tests/run_lobby.gd -- --role=join --code=ABC123
#
# options (after the bare "--"):
#   --role=host|join  which end this copy plays (required)
#   --code=XXXXXX     join only: the room code the host printed
#   --versus=NAME     host only: coop | race | pvp (default coop)
#   --mode=NAME       host only: run shape for co-op (default sprint)
#   --max-sim=SEC     give up after this long (default 600)
#
# like run_net.gd this has to run in real time (no --fixed-fps), with a
# separate APPDATA for each copy. exits 0 when this side reached the summary.

const BotDriver := preload("res://tests/bot/bot_driver.gd")
const Smoke := preload("res://tests/run_smoke.gd")
const VERSUS: Array[String] = ["coop", "race", "pvp"]

var _opts: Dictionary
var _role: String
var _driver: Node
var _clock_usec: int = 0
var _wait: float = 1.5
var _step: int = 0
var _quit_in: float = -1.0
var _exit_code: int = 1
var _join_presses: int = 0


func _initialize() -> void:
	_opts = Smoke.parse_args()
	_role = String(_opts.get("role", ""))
	if _role != "host" and _role != "join":
		print("[net] FAIL: pass --role=host or --role=join")
		quit(1)
		return
	_driver = BotDriver.new()
	_driver.name = "BotDriver"
	_driver.max_runs = 1
	_driver.max_sim_seconds = float(_opts.get("max-sim", 600.0))
	_driver.finished.connect(_on_finished)
	root.add_child(_driver)
	_clock_usec = Time.get_ticks_usec()
	var err: Error = change_scene_to_file("res://scenes/main_menu.tscn")
	if err != OK:
		print("[net] FAIL: could not load the menu: %s" % error_string(err))
		quit(1)


func _on_finished(passed: bool, reason: String) -> void:
	Engine.time_scale = 1.0
	_exit_code = 0 if passed else 1
	print("[net] %s: %s (%s)" % [_role, "PASS" if passed else "FAIL", reason])
	var players: PlayerManager = Game.players()
	if players:
		print("[net] %s: %d players in the scene at the end" % [_role, players.get_player_count()])
	_quit_in = 4.0


func _process(_delta: float) -> bool:
	var now: int = Time.get_ticks_usec()
	var delta: float = float(now - _clock_usec) / 1000000.0
	_clock_usec = now

	if _quit_in >= 0.0:
		_quit_in -= delta
		if _quit_in < 0.0:
			quit(_exit_code)
		return false

	var menu: Node = current_scene
	if not menu or menu.get("_host_button") == null:
		return false
	_wait -= delta
	if _wait > 0.0:
		return false

	if _role == "host":
		_drive_host(menu)
	else:
		_drive_join(menu)
	return false


func _drive_host(menu: Node) -> void:
	var network: NetworkManager = menu.get("_network")
	match _step:
		0:
			# pick the run shape and the versus rule with the same buttons a player uses
			var want_mode: StringName = StringName(String(_opts.get("mode", "sprint")))
			for i: int in menu.RUN_MODES.size():
				if menu.RUN_MODES[menu.get("_run_mode_index")] == want_mode:
					break
				(menu.get("_mode_button") as Button).pressed.emit()
			var want_versus: int = maxi(0, VERSUS.find(String(_opts.get("versus", "coop"))))
			for i: int in VERSUS.size():
				if menu.get("_coop_mode") == want_versus:
					break
				(menu.get("_coop_button") as Button).pressed.emit()
			(menu.get("_host_button") as Button).pressed.emit()
			if not network.is_host():
				print("[net] FAIL: pressing host did not start a session")
				quit(1)
				return
			print("[net] host: room code %s" % network.room_code)
			_step = 1
		1:
			if network.connected_peers.size() >= 2:
				print("[net] host: %d in the lobby, button reads \"%s\"" % [
					network.connected_peers.size(), (menu.get("_start_button") as Button).text])
				_wait = 1.0
				_step = 2
		2:
			(menu.get("_start_button") as Button).pressed.emit()
			_step = 3


func _drive_join(menu: Node) -> void:
	var network: NetworkManager = menu.get("_network")
	match _step:
		0:
			(menu.get("_code_input") as LineEdit).text = String(_opts.get("code", ""))
			(menu.get("_join_button") as Button).pressed.emit()
			_join_presses += 1
			_wait = 3.0
			_step = 1
		1:
			if network.is_online():
				print("[net] join: in the lobby, button reads \"%s\"" % (menu.get("_start_button") as Button).text)
				_step = 2
			elif _join_presses < 5:
				# not up yet, or the attempt timed out: press it again
				_step = 0
			else:
				print("[net] FAIL: could not join with code %s" % _opts.get("code", ""))
				quit(1)
