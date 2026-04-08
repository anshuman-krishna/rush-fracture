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

	# title at top
	if title_label:
		title_label.add_theme_font_size_override("font_size", 26)
		title_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.1, 1))
		title_label.text = "choose upgrade"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# upgrade cards
	for i in choices.size():
		var upgrade: Dictionary = choices[i]
		var is_cursed: bool = upgrade.get("cursed", false)

		var card: PanelContainer = PanelContainer.new()
		var card_style: StyleBoxFlat = StyleBoxFlat.new()
		if is_cursed:
			card_style.bg_color = Color(0.15, 0.06, 0.12, 0.9)
			card_style.border_color = Color(0.9, 0.3, 0.8, 0.6)
		else:
			card_style.bg_color = Color(0.08, 0.08, 0.1, 0.9)
			card_style.border_color = Color(1.0, 0.3, 0.15, 0.4)
		card_style.border_width_left = 2
		card_style.border_width_right = 2
		card_style.border_width_top = 2
		card_style.border_width_bottom = 2
		card_style.corner_radius_top_left = 4
		card_style.corner_radius_top_right = 4
		card_style.corner_radius_bottom_left = 4
		card_style.corner_radius_bottom_right = 4
		card_style.content_margin_left = 12
		card_style.content_margin_right = 12
		card_style.content_margin_top = 10
		card_style.content_margin_bottom = 10
		card.add_theme_stylebox_override("panel", card_style)

		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# left: info
		var info_col: VBoxContainer = VBoxContainer.new()
		info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_col.add_theme_constant_override("separation", 4)

		var name_label: Label = Label.new()
		name_label.text = "[%d] %s" % [i + 1, upgrade.name]
		name_label.add_theme_font_size_override("font_size", 20)
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
				Color(0.7, 0.3, 0.6) if is_cursed else Color(0.4, 0.9, 0.4))
			info_col.add_child(hint_label)

		row.add_child(info_col)

		# right: select button — well highlighted
		var select_btn: Button = Button.new()
		select_btn.text = "select"
		select_btn.custom_minimum_size = Vector2(110, 54)
		select_btn.add_theme_font_size_override("font_size", 18)

		var btn_style: StyleBoxFlat = StyleBoxFlat.new()
		if is_cursed:
			btn_style.bg_color = Color(0.4, 0.1, 0.3, 0.8)
			select_btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.9))
			select_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.7, 1.0))
		else:
			btn_style.bg_color = Color(0.35, 0.08, 0.04, 0.8)
			select_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2))
			select_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.6, 0.4))
		btn_style.corner_radius_top_left = 3
		btn_style.corner_radius_top_right = 3
		btn_style.corner_radius_bottom_left = 3
		btn_style.corner_radius_bottom_right = 3
		select_btn.add_theme_stylebox_override("normal", btn_style)

		var btn_hover: StyleBoxFlat = btn_style.duplicate()
		btn_hover.bg_color = btn_hover.bg_color.lightened(0.15)
		select_btn.add_theme_stylebox_override("hover", btn_hover)

		select_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var captured: Dictionary = upgrade
		select_btn.pressed.connect(func(): _on_choice(captured))
		row.add_child(select_btn)

		card.add_child(row)

		# stagger animation
		card.modulate.a = 0.0
		container.add_child(card)
		var delay: float = 0.06 * i
		var tween: Tween = card.create_tween()
		tween.tween_interval(delay)
		tween.tween_property(card, "modulate:a", 1.0, 0.12)

	# focus first select button
	_focus_first_button()


func _focus_first_button() -> void:
	await get_tree().process_frame
	if container.get_child_count() > 0:
		var first_card: PanelContainer = container.get_child(0) as PanelContainer
		if first_card and first_card.get_child_count() > 0:
			var row: HBoxContainer = first_card.get_child(0) as HBoxContainer
			if row and row.get_child_count() > 1:
				(row.get_child(1) as Button).grab_focus()


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
