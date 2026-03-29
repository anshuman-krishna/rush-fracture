extends Control

# main menu — entry point. aggressive, minimal.
# supports solo play and multiplayer host/join.

@onready var title_label: Label = $Panel/TitleLabel
@onready var tagline_label: Label = $Panel/TaglineLabel
@onready var start_button: Button = $Panel/StartButton
@onready var best_stats_label: Label = $Panel/BestStatsLabel
@onready var quit_button: Button = $Panel/QuitButton
@onready var host_button: Button = $Panel/HostButton
@onready var join_button: Button = $Panel/JoinButton
@onready var ip_input: LineEdit = $Panel/IpInput
@onready var status_label: Label = $Panel/StatusLabel

var _network_manager: NetworkManager


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	start_button.pressed.connect(_on_start)
	quit_button.pressed.connect(_on_quit)
	host_button.pressed.connect(_on_host)
	join_button.pressed.connect(_on_join)
	start_button.grab_focus()
	_show_best_stats()
	_animate_in()

	# create network manager as autoload-like node
	_network_manager = NetworkManager.new()
	_network_manager.name = "NetworkManager"
	get_tree().root.add_child(_network_manager)

	_network_manager.connection_succeeded.connect(_on_connection_succeeded)
	_network_manager.connection_failed.connect(_on_connection_failed)


func _on_start() -> void:
	# solo mode — clean up network manager if not connected
	if _network_manager and not _network_manager.is_online():
		_network_manager.queue_free()
	_animate_out(func():
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)


func _on_host() -> void:
	status_label.text = "starting server..."
	status_label.visible = true
	var err: Error = _network_manager.host_game()
	if err != OK:
		status_label.text = "failed to host: %s" % error_string(err)
		return
	status_label.text = "hosting — waiting for players..."
	join_button.disabled = true
	host_button.disabled = true
	# host can start immediately
	start_button.text = "start run (host)"


func _on_join() -> void:
	var ip: String = ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	status_label.text = "connecting to %s..." % ip
	status_label.visible = true
	var err: Error = _network_manager.join_game(ip)
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
	status_label.text = "connection failed"
	host_button.disabled = false
	join_button.disabled = false


func _on_quit() -> void:
	if _network_manager:
		_network_manager.disconnect_game()
	get_tree().quit()


func _show_best_stats() -> void:
	var stats: BestStats = BestStats.load_stats()
	if stats.best_kills <= 0 and stats.best_combo <= 0:
		best_stats_label.visible = false
		return

	var lines: PackedStringArray = PackedStringArray()
	if stats.best_kills > 0:
		lines.append("best kills: %d" % stats.best_kills)
	if stats.best_combo > 0:
		lines.append("best combo: %d" % stats.best_combo)
	if stats.best_time > 0:
		var m: int = int(stats.best_time) / 60
		var s: int = int(stats.best_time) % 60
		lines.append("best time: %d:%02d" % [m, s])
	if stats.runs_completed > 0:
		lines.append("runs completed: %d" % stats.runs_completed)

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
