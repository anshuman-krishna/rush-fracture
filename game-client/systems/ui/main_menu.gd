extends Control

# main menu — entry point. aggressive, minimal.
# supports solo play and multiplayer via room codes.

@onready var title_label: Label = $Panel/ContentMargin/Content/TitleLabel
@onready var tagline_label: Label = $Panel/ContentMargin/Content/TaglineLabel
@onready var start_button: Button = $Panel/ContentMargin/Content/StartButton
@onready var best_stats_label: Label = $Panel/ContentMargin/Content/BestStatsLabel
@onready var quit_button: Button = $Panel/ContentMargin/Content/QuitButton
@onready var host_button: Button = $Panel/ContentMargin/Content/HostButton
@onready var code_input: LineEdit = $Panel/ContentMargin/Content/CodeInput
@onready var join_button: Button = $Panel/ContentMargin/Content/JoinButton
@onready var status_label: Label = $Panel/ContentMargin/Content/StatusLabel
@onready var mode_button: Button = $Panel/ContentMargin/Content/ModeButton
@onready var upgrades_button: Button = $Panel/ContentMargin/Content/UpgradesButton
@onready var shards_label: Label = $Panel/ContentMargin/Content/ShardsLabel
@onready var settings_button: Button = $Panel/ContentMargin/Content/SettingsButton

var _network_manager: NetworkManager
var _game_mode_manager: GameModeManager
var _selected_mode: GameModeManager.GameMode = GameModeManager.GameMode.COOP
var _progression_ui: ProgressionUI
var _settings_menu: SettingsMenu


func _ready() -> void:
	print("main menu ready")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# apply saved settings on startup
	var settings: GameSettings = GameSettings.load_settings()
	settings.apply()

	start_button.pressed.connect(_on_start)
	quit_button.pressed.connect(_on_quit)
	host_button.pressed.connect(_on_host)
	join_button.pressed.connect(_on_join)
	start_button.grab_focus()
	_show_best_stats()
	_show_shards()
	_animate_in()

	# create network manager as root-level node
	_network_manager = NetworkManager.new()
	_network_manager.name = "NetworkManager"
	get_tree().root.add_child(_network_manager)

	# create game mode manager
	_game_mode_manager = GameModeManager.new()
	_game_mode_manager.name = "GameModeManager"
	get_tree().root.add_child(_game_mode_manager)

	_network_manager.connection_succeeded.connect(_on_connection_succeeded)
	_network_manager.connection_failed.connect(_on_connection_failed)

	# mode selection button
	if mode_button:
		mode_button.pressed.connect(_on_mode_cycle)
		_update_mode_label()

	# progression ui
	if upgrades_button:
		upgrades_button.pressed.connect(_on_upgrades)
	_load_progression_ui()

	# settings menu
	if settings_button:
		settings_button.pressed.connect(_on_settings)
	_load_settings_menu()


func _on_start() -> void:
	print("starting game — mode: %s" % _game_mode_manager.get_mode_name())
	_game_mode_manager.set_mode(_selected_mode)

	# solo mode — clean up network manager
	if _network_manager and not _network_manager.is_online():
		_network_manager.queue_free()
		_network_manager = null
	_animate_out(func():
		var err: Error = get_tree().change_scene_to_file("res://scenes/main.tscn")
		if err != OK:
			push_error("failed to change scene to main: %s" % error_string(err))
	)


func _on_host() -> void:
	print("hosting game")
	status_label.text = "creating room..."
	status_label.visible = true
	var err: Error = _network_manager.host_game()
	if err != OK:
		status_label.text = "failed to host: %s" % error_string(err)
		return
	status_label.text = "room code: %s — share this code" % _network_manager.room_code
	join_button.disabled = true
	host_button.disabled = true
	code_input.text = _network_manager.room_code
	code_input.editable = false
	start_button.text = "start run (host)"


func _on_join() -> void:
	print("joining game")
	var code: String = code_input.text.strip_edges().to_upper()
	if code.length() != NetworkManager.CODE_LENGTH:
		status_label.text = "enter a %d-character room code" % NetworkManager.CODE_LENGTH
		status_label.visible = true
		return
	status_label.text = "connecting with code %s..." % code
	status_label.visible = true
	var err: Error = _network_manager.join_by_code(code)
	if err != OK:
		status_label.text = "failed to connect: %s" % error_string(err)
		return
	host_button.disabled = true
	join_button.disabled = true


func _on_connection_succeeded() -> void:
	if _network_manager.is_host():
		return
	status_label.text = "connected (peer %d)" % _network_manager.local_peer_id
	start_button.text = "start run (client)"


func _on_connection_failed() -> void:
	status_label.text = "connection failed — check code and try again"
	host_button.disabled = false
	join_button.disabled = false
	code_input.editable = true


func _on_mode_cycle() -> void:
	match _selected_mode:
		GameModeManager.GameMode.COOP:
			_selected_mode = GameModeManager.GameMode.RACE
		GameModeManager.GameMode.RACE:
			_selected_mode = GameModeManager.GameMode.PVP_ENCOUNTER
		GameModeManager.GameMode.PVP_ENCOUNTER:
			_selected_mode = GameModeManager.GameMode.COOP
	_update_mode_label()


func _update_mode_label() -> void:
	if not mode_button:
		return
	match _selected_mode:
		GameModeManager.GameMode.COOP:
			mode_button.text = "mode: co-op"
		GameModeManager.GameMode.RACE:
			mode_button.text = "mode: race"
		GameModeManager.GameMode.PVP_ENCOUNTER:
			mode_button.text = "mode: pvp encounter"


func _on_upgrades() -> void:
	if _progression_ui:
		_progression_ui.show_progression()


func _on_settings() -> void:
	if _settings_menu:
		_settings_menu.show_settings()


func _load_progression_ui() -> void:
	var scene: PackedScene = load("res://scenes/progression_ui.tscn")
	if scene:
		_progression_ui = scene.instantiate() as ProgressionUI
		add_child(_progression_ui)
		_progression_ui.closed.connect(func():
			_show_shards()
			start_button.grab_focus()
		)


func _load_settings_menu() -> void:
	var scene: PackedScene = load("res://scenes/settings_menu.tscn")
	if scene:
		_settings_menu = scene.instantiate() as SettingsMenu
		add_child(_settings_menu)
		_settings_menu.closed.connect(func():
			start_button.grab_focus()
		)


func _on_quit() -> void:
	if _network_manager:
		_network_manager.disconnect_game()
	get_tree().quit()


func _show_shards() -> void:
	if not shards_label:
		return
	var profile: PlayerProfile = PlayerProfile.load_profile()
	if profile.fracture_shards > 0:
		shards_label.text = "%d shards" % profile.fracture_shards
		shards_label.visible = true
	else:
		shards_label.visible = false


func _show_best_stats() -> void:
	var profile: PlayerProfile = PlayerProfile.load_profile()
	if profile.best_kills_single_run <= 0 and profile.best_combo <= 0:
		best_stats_label.visible = false
		return

	var lines: PackedStringArray = PackedStringArray()
	if profile.best_kills_single_run > 0:
		lines.append("best kills: %d" % profile.best_kills_single_run)
	if profile.best_combo > 0:
		lines.append("best combo: %d" % profile.best_combo)
	if profile.best_time > 0:
		var m: int = int(profile.best_time) / 60
		var s: int = int(profile.best_time) % 60
		lines.append("best time: %d:%02d" % [m, s])
	if profile.runs_completed > 0:
		lines.append("runs completed: %d" % profile.runs_completed)

	best_stats_label.text = " / ".join(lines)
	best_stats_label.visible = true


func _animate_in() -> void:
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.4)


func _animate_out(callback: Callable) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(callback)
