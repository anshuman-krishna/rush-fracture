extends Control

# presents mutation choices after specific rooms.
# mutations have visible upsides and downsides.

signal mutation_selected(mutation: Dictionary)
signal mutation_skipped

var choices: Array[Dictionary] = []
var _active: bool = false

@onready var container: VBoxContainer = $Panel/VBoxContainer
@onready var title_label: Label = $Panel/TitleLabel


func show_choices(mutation_choices: Array[Dictionary]) -> void:
	choices = mutation_choices
	_active = false
	_build_buttons()
	_animate_in()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _active:
		return
	if event is InputEventKey and event.pressed:
		var idx: int = -1
		match event.keycode:
			KEY_1: idx = 0
			KEY_2: idx = 1
			KEY_3: idx = 2
		if idx >= 0 and idx < choices.size():
			_on_choice(choices[idx])
		elif event.keycode == KEY_ESCAPE or (idx == choices.size()):
			_on_skip()


func _build_buttons() -> void:
	for child in container.get_children():
		child.queue_free()

	for i in choices.size():
		var mutation: Dictionary = choices[i]
		var btn: Button = Button.new()
		btn.text = "[%d] %s — %s" % [i + 1, mutation.name, mutation.description]
		btn.custom_minimum_size = Vector2(450, 50)

		btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.1))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.3, 0.0))
		btn.add_theme_font_size_override("font_size", 15)

		var captured: Dictionary = mutation
		btn.pressed.connect(func(): _on_choice(captured))
		container.add_child(btn)

		# staggered fade
		btn.modulate.a = 0.0
		var delay: float = i * 0.05
		get_tree().create_timer(delay).timeout.connect(func():
			if is_instance_valid(btn):
				var t: Tween = create_tween()
				t.tween_property(btn, "modulate:a", 1.0, 0.1)
		)

	# skip button
	var skip: Button = Button.new()
	skip.text = "[%d] skip — no mutation" % (choices.size() + 1)
	skip.custom_minimum_size = Vector2(450, 40)
	skip.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	skip.add_theme_color_override("font_hover_color", Color(0.7, 0.7, 0.7))
	skip.add_theme_font_size_override("font_size", 14)
	skip.pressed.connect(_on_skip)
	container.add_child(skip)

	# focus first button
	if container.get_child_count() > 0:
		container.get_child(0).call_deferred("grab_focus")


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


func _on_choice(mutation: Dictionary) -> void:
	if _active:
		return
	_active = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_animate_out(func(): mutation_selected.emit(mutation))


func _on_skip() -> void:
	if _active:
		return
	_active = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_animate_out(func(): mutation_skipped.emit())
