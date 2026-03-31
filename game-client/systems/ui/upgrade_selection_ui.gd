extends Control

signal upgrade_selected(upgrade: Dictionary)

var choices: Array[Dictionary] = []
var _active: bool = false

@onready var container: VBoxContainer = $Panel/VBoxContainer
@onready var title_label: Label = $Panel/TitleLabel


func show_choices(upgrade_choices: Array[Dictionary]) -> void:
	choices = upgrade_choices
	_active = true
	_build_buttons()
	_animate_in()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	# keyboard shortcuts: 1/2/3 to pick upgrades
	if event is InputEventKey and event.pressed:
		var idx: int = -1
		if event.keycode == KEY_1: idx = 0
		elif event.keycode == KEY_2: idx = 1
		elif event.keycode == KEY_3: idx = 2
		if idx >= 0 and idx < choices.size():
			_on_choice(choices[idx])


func _build_buttons() -> void:
	for child in container.get_children():
		child.queue_free()

	for i in choices.size():
		var upgrade: Dictionary = choices[i]
		var btn: Button = Button.new()
		var is_cursed: bool = upgrade.get("cursed", false)
		btn.text = "[%d] %s — %s" % [i + 1, upgrade.name, upgrade.description]
		btn.custom_minimum_size = Vector2(400, 50)

		if is_cursed:
			btn.add_theme_color_override("font_color", Color(0.9, 0.3, 0.8))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 0.4, 0.9))
		else:
			btn.add_theme_color_override("font_color", Color(1, 0.9, 0.9))
			btn.add_theme_color_override("font_hover_color", Color(1, 0.3, 0.2))
		btn.add_theme_font_size_override("font_size", 16)

		var captured: Dictionary = upgrade
		btn.pressed.connect(func(): _on_choice(captured))

		# stagger animation: buttons fade in sequentially
		btn.modulate.a = 0.0
		container.add_child(btn)
		var delay: float = 0.05 * i
		var tween: Tween = btn.create_tween()
		tween.tween_interval(delay)
		tween.tween_property(btn, "modulate:a", 1.0, 0.12)

	# focus first button
	if container.get_child_count() > 0:
		(container.get_child(0) as Button).grab_focus()


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
	if not _active:
		return
	_active = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_animate_out(func(): upgrade_selected.emit(upgrade))
