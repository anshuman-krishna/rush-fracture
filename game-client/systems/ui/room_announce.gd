extends Control

# brief room intro and clear announcements with scale/fade animations.

@onready var announce_label: Label = $AnnounceLabel

var _active_tween: Tween


func show_room_enter(room: RunData.RoomData, room_number: int, total: int) -> void:
	var type_name: String = RoomDefinitions.type_to_string(room.type)
	announce_label.text = "%s — %d/%d" % [type_name, room_number, total]
	announce_label.remove_theme_color_override("font_color")
	_slide_in(1.2)


func show_room_clear() -> void:
	announce_label.text = "cleared"
	announce_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 1))
	_slide_in(0.6, true)


func show_boss_warning() -> void:
	_kill_tween()
	announce_label.text = "WARNING — BOSS INCOMING"
	announce_label.add_theme_color_override("font_color", Color(1, 0.05, 0.0, 1))
	announce_label.modulate.a = 0.0
	announce_label.scale = Vector2.ONE
	visible = true

	_active_tween = create_tween()
	for i in 3:
		_active_tween.tween_property(announce_label, "modulate:a", 1.0, 0.15)
		_active_tween.tween_property(announce_label, "modulate:a", 0.2, 0.15)
	_active_tween.tween_property(announce_label, "modulate:a", 1.0, 0.1)
	_active_tween.tween_interval(0.8)
	_active_tween.tween_property(announce_label, "modulate:a", 0.0, 0.4)
	_active_tween.tween_callback(func():
		visible = false
		announce_label.remove_theme_color_override("font_color")
	)


func show_boss_defeated() -> void:
	_kill_tween()
	announce_label.text = "BOSS DEFEATED"
	announce_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3, 1))
	announce_label.pivot_offset = announce_label.size / 2
	announce_label.scale = Vector2(0.5, 0.5)
	announce_label.modulate.a = 0.0
	visible = true

	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.tween_property(announce_label, "modulate:a", 1.0, 0.2)
	_active_tween.tween_property(announce_label, "scale", Vector2(1.1, 1.1), 0.25).set_ease(Tween.EASE_OUT)
	_active_tween.chain().tween_property(announce_label, "scale", Vector2.ONE, 0.15)
	_active_tween.tween_interval(1.2)
	_active_tween.tween_property(announce_label, "modulate:a", 0.0, 0.5)
	_active_tween.tween_callback(func():
		visible = false
		announce_label.remove_theme_color_override("font_color")
	)


func show_fracture(fracture_name: String) -> void:
	announce_label.text = "fracture — %s" % fracture_name
	announce_label.add_theme_color_override("font_color", Color(0.9, 0.2, 1.0, 1))
	_slide_in(1.2, true)


func _slide_in(hold_time: float, auto_clear_color: bool = false) -> void:
	_kill_tween()
	announce_label.pivot_offset = announce_label.size / 2
	announce_label.modulate.a = 0.0
	announce_label.scale = Vector2(0.9, 0.9)
	visible = true

	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.tween_property(announce_label, "modulate:a", 1.0, 0.12)
	_active_tween.tween_property(announce_label, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_OUT)
	_active_tween.chain().tween_interval(hold_time)
	_active_tween.tween_property(announce_label, "modulate:a", 0.0, 0.3)
	_active_tween.tween_callback(func():
		visible = false
		if auto_clear_color:
			announce_label.remove_theme_color_override("font_color")
	)


func _kill_tween() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
