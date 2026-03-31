extends Control

# persistent run hud: room counter, timer, hp, enemies, weapon, combo, mode

var run_manager: RunManager
var pvp_manager: PvPManager

var _player_manager: PlayerManager
var _primary_player: CharacterBody3D
var _weapon_manager: WeaponManager
var _update_timer: float = 0.0

@onready var room_label: Label = $RoomLabel
@onready var timer_label: Label = $TimerLabel
@onready var hp_label: Label = $HpLabel
@onready var enemy_label: Label = $EnemyLabel
@onready var weapon_label: Label = $WeaponLabel
@onready var combo_label: Label = $ComboLabel
@onready var mode_label: Label = $ModeLabel


func bind_run_manager(manager: RunManager) -> void:
	run_manager = manager


func bind_pvp(manager: PvPManager) -> void:
	pvp_manager = manager


func bind_player(player: CharacterBody3D, wm: WeaponManager) -> void:
	_primary_player = player
	_weapon_manager = wm


func update_weapon_display(weapon_name: String) -> void:
	if weapon_label:
		weapon_label.text = weapon_name
		weapon_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))


func update_combo(multiplier: int, kill_count: int) -> void:
	if not combo_label:
		return
	if multiplier <= 1:
		combo_label.visible = false
		return
	combo_label.visible = true
	combo_label.text = "x%d  %d kills" % [multiplier, kill_count]


func _process(delta: float) -> void:
	if not run_manager or not run_manager.data:
		return

	var data: RunData = run_manager.data

	room_label.text = "room %d/%d" % [data.current_room_index + 1, data.total_rooms()]
	timer_label.text = _format_time(data.elapsed_time)

	# throttle expensive lookups
	_update_timer += delta
	if _update_timer >= 0.1:
		_update_timer = 0.0
		enemy_label.text = "x%d" % get_tree().get_nodes_in_group("enemies").size()
		_update_mode_display()

	# resolve player refs if missing
	if not _primary_player or not is_instance_valid(_primary_player):
		_resolve_refs()

	if _primary_player and is_instance_valid(_primary_player):
		hp_label.text = "%d hp" % _primary_player.health

	# beam emitter heat display
	if _weapon_manager and is_instance_valid(_weapon_manager):
		if _weapon_manager.active_slot == WeaponManager.WeaponSlot.BEAM_EMITTER:
			var ratio: float = _weapon_manager.get_beam_heat_ratio()
			var oh: bool = _weapon_manager.is_beam_overheated()
			if oh:
				weapon_label.text = "beam emitter [OVERHEAT]"
				weapon_label.add_theme_color_override("font_color", Color(1.0, 0.1, 0.0))
			elif ratio > 0.7:
				weapon_label.text = "beam emitter [%.0f%%]" % (ratio * 100)
				weapon_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.1))
			else:
				weapon_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))


func _resolve_refs() -> void:
	if not _player_manager:
		_player_manager = get_node_or_null("/root/Main/PlayerManager") as PlayerManager
	if _player_manager:
		_primary_player = _player_manager.get_primary_player()
		_weapon_manager = _player_manager.get_primary_weapon_manager()


func _update_mode_display() -> void:
	if not mode_label:
		return

	var gm: GameModeManager = get_node_or_null("/root/GameModeManager") as GameModeManager
	if not gm or gm.current_mode == GameModeManager.GameMode.COOP:
		mode_label.visible = false
		return

	mode_label.visible = true
	if pvp_manager and pvp_manager.is_active():
		mode_label.text = "pvp encounter"
		mode_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.1))
	else:
		mode_label.text = gm.get_mode_name()
		mode_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))


static func _format_time(seconds: float) -> String:
	var mins: int = int(seconds) / 60
	var secs: int = int(seconds) % 60
	return "%d:%02d" % [mins, secs]
