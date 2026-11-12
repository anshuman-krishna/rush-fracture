extends SceneTree

# headless playtest entry point.
#
#   godot --headless --fixed-fps 60 --path game-client -s res://tests/run_smoke.gd -- [options]
#
# options (after the bare "--"):
#   --runs=N        how many runs to play back to back (default 1)
#   --god=0|1       keep the bot at full health (default 1, so a run reaches the boss)
#   --max-sim=SEC   abort after this many simulated seconds (default 1800)
#   --verbose       log every reward pick
#
# exits 0 when every requested run reached a summary screen, 1 otherwise.
# point APPDATA at a scratch directory when running this so it never touches
# a real save file.

const BotDriver := preload("res://tests/bot/bot_driver.gd")

var _driver: Node


func _initialize() -> void:
	var opts: Dictionary = _parse_args()
	_driver = BotDriver.new()
	_driver.name = "BotDriver"
	_driver.max_runs = int(opts.get("runs", 1))
	_driver.god_mode = int(opts.get("god", 1)) != 0
	_driver.max_sim_seconds = float(opts.get("max-sim", 1800.0))
	_driver.verbose = opts.has("verbose")
	_driver.finished.connect(_on_finished)
	root.add_child(_driver)

	print("[bot] start runs=%d god=%s user=%s" % [_driver.max_runs, _driver.god_mode, OS.get_user_data_dir()])
	var err: Error = change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		print("[bot] FAIL: could not load main scene: %s" % error_string(err))
		quit(1)


func _on_finished(passed: bool, _reason: String) -> void:
	Engine.time_scale = 1.0
	quit(0 if passed else 1)


func _parse_args() -> Dictionary:
	var out: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var body: String = arg.substr(2)
		var eq: int = body.find("=")
		if eq < 0:
			out[body] = "1"
		else:
			out[body.substr(0, eq)] = body.substr(eq + 1)
	return out
