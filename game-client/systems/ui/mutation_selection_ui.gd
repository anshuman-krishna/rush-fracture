extends Control

# mutation choices after specific rooms. visible upsides and downsides.

signal mutation_selected(mutation: Dictionary)
signal mutation_skipped

var choices: Array[Dictionary] = []
var _chosen: bool = false

@onready var container: VBoxContainer = $Panel/VBoxContainer
@onready var title_label: Label = $Panel/TitleLabel


func show_choices(mutation_choices: Array[Dictionary]) -> void:
	choices = mutation_choices
	_chosen = false
	_build_buttons()
	_animate_in()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _chosen:
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

	# title at top
	if title_label:
		title_label.add_theme_font_size_override("font_size", 26)
		title_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0, 1))
		title_label.text = "choose mutation"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# mutation cards
	for i in choices.size():
		var mutation: Dictionary = choices[i]

		var card: PanelContainer = PanelContainer.new()
		var card_style: StyleBoxFlat = StyleBoxFlat.new()
		card_style.bg_color = Color(0.1, 0.07, 0.04, 0.9)
		card_style.border_color = Color(1.0, 0.5, 0.0, 0.4)
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

		var info_col: VBoxContainer = VBoxContainer.new()
		info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_col.add_theme_constant_override("separation", 4)

		var name_label: Label = Label.new()
		name_label.text = "[%d] %s" % [i + 1, mutation.name]
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.1))
		info_col.add_child(name_label)

		var desc_label: Label = Label.new()
		desc_label.text = mutation.description
		desc_label.add_theme_font_size_override("font_size", 14)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_col.add_child(desc_label)

		# upside/downside
		var upside: String = mutation.get("upside", "")
		var downside: String = mutation.get("downside", "")
		if upside.length() > 0 or downside.length() > 0:
			var hint_row: HBoxContainer = HBoxContainer.new()
			hint_row.add_theme_constant_override("separation", 12)
			if upside.length() > 0:
				var up_lbl: Label = Label.new()
				up_lbl.text = upside
				up_lbl.add_theme_font_size_override("font_size", 13)
				up_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
				hint_row.add_child(up_lbl)
			if downside.length() > 0:
				var down_lbl: Label = Label.new()
				down_lbl.text = downside
				down_lbl.add_theme_font_size_override("font_size", 13)
				down_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25))
				hint_row.add_child(down_lbl)
			info_col.add_child(hint_row)

		row.add_child(info_col)

		# select button — highlighted
		var select_btn: Button = Button.new()
		select_btn.text = "select"
		select_btn.custom_minimum_size = Vector2(110, 54)
		select_btn.add_theme_font_size_override("font_size", 18)
		select_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.1))
		select_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.8, 0.3))

		var btn_style: StyleBoxFlat = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.3, 0.15, 0.02, 0.8)
		btn_style.corner_radius_top_left = 3
		btn_style.corner_radius_top_right = 3
		btn_style.corner_radius_bottom_left = 3
		btn_style.corner_radius_bottom_right = 3
		select_btn.add_theme_stylebox_override("normal", btn_style)

		var btn_hover: StyleBoxFlat = btn_style.duplicate()
		btn_hover.bg_color = btn_hover.bg_color.lightened(0.15)
		select_btn.add_theme_stylebox_override("hover", btn_hover)

		select_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var captured: Dictionary = mutation
		select_btn.pressed.connect(func(): _on_choice(captured))
		row.add_child(select_btn)

		card.add_child(row)

		# stagger fade
		card.modulate.a = 0.0
		container.add_child(card)
		var delay: float = i * 0.06
		var tween: Tween = card.create_tween()
		tween.tween_interval(delay)
		tween.tween_property(card, "modulate:a", 1.0, 0.12)

	# skip button at bottom
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	container.add_child(spacer)

	var skip: Button = Button.new()
	skip.text = "skip — no mutation"
	skip.custom_minimum_size = Vector2(0, 44)
	skip.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	skip.add_theme_color_override("font_hover_color", Color(0.75, 0.75, 0.75))
	skip.add_theme_font_size_override("font_size", 16)
	skip.pressed.connect(_on_skip)
	container.add_child(skip)

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


func _on_choice(mutation: Dictionary) -> void:
	if _chosen:
		return
	_chosen = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_animate_out(func(): mutation_selected.emit(mutation))


func _on_skip() -> void:
	if _chosen:
		return
	_chosen = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_animate_out(func(): mutation_skipped.emit())
