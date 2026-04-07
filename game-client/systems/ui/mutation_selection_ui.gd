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

	if title_label:
		title_label.add_theme_font_size_override("font_size", 22)
		title_label.text = "choose mutation"

	for i in choices.size():
		var mutation: Dictionary = choices[i]

		# row: info left, select button right
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var info_col: VBoxContainer = VBoxContainer.new()
		info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_col.add_theme_constant_override("separation", 3)

		var name_label: Label = Label.new()
		name_label.text = "[%d] %s" % [i + 1, mutation.name]
		name_label.add_theme_font_size_override("font_size", 18)
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
			hint_row.add_theme_constant_override("separation", 8)
			if upside.length() > 0:
				var up_lbl: Label = Label.new()
				up_lbl.text = upside
				up_lbl.add_theme_font_size_override("font_size", 13)
				up_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
				hint_row.add_child(up_lbl)
			if downside.length() > 0:
				var down_lbl: Label = Label.new()
				down_lbl.text = downside
				down_lbl.add_theme_font_size_override("font_size", 13)
				down_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
				hint_row.add_child(down_lbl)
			info_col.add_child(hint_row)

		row.add_child(info_col)

		# select button
		var select_btn: Button = Button.new()
		select_btn.text = "select"
		select_btn.custom_minimum_size = Vector2(100, 50)
		select_btn.add_theme_font_size_override("font_size", 17)
		select_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.1))
		select_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.8, 0.3))
		select_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var captured: Dictionary = mutation
		select_btn.pressed.connect(func(): _on_choice(captured))
		row.add_child(select_btn)

		container.add_child(row)

		# stagger fade
		row.modulate.a = 0.0
		var delay: float = i * 0.05
		get_tree().create_timer(delay).timeout.connect(func():
			if is_instance_valid(row):
				var t: Tween = create_tween()
				t.tween_property(row, "modulate:a", 1.0, 0.1)
		)

		if i < choices.size() - 1:
			var sep: HSeparator = HSeparator.new()
			container.add_child(sep)

	# skip button
	var skip: Button = Button.new()
	skip.text = "skip — no mutation"
	skip.custom_minimum_size = Vector2(0, 44)
	skip.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	skip.add_theme_color_override("font_hover_color", Color(0.75, 0.75, 0.75))
	skip.add_theme_font_size_override("font_size", 16)
	skip.pressed.connect(_on_skip)
	container.add_child(skip)

	# focus first select button
	if container.get_child_count() > 0:
		var first_row: Node = container.get_child(0)
		if first_row is HBoxContainer and first_row.get_child_count() > 1:
			first_row.get_child(1).call_deferred("grab_focus")


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
