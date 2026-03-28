extends Control

signal upgrade_selected(upgrade: Dictionary)

var choices: Array[Dictionary] = []

@onready var container: VBoxContainer = $Panel/VBoxContainer
@onready var title_label: Label = $Panel/TitleLabel


func show_choices(upgrade_choices: Array[Dictionary]) -> void:
	choices = upgrade_choices
	_build_buttons()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_buttons() -> void:
	for child in container.get_children():
		child.queue_free()

	for upgrade in choices:
		var btn := Button.new()
		btn.text = "%s — %s" % [upgrade.name, upgrade.description]
		btn.custom_minimum_size = Vector2(400, 50)

		btn.add_theme_color_override("font_color", Color(1, 0.9, 0.9))
		btn.add_theme_color_override("font_hover_color", Color(1, 0.3, 0.2))
		btn.add_theme_font_size_override("font_size", 16)

		var captured := upgrade
		btn.pressed.connect(func(): _on_choice(captured))
		container.add_child(btn)


func _on_choice(upgrade: Dictionary) -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	upgrade_selected.emit(upgrade)
