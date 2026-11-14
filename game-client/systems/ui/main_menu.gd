extends Control

# title screen: pick a mode and difficulty, manage the armory and
# progression, change settings, or host / join a multiplayer room.

const RUN_MODES: Array[StringName] = [
	RunData.MODE_STANDARD, RunData.MODE_SPRINT, RunData.MODE_ENDLESS, RunData.MODE_BOSS_RUSH, RunData.MODE_DAILY,
	RunData.MODE_ONSLAUGHT, RunData.MODE_TEMPEST, RunData.MODE_HUNT, RunData.MODE_DRAFT, RunData.MODE_DEADLINE,
]
const COOP_MODE_NAMES: Array[String] = ["co-op", "race", "pvp encounter"]

var _profile: PlayerProfile
var _network: NetworkManager
var _modes: GameModeManager
var _backdrop: MenuBackdrop
var _audio: AudioManager

var _run_mode_index: int = 0
var _coop_mode: int = 0
var _ascension: int = 0
var _difficulty: StringName = Difficulty.DEFAULT

var _root_panel: Control
var _mode_tabs: Array[IconTab] = []
var _mode_name: Label
var _difficulty_buttons: Dictionary = {}
var _difficulty_blurb: Label
var _ascension_box: HBoxContainer
var _ascension_value: Label
var _mode_button: Button
var _mode_blurb: Label
var _ascension_button: Button
var _ascension_blurb: Label
var _start_button: Button
var _shards_label: Label
var _stats_label: Label
var _seed_input: LineEdit
var _net_box: VBoxContainer
var _host_button: Button
var _join_button: Button
var _leave_button: Button
var _code_input: LineEdit
var _ip_input: LineEdit
var _status: Label
var _coop_button: Button

var _armory: ArmoryPanel
var _progression: ProgressionPanel
var _settings_panel: SettingsPanel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Engine.time_scale = 1.0
	get_tree().paused = false

	GameSettings.load_settings().apply()
	_profile = PlayerProfile.load_profile()
	_ascension = _profile.ascension_selected
	_difficulty = Difficulty.valid(_profile.difficulty_selected)

	_audio = AudioManager.new()
	_audio.name = "MenuAudio"
	add_child(_audio)
	Game.set_audio(_audio)
	_audio.play_music(&"menu")
	_audio.set_music_state(AudioManager.MusicState.MENU)

	_backdrop = MenuBackdrop.new()
	add_child(_backdrop)
	_backdrop.set_tint(Skins.accent(_profile.skin))
	_backdrop.show_random_boss()

	_setup_persistent_nodes()
	_build()
	_refresh()

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)


func _exit_tree() -> void:
	if Game.audio() == _audio:
		Game.set_audio(null)


## the network and mode managers live on the tree root so they survive the
## change into the run scene. reuse them when coming back from a run.
func _setup_persistent_nodes() -> void:
	var root: Node = get_tree().root
	_network = root.get_node_or_null("NetworkManager") as NetworkManager
	if not _network:
		_network = NetworkManager.new()
		_network.name = "NetworkManager"
		root.add_child.call_deferred(_network)
	_modes = root.get_node_or_null("GameModeManager") as GameModeManager
	if not _modes:
		_modes = GameModeManager.new()
		_modes.name = "GameModeManager"
		root.add_child.call_deferred(_modes)
	else:
		_run_mode_index = maxi(0, RUN_MODES.find(_modes.run_mode))
	_network.connection_succeeded.connect(_on_connection_changed)
	_network.connection_failed.connect(_on_connection_failed)
	_network.player_connected.connect(func(_id: int) -> void: _refresh())
	_network.player_disconnected.connect(func(_id: int) -> void: _refresh())
	_network.server_disconnected.connect(_on_connection_changed)


func _build() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_top", 70)
	margin.add_theme_constant_override("margin_bottom", 60)
	margin.add_theme_constant_override("margin_right", 90)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	_root_panel = margin

	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.custom_minimum_size = Vector2(560, 0)
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)

	var name_label: Label = UiKit.label("RUSH FRACTURE", 84, Color(0.97, 0.94, 0.88))
	name_label.add_theme_font_override("font", UiKit.font_title())
	col.add_child(name_label)
	var motto: Label = UiKit.label("break speed. survive chaos.", 17, UiKit.ACCENT)
	motto.add_theme_font_override("font", UiKit.font_tag())
	col.add_child(motto)
	var purse: HBoxContainer = HBoxContainer.new()
	purse.add_theme_constant_override("separation", 18)
	col.add_child(purse)
	_shards_label = UiKit.label("", 19, UiKit.GOLD, true)
	purse.add_child(_shards_label)
	_stats_label = UiKit.label("", 14, UiKit.TEXT_DIM)
	_stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_label.clip_text = true
	purse.add_child(_stats_label)

	_start_button = UiKit.button("start run", 26, Vector2(560, 62))
	_start_button.add_theme_color_override("font_color", UiKit.ACCENT)
	_start_button.add_theme_font_override("font", UiKit.font_title())
	_start_button.pressed.connect(_on_start)
	col.add_child(_start_button)

	# --- the run: which mode, how hard, which seed
	col.add_child(_tag("the run"))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	for i: int in RUN_MODES.size():
		var tab: IconTab = IconTab.new()
		tab.glyph = GameModeManager.run_mode_glyph(RUN_MODES[i])
		tab.caption = GameModeManager.run_mode_name(RUN_MODES[i]).trim_suffix(" run").trim_prefix("the ")
		var index: int = i
		tab.pressed.connect(func() -> void:
			_run_mode_index = index
			Game.sfx(&"ui_select", -8.0)
			_refresh())
		grid.add_child(tab)
		_mode_tabs.append(tab)

	var mode_row: HBoxContainer = HBoxContainer.new()
	col.add_child(mode_row)
	_mode_name = UiKit.label("", 24, UiKit.BONE)
	_mode_name.add_theme_font_override("font", UiKit.font_title())
	_mode_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_row.add_child(_mode_name)
	# steps to the next mode: for a pad, and for the menu test, which presses it
	_mode_button = UiKit.button("next", 14, Vector2(70, 30))
	_mode_button.pressed.connect(func() -> void:
		_run_mode_index = (_run_mode_index + 1) % RUN_MODES.size()
		Game.sfx(&"ui_select", -8.0)
		_refresh())
	mode_row.add_child(_mode_button)
	_mode_blurb = UiKit.label("", 15, UiKit.TEXT_DIM)
	_mode_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mode_blurb.custom_minimum_size = Vector2(0, 40)
	col.add_child(_mode_blurb)

	var diff_row: HBoxContainer = HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 8)
	col.add_child(diff_row)
	for id: StringName in Difficulty.ORDER:
		var b: Button = UiKit.button(Difficulty.display_name(id), 16, Vector2(0, 36))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var chosen: StringName = id
		b.pressed.connect(func() -> void:
			_difficulty = chosen
			_profile.difficulty_selected = String(chosen)
			_profile.save()
			Game.sfx(&"ui_select", -8.0)
			_refresh())
		diff_row.add_child(b)
		_difficulty_buttons[id] = b
	_difficulty_blurb = UiKit.label("", 14, UiKit.TEXT_DIM)
	_difficulty_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_difficulty_blurb)

	var tune_row: HBoxContainer = HBoxContainer.new()
	tune_row.add_theme_constant_override("separation", 8)
	col.add_child(tune_row)
	_ascension_box = HBoxContainer.new()
	_ascension_box.add_theme_constant_override("separation", 6)
	tune_row.add_child(_ascension_box)
	_ascension_box.add_child(UiKit.label("ascension", 15, UiKit.TEXT_DIM))
	var down: Button = UiKit.button("-", 16, Vector2(34, 34))
	down.pressed.connect(func() -> void: _step_ascension(-1))
	_ascension_box.add_child(down)
	_ascension_value = UiKit.label("0", 20, UiKit.BONE, true)
	_ascension_value.custom_minimum_size = Vector2(30, 0)
	_ascension_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ascension_box.add_child(_ascension_value)
	_ascension_button = UiKit.button("+", 16, Vector2(34, 34))
	_ascension_button.pressed.connect(func() -> void: _step_ascension(1))
	_ascension_box.add_child(_ascension_button)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(16, 0)
	_ascension_box.add_child(gap)
	tune_row.add_child(UiKit.label("seed", 15, UiKit.TEXT_DIM))
	_seed_input = LineEdit.new()
	_seed_input.placeholder_text = "random"
	_seed_input.max_length = 9
	_seed_input.custom_minimum_size = Vector2(150, 34)
	tune_row.add_child(_seed_input)
	_ascension_blurb = UiKit.label("", 14, UiKit.TEXT_DIM)
	_ascension_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_ascension_blurb)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	_small_button(row, "armory", _open_armory)
	_small_button(row, "progression", _open_progression)
	_small_button(row, "settings", _open_settings)
	_small_button(row, "quit", func() -> void:
		_network.disconnect_game()
		get_tree().quit())

	col.add_child(_spacer(6))
	col.add_child(_tag("multiplayer"))
	_net_box = VBoxContainer.new()
	_net_box.add_theme_constant_override("separation", 8)
	col.add_child(_net_box)

	_coop_button = UiKit.button("", 17, Vector2(560, 38))
	_coop_button.pressed.connect(func() -> void:
		_coop_mode = (_coop_mode + 1) % COOP_MODE_NAMES.size()
		_refresh())
	_net_box.add_child(_coop_button)

	var net_row: HBoxContainer = HBoxContainer.new()
	net_row.add_theme_constant_override("separation", 10)
	_net_box.add_child(net_row)
	_host_button = UiKit.button("host", 17, Vector2(120, 40))
	_host_button.pressed.connect(_on_host)
	net_row.add_child(_host_button)
	_code_input = LineEdit.new()
	_code_input.placeholder_text = "room code"
	_code_input.max_length = NetworkManager.CODE_LENGTH
	_code_input.custom_minimum_size = Vector2(130, 40)
	net_row.add_child(_code_input)
	_ip_input = LineEdit.new()
	_ip_input.placeholder_text = "host ip (blank = this pc)"
	_ip_input.custom_minimum_size = Vector2(150, 40)
	_ip_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	net_row.add_child(_ip_input)
	_join_button = UiKit.button("join", 17, Vector2(90, 40))
	_join_button.pressed.connect(_on_join)
	net_row.add_child(_join_button)

	_leave_button = UiKit.button("leave room", 16, Vector2(160, 36))
	_leave_button.pressed.connect(func() -> void:
		_network.disconnect_game()
		_refresh())
	_net_box.add_child(_leave_button)
	_status = UiKit.label("", 15, UiKit.TEXT_DIM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_net_box.add_child(_status)


	_armory = ArmoryPanel.new()
	add_child(_armory)
	_armory.closed.connect(_on_panel_closed)
	_armory.profile_changed.connect(_refresh)
	_armory.preview_requested.connect(func(path: String, skin: StringName) -> void:
		_backdrop.set_tint(Skins.accent(skin))
		_backdrop.show_model(path, skin, 0.6))
	_progression = ProgressionPanel.new()
	add_child(_progression)
	_progression.closed.connect(_on_panel_closed)
	_progression.profile_changed.connect(_refresh)
	_settings_panel = SettingsPanel.new()
	add_child(_settings_panel)
	_settings_panel.closed.connect(_on_panel_closed)

	_start_button.grab_focus.call_deferred()


## a small spaced heading over a group of controls, with a rule after it.
func _tag(text: String) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l: Label = UiKit.label(text, 13, UiKit.BONE)
	l.add_theme_font_override("font", UiKit.font_tag())
	row.add_child(l)
	var line: ColorRect = ColorRect.new()
	line.color = Color(UiKit.BONE.r, UiKit.BONE.g, UiKit.BONE.b, 0.3)
	line.custom_minimum_size = Vector2(0, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	return row


func _step_ascension(by: int) -> void:
	_ascension = posmod(_ascension + by, _profile.ascension_unlocked + 1)
	_profile.ascension_selected = _ascension
	_profile.save()
	Game.sfx(&"ui_select", -8.0)
	_refresh()


func _spacer(height: float) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


func _small_button(row: HBoxContainer, text: String, callback: Callable) -> void:
	var b: Button = UiKit.button(text, 17, Vector2(132, 42))
	b.pressed.connect(callback)
	row.add_child(b)


# --- state ----------------------------------------------------------------------

func _refresh() -> void:
	if not _mode_button:
		return
	var mode: StringName = RUN_MODES[_run_mode_index]
	var online: bool = _network.is_online()
	var hosting: bool = _network.is_host()
	var versus: bool = online and _coop_mode != 0

	_shards_label.text = "%d shards" % _profile.fracture_shards
	_stats_label.text = "   ·   ".join(_profile.get_stat_summary())

	_mode_name.text = GameModeManager.run_mode_name(mode)
	_mode_blurb.text = GameModeManager.run_mode_description(mode)
	var locked: bool = versus or (online and not hosting)
	for i: int in _mode_tabs.size():
		_mode_tabs[i].selected = i == _run_mode_index
		_mode_tabs[i].disabled = locked
		_mode_tabs[i].queue_redraw()
	for id: StringName in _difficulty_buttons:
		var b: Button = _difficulty_buttons[id]
		var tint: Color = Difficulty.color(id)
		b.disabled = locked
		if id == _difficulty:
			b.add_theme_stylebox_override("normal", UiKit.box(UiKit.CARD.lerp(tint, 0.18), tint, 2))
			b.add_theme_color_override("font_color", tint)
		else:
			b.remove_theme_stylebox_override("normal")
			b.remove_theme_color_override("font_color")
	_difficulty_blurb.text = Difficulty.text(_difficulty)
	if mode == RunData.MODE_DAILY and _profile.daily_last_played == GameModeManager.daily_key():
		_mode_blurb.text += " (already played today: best %d kills)" % _profile.daily_best_kills
	_mode_button.disabled = versus or (online and not hosting)

	_ascension = clampi(_ascension, 0, _profile.ascension_unlocked)
	_ascension_box.visible = _profile.ascension_unlocked > 0
	_ascension_blurb.visible = _profile.ascension_unlocked > 0
	_ascension_value.text = str(_ascension)
	_ascension_blurb.text = MetaProgression.ascension_description(_ascension)
	_ascension_button.disabled = online and not hosting

	_seed_input.editable = mode != RunData.MODE_DAILY and (not online or hosting)

	_coop_button.text = "together as:  %s" % COOP_MODE_NAMES[_coop_mode]
	_coop_button.disabled = online and not hosting
	_host_button.disabled = online
	_join_button.disabled = online
	_code_input.editable = not online
	_ip_input.editable = not online
	_leave_button.visible = online

	if not online:
		_start_button.text = "start run"
		_start_button.disabled = false
	elif hosting:
		var others: int = _network.connected_peers.size() - 1
		_start_button.text = "start for everyone (%d joined)" % others
		_start_button.disabled = false
		var ip: String = _local_lan_ip()
		_status.text = "room code %s%s. share it, then start." % [_network.room_code, ("   ·   ip %s" % ip) if not ip.is_empty() else ""]
	else:
		_start_button.text = "waiting for the host"
		_start_button.disabled = true
		_status.text = "connected to room %s. the host starts the run." % _network.room_code


func _selected_seed() -> int:
	var text: String = _seed_input.text.strip_edges()
	if text.is_empty() or not text.is_valid_int():
		return 0
	return clampi(absi(text.to_int()), 0, 999999999)


func _on_start() -> void:
	var mode: StringName = RUN_MODES[_run_mode_index]
	if _network.is_online():
		if not _network.is_host():
			return
		_network.start_match(_coop_mode, String(mode), _ascension, _selected_seed(), String(_difficulty))
		return
	_modes.set_mode(GameModeManager.GameMode.COOP)
	_modes.run_mode = mode
	_modes.ascension = _ascension
	_modes.difficulty = _difficulty
	_modes.custom_seed = _selected_seed()
	Game.sfx(&"run_start", -6.0)
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void:
		var err: Error = get_tree().change_scene_to_file(NetworkManager.GAME_SCENE)
		if err != OK:
			push_error("failed to load the run scene: %s" % error_string(err)))


# --- panels ---------------------------------------------------------------------

func _open_armory() -> void:
	_root_panel.visible = false
	_armory.open(_profile)


func _open_progression() -> void:
	_root_panel.visible = false
	_progression.open(_profile)


func _open_settings() -> void:
	_root_panel.visible = false
	_settings_panel.open()


func _on_panel_closed() -> void:
	_root_panel.visible = true
	_backdrop.set_tint(Skins.accent(_profile.skin))
	_backdrop.show_random_boss()
	_refresh()
	_start_button.grab_focus.call_deferred()


# --- multiplayer ----------------------------------------------------------------

func _on_host() -> void:
	var err: Error = _network.host_game()
	if err != OK:
		_status.text = "could not host: %s" % error_string(err)
		return
	_refresh()


func _on_join() -> void:
	var code: String = _code_input.text.strip_edges().to_upper()
	if code.length() != NetworkManager.CODE_LENGTH:
		_status.text = "enter the %d-character room code." % NetworkManager.CODE_LENGTH
		return
	var address: String = _ip_input.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	_status.text = "connecting to %s..." % address
	var err: Error = _network.join_by_code(code, address)
	if err != OK:
		_status.text = "could not connect: %s" % error_string(err)
		return
	_host_button.disabled = true
	_join_button.disabled = true


func _on_connection_changed() -> void:
	_refresh()


func _on_connection_failed() -> void:
	_refresh()
	_status.text = "connection failed. check the code and the host's ip."


## best-effort private ipv4 address to show the host, so they can share it.
func _local_lan_ip() -> String:
	for addr: String in IP.get_local_addresses():
		if ":" in addr or addr == "127.0.0.1" or addr.begins_with("169.254."):
			continue
		if addr.begins_with("192.168.") or addr.begins_with("10."):
			return addr
		if addr.begins_with("172."):
			var parts: PackedStringArray = addr.split(".")
			if parts.size() >= 2 and parts[1].to_int() >= 16 and parts[1].to_int() <= 31:
				return addr
	return ""
