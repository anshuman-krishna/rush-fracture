extends Control

# presents mutation choices after specific rooms.
# mutations have visible upsides and downsides.

signal mutation_selected(mutation: Dictionary)
signal mutation_skipped

var choices: Array[Dictionary] = []

@onready var container: VBoxContainer = $Panel/VBoxContainer
@onready var title_label: Label = $Panel/TitleLabel


func show_choices(mutation_choices: Array[Dictionary]) -> void:
	choices = mutation_choices
	_build_buttons()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_buttons() -> void:
	for child in container.get_children():
		child.queue_free()

	for mutation in choices:
		var btn := Button.new()
		btn.text = "%s — %s" % [mutation.name, mutation.description]
		btn.custom_minimum_size = Vector2(450, 50)

		btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.1))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.3, 0.0))
		btn.add_theme_font_size_override("font_size", 15)

		var captured := mutation
		btn.pressed.connect(func(): _on_choice(captured))
		container.add_child(btn)

	# skip button
	var skip := Button.new()
	skip.text = "skip — no mutation"
	skip.custom_minimum_size = Vector2(450, 40)
	skip.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	skip.add_theme_color_override("font_hover_color", Color(0.7, 0.7, 0.7))
	skip.add_theme_font_size_override("font_size", 14)
	skip.pressed.connect(_on_skip)
	container.add_child(skip)


func _on_choice(mutation: Dictionary) -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mutation_selected.emit(mutation)


func _on_skip() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mutation_skipped.emit()
