extends Control

# brief room intro and clear announcements

@onready var announce_label: Label = $AnnounceLabel


func show_room_enter(room: RunData.RoomData, room_number: int, total: int) -> void:
	var type_name := RoomDefinitions.type_to_string(room.type)
	announce_label.text = "%s — %d/%d" % [type_name, room_number, total]
	announce_label.modulate.a = 1.0
	visible = true

	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(announce_label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): visible = false)


func show_room_clear() -> void:
	announce_label.text = "cleared"
	announce_label.modulate.a = 1.0
	visible = true

	var tween := create_tween()
	tween.tween_interval(0.8)
	tween.tween_property(announce_label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): visible = false)


func show_fracture(fracture_name: String) -> void:
	announce_label.text = "fracture — %s" % fracture_name
	announce_label.modulate.a = 1.0
	visible = true

	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(announce_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): visible = false)
