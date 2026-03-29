extends Control

signal upgrade_selected(upgrade: Dictionary)

var choices: Array[Dictionary] = []

@onready var container: VBoxContainer = $Panel/VBoxContainer
@onready var title_label: Label = $Panel/TitleLabel


func show_choices(upgrade_choices: Array[Dictionary]) -> void:
	choices = upgrade_choices
	_build_buttons()
	_animate_in()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_buttons() -> void:
	for child in container.get_children():
		child.queue_free()

	for upgrade in choices:
		var btn: Button = Button.new()
		btn.text = "%s — %s" % [upgrade.name, upgrade.description]
		btn.custom_minimum_size = Vector2(400, 50)

		btn.add_theme_color_override("font_color", Color(1, 0.9, 0.9))
		btn.add_theme_color_override("font_hover_color", Color(1, 0.3, 0.2))
		btn.add_theme_font_size_override("font_size", 16)

		var captured: Dictionary = upgrade
		btn.pressed.connect(func(): _on_choice(captured))
		container.add_child(btn)


func _animate_in() -> void:
	modulate.a = 0.0
	scale = Vector2(0.95, 0.95)
	visible = true
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
	tween.tween_property(self, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_OUT)


func _animate_out(callback: Callable) -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.tween_property(self, "scale", Vector2(1.02, 1.02), 0.1)
	tween.chain().tween_callback(func():
		visible = false
		callback.call()
	)


func _on_choice(upgrade: Dictionary) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_animate_out(func(): upgrade_selected.emit(upgrade))
