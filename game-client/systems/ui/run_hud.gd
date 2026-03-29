extends Control

# persistent run hud: room counter, timer, hp, enemies, weapon, combo

var run_manager: RunManager

@onready var room_label: Label = $RoomLabel
@onready var timer_label: Label = $TimerLabel
@onready var hp_label: Label = $HpLabel
@onready var enemy_label: Label = $EnemyLabel
@onready var weapon_label: Label = $WeaponLabel
@onready var combo_label: Label = $ComboLabel


func bind_run_manager(manager: RunManager) -> void:
	run_manager = manager


func update_weapon_display(weapon_name: String) -> void:
	weapon_label.text = weapon_name


func update_combo(multiplier: int, kill_count: int) -> void:
	if multiplier <= 1:
		combo_label.visible = false
		return
	combo_label.visible = true
	combo_label.text = "x%d  %d kills" % [multiplier, kill_count]


func _process(_delta: float) -> void:
	if not run_manager or not run_manager.data:
		return

	var data: RunData = run_manager.data

	room_label.text = "room %d/%d" % [data.current_room_index + 1, data.total_rooms()]
	timer_label.text = _format_time(data.elapsed_time)
	enemy_label.text = "x%d" % get_tree().get_nodes_in_group("enemies").size()

	var pm: PlayerManager = get_node_or_null("/root/Main/PlayerManager") as PlayerManager
	var primary: CharacterBody3D = pm.get_primary_player() if pm else null
	if not primary:
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			primary = players[0] as CharacterBody3D
	if primary:
		hp_label.text = "%d hp" % primary.health

	# update heat bar for beam emitter
	var wm: WeaponManager = pm.get_primary_weapon_manager() if pm else null
	if wm and wm.active_slot == WeaponManager.WeaponSlot.BEAM_EMITTER:
		var ratio: float = wm.get_beam_heat_ratio()
		var oh: bool = wm.is_beam_overheated()
		if oh:
			weapon_label.text = "beam emitter [OVERHEAT]"
			weapon_label.add_theme_color_override("font_color", Color(1.0, 0.1, 0.0))
		elif ratio > 0.7:
			weapon_label.text = "beam emitter [%.0f%%]" % (ratio * 100)
			weapon_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.1))
		else:
			weapon_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))


static func _format_time(seconds: float) -> String:
	var mins: int = int(seconds) / 60
	var secs: int = int(seconds) % 60
	return "%d:%02d" % [mins, secs]
