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

	var data := run_manager.data

	room_label.text = "room %d/%d" % [data.current_room_index + 1, data.total_rooms()]
	timer_label.text = _format_time(data.elapsed_time)
	enemy_label.text = "x%d" % get_tree().get_nodes_in_group("enemies").size()

	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		hp_label.text = "%d hp" % players[0].health

	# update heat bar for beam emitter
	var wm := get_node_or_null("/root/Main/Player/Head/WeaponManager") as WeaponManager
	if wm and wm.active_slot == WeaponManager.WeaponSlot.BEAM_EMITTER:
		var ratio := wm.get_beam_heat_ratio()
		var oh := wm.is_beam_overheated()
		if oh:
			weapon_label.text = "beam emitter [OVERHEAT]"
			weapon_label.add_theme_color_override("font_color", Color(1.0, 0.1, 0.0))
		elif ratio > 0.7:
			weapon_label.text = "beam emitter [%.0f%%]" % (ratio * 100)
			weapon_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.1))
		else:
			weapon_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))


static func _format_time(seconds: float) -> String:
	var mins := int(seconds) / 60
	var secs := int(seconds) % 60
	return "%d:%02d" % [mins, secs]
