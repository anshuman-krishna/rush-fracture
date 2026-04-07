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

	if title_label:
		title_label.add_theme_font_size_override("font_size", 22)
		title_label.text = "choose upgrade"

	for i in choices.size():
		var upgrade: Dictionary = choices[i]
		var is_cursed: bool = upgrade.get("cursed", false)

		# outer row: info on left, select button on right
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# left side: name + description + hint stacked
		var info_col: VBoxContainer = VBoxContainer.new()
		info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_col.add_theme_constant_override("separation", 3)

		var name_label: Label = Label.new()
		name_label.text = "[%d] %s" % [i + 1, upgrade.name]
		name_label.add_theme_font_size_override("font_size", 19)
		if is_cursed:
			name_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.8))
		else:
			name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.9))
		info_col.add_child(name_label)

		var desc_label: Label = Label.new()
		desc_label.text = upgrade.description
		desc_label.add_theme_font_size_override("font_size", 14)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_col.add_child(desc_label)

		# stat hint
		var hint: String = _build_hint(upgrade)
		if hint.length() > 0:
			var hint_label: Label = Label.new()
			hint_label.text = hint
			hint_label.add_theme_font_size_override("font_size", 13)
			hint_label.add_theme_color_override("font_color",
				Color(0.7, 0.3, 0.6) if is_cursed else Color(0.5, 0.8, 0.5))
			info_col.add_child(hint_label)

		row.add_child(info_col)

		# select button on right
		var select_btn: Button = Button.new()
		select_btn.text = "select"
		select_btn.custom_minimum_size = Vector2(100, 50)
		select_btn.add_theme_font_size_override("font_size", 17)
		if is_cursed:
			select_btn.add_theme_color_override("font_color", Color(0.9, 0.3, 0.8))
			select_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.4, 0.9))
		else:
			select_btn.add_theme_color_override("font_color", Color(1, 0.3, 0.15))
			select_btn.add_theme_color_override("font_hover_color", Color(1, 0.5, 0.3))
		select_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var captured: Dictionary = upgrade
		select_btn.pressed.connect(func(): _on_choice(captured))
		row.add_child(select_btn)

		# stagger animation
		row.modulate.a = 0.0
		container.add_child(row)
		var delay: float = 0.05 * i
		var tween: Tween = row.create_tween()
		tween.tween_interval(delay)
		tween.tween_property(row, "modulate:a", 1.0, 0.12)

		# separator between upgrades
		if i < choices.size() - 1:
			var sep: HSeparator = HSeparator.new()
			container.add_child(sep)

	# focus first select button
	if container.get_child_count() > 0:
		var first_row: HBoxContainer = container.get_child(0) as HBoxContainer
		if first_row and first_row.get_child_count() > 1:
			(first_row.get_child(1) as Button).grab_focus()


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


func _build_hint(upgrade: Dictionary) -> String:
	var stat: String = upgrade.get("stat", "")
	var modifier: float = upgrade.get("modifier", 0.0)
	var mode: String = upgrade.get("apply_mode", "")
	if stat.is_empty() or modifier == 0.0:
		return ""
	if mode == "special":
		return ""
	if mode == "multiply":
		var pct: int = int((modifier - 1.0) * 100)
		if pct == 0:
			return ""
		var pct_sign: String = "+" if pct > 0 else ""
		return "%s%d%% %s" % [pct_sign, pct, stat.replace("_", " ")]
	var sign: String = "+" if modifier > 0 else ""
	return "%s%s %s" % [sign, str(modifier), stat.replace("_", " ")]
