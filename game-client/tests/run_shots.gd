extends SceneTree

# windowed capture run: the playtest bot plays while this script saves
# screenshots at interesting moments, so visual changes can be reviewed
# without a human at the keyboard.
#
#   godot --fixed-fps 60 --disable-vsync --resolution 1280x720 --path game-client \
#       -s res://tests/run_shots.gd -- --out=C:/some/dir [--every=4] [--max-shots=40] [--scene=res://...]
#
# also: --upgrades=a,b|all (start the run with these), and for the menu scene
# --menu-tab=NAME to open the progression panel on that tab before the shots.
#
# needs a real renderer (do not pass --headless).

const BotDriver := preload("res://tests/bot/bot_driver.gd")

var _driver: Node
var _out_dir: String = "user://shots"
var _every: float = 4.0
var _max_shots: int = 40
var _shot_count: int = 0
var _timer: float = 1.5
var _pending: String = ""
var _last_room: int = -1
var _room_shot_delay: float = -1.0
var _seen: Dictionary = {}
var _quit_after: float = -1.0
var _hide_ui: bool = false
var _menu_tab: String = ""


func _initialize() -> void:
	var opts: Dictionary = _parse_args()
	_out_dir = String(opts.get("out", _out_dir))
	_every = float(opts.get("every", _every))
	_max_shots = int(opts.get("max-shots", _max_shots))
	DirAccess.make_dir_recursive_absolute(_out_dir)

	_driver = BotDriver.new()
	_driver.name = "BotDriver"
	_driver.max_runs = int(opts.get("runs", 1))
	_driver.god_mode = int(opts.get("god", 1)) != 0
	_driver.max_sim_seconds = float(opts.get("max-sim", 600.0))
	_driver.room_limit = int(opts.get("rooms", 0))
	_driver.grant_upgrades = String(opts.get("upgrades", "")).split(",", false)
	_driver.force_condition = String(opts.get("condition", ""))
	_menu_tab = String(opts.get("menu-tab", ""))
	_driver.finished.connect(_on_finished)
	root.add_child(_driver)

	var mode_node: GameModeManager = GameModeManager.new()
	mode_node.name = "GameModeManager"
	mode_node.run_mode = StringName(String(opts.get("mode", "standard")))
	mode_node.ascension = int(opts.get("ascension", 0))
	mode_node.custom_seed = int(opts.get("seed", 0))
	root.add_child(mode_node)
	if opts.has("loadout"):
		var profile: PlayerProfile = PlayerProfile.load_profile()
		var ids: Array = []
		for id: String in String(opts.loadout).split(",", false):
			profile.unlocks[id.strip_edges()] = true
			ids.append(id.strip_edges())
		profile.loadout = WeaponDefs.sanitize_loadout(ids, profile.owns_weapon)
		profile.save()

	RenderingServer.frame_post_draw.connect(_on_frame_drawn)
	var scene: String = String(opts.get("scene", "res://scenes/main.tscn"))
	print("[shot] start out=%s scene=%s" % [_out_dir, scene])
	change_scene_to_file(scene)


func _process(delta: float) -> bool:
	if _quit_after >= 0.0:
		_quit_after -= delta
		if _quit_after <= 0.0 and _pending.is_empty():
			return true
		return false

	var main: Node = root.get_node_or_null("Main")
	if not main:
		_timer -= delta
		if _timer <= 0.0:
			_timer = _every
			if not _menu_tab.is_empty() and current_scene and current_scene.has_method("_open_progression"):
				current_scene._open_progression()
				var panel: Node = current_scene.get("_progression")
				panel.set("_tab", _menu_tab)
				panel.call("_rebuild")
				_menu_tab = ""
				_timer = 1.0
				return false
			_request("menu")
			if _max_shots <= _shot_count + 1:
				_quit_after = 0.5
		return false

	var gm: Node = main.get_node_or_null("GameManager")
	if gm and gm.get("run_manager") and gm.run_manager.data:
		var idx: int = gm.run_manager.data.current_room_index
		if idx != _last_room:
			_last_room = idx
			_room_shot_delay = 1.6
		if _room_shot_delay >= 0.0:
			_room_shot_delay -= delta
			if _room_shot_delay < 0.0:
				_request("room%02d_start" % (idx + 1))

	_once(main, "UI/UpgradeSelection", "upgrade_ui")
	_once(main, "UI/MutationSelection", "mutation_ui")
	_once(main, "UI/RunSummary", "summary")
	_once(main, "UI/PathChoice", "path_ui")
	_once(main, "UI/Shop", "shop_ui")

	_timer -= delta
	if _timer <= 0.0:
		_timer = _every
		_request("play")
	return false


func _once(main: Node, path: String, label: String) -> void:
	var node: Control = main.get_node_or_null(path) as Control
	if node and node.visible and node.modulate.a > 0.95 and not _seen.has(label):
		_seen[label] = true
		_request(label)


func _request(label: String) -> void:
	if _shot_count >= _max_shots or not _pending.is_empty():
		return
	_pending = label


func _on_frame_drawn() -> void:
	if _pending.is_empty():
		return
	var label: String = _pending
	_pending = ""
	var img: Image = root.get_texture().get_image()
	if not img:
		return
	_shot_count += 1
	var path: String = "%s/%03d_%s.png" % [_out_dir, _shot_count, label]
	var err: Error = img.save_png(path)
	print("[shot] %s (%s)" % [path, error_string(err)])


func _on_finished(passed: bool, reason: String) -> void:
	print("[shot] bot finished passed=%s %s" % [passed, reason])
	_request("final")
	_quit_after = 0.5


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
