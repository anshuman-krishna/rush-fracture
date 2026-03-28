extends Control

# persistent run hud: room counter, timer, hp, enemies remaining

var run_manager: RunManager

@onready var room_label: Label = $RoomLabel
@onready var timer_label: Label = $TimerLabel
@onready var hp_label: Label = $HpLabel
@onready var enemy_label: Label = $EnemyLabel


func bind_run_manager(manager: RunManager) -> void:
	run_manager = manager


func _process(_delta: float) -> void:
	if not run_manager or not run_manager.data:
		return

	var data := run_manager.data
	var room := data.current_room()

	room_label.text = "room %d/%d" % [data.current_room_index + 1, data.total_rooms()]
	timer_label.text = _format_time(data.elapsed_time)
	enemy_label.text = "x%d" % get_tree().get_nodes_in_group("enemies").size()

	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		hp_label.text = "%d hp" % players[0].health


static func _format_time(seconds: float) -> String:
	var mins := int(seconds) / 60
	var secs := int(seconds) % 60
	return "%d:%02d" % [mins, secs]
