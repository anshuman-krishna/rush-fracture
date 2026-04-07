class_name ProgressionUI
extends Control

# meta progression screen. shows upgrades, unlocks, and currency.

signal closed

var _profile: PlayerProfile

@onready var title_label: Label = $Panel/TitleLabel
@onready var shards_label: Label = $Panel/ShardsLabel
@onready var upgrade_list: VBoxContainer = $Panel/ScrollContainer/UpgradeList
@onready var unlock_list: VBoxContainer = $Panel/ScrollContainer2/UnlockList
@onready var close_button: Button = $Panel/CloseButton
@onready var stats_label: Label = $Panel/StatsLabel


func _ready() -> void:
	visible = false
	close_button.pressed.connect(_close)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	visible = false
	closed.emit()


func show_progression() -> void:
	_profile = PlayerProfile.load_profile()
	_refresh()
	visible = true
	close_button.call_deferred("grab_focus")


func _refresh() -> void:
	shards_label.text = "%d shards" % _profile.fracture_shards
	shards_label.add_theme_font_size_override("font_size", 18)

	var stat_lines: PackedStringArray = _profile.get_stat_summary()
	stats_label.text = " | ".join(stat_lines) if stat_lines.size() > 0 else "no runs yet"
	stats_label.add_theme_font_size_override("font_size", 14)

	_build_upgrades()
	_build_unlocks()


func _build_upgrades() -> void:
	for child in upgrade_list.get_children():
		child.queue_free()

	for entry: Dictionary in MetaProgression.meta_catalog:
		var id: String = entry.id
		var current: int = _profile.get_meta_level(id)
		var max_level: int = entry.max_level
		var cost: int = MetaProgression.get_upgrade_cost(id, current)
		var maxed: bool = current >= max_level

		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 10)

		# info column: name + description
		var info_col: VBoxContainer = VBoxContainer.new()
		info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_col.add_theme_constant_override("separation", 2)

		var name_lbl: Label = Label.new()
		if maxed:
			name_lbl.text = "%s [max]" % entry.name
			name_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		else:
			name_lbl.text = "%s  lv%d/%d" % [entry.name, current, max_level]
			name_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
		name_lbl.add_theme_font_size_override("font_size", 16)
		info_col.add_child(name_lbl)

		var desc: Label = Label.new()
		desc.text = entry.description
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_col.add_child(desc)

		row.add_child(info_col)

		if not maxed:
			var btn: Button = Button.new()
			btn.text = "upgrade — %d shards" % cost
			btn.custom_minimum_size = Vector2(160, 38)
			btn.add_theme_font_size_override("font_size", 14)
			btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var can_buy: bool = MetaProgression.can_purchase(_profile, id)
			btn.disabled = not can_buy
			if can_buy:
				btn.add_theme_color_override("font_color", Color(1.0, 0.7, 0.15))
				btn.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.3))
			else:
				btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
			var captured_id: String = id
			btn.pressed.connect(func():
				if MetaProgression.purchase(_profile, captured_id):
					_refresh()
			)
			row.add_child(btn)

		upgrade_list.add_child(row)

		# separator
		var sep: HSeparator = HSeparator.new()
		upgrade_list.add_child(sep)


func _build_unlocks() -> void:
	for child in unlock_list.get_children():
		child.queue_free()

	for entry: Dictionary in MetaProgression.unlock_catalog:
		var id: String = entry.id
		var owned: bool = _profile.has_unlock(id)
		var req_met: bool = MetaProgression.is_requirement_met(_profile, id)

		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 10)

		var info_col: VBoxContainer = VBoxContainer.new()
		info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_col.add_theme_constant_override("separation", 2)

		var name_lbl: Label = Label.new()
		if owned:
			name_lbl.text = "%s [owned]" % entry.name
			name_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		elif not req_met:
			name_lbl.text = "%s [locked]" % entry.name
			name_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		else:
			name_lbl.text = entry.name
			name_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
		name_lbl.add_theme_font_size_override("font_size", 16)
		info_col.add_child(name_lbl)

		var desc: Label = Label.new()
		desc.text = entry.description
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_col.add_child(desc)

		row.add_child(info_col)

		if not owned and req_met:
			var btn: Button = Button.new()
			btn.text = "unlock — %d shards" % entry.cost
			btn.custom_minimum_size = Vector2(160, 38)
			btn.add_theme_font_size_override("font_size", 14)
			btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var can_buy: bool = MetaProgression.can_unlock(_profile, id)
			btn.disabled = not can_buy
			if can_buy:
				btn.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
				btn.add_theme_color_override("font_hover_color", Color(0.5, 1.0, 1.0))
			else:
				btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
			var captured_id: String = id
			btn.pressed.connect(func():
				if MetaProgression.purchase_unlock(_profile, captured_id):
					_refresh()
			)
			row.add_child(btn)
		elif not owned and not req_met:
			var req_label: Label = Label.new()
			req_label.text = entry.requirement
			req_label.add_theme_font_size_override("font_size", 12)
			req_label.add_theme_color_override("font_color", Color(0.5, 0.3, 0.3))
			req_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(req_label)

		unlock_list.add_child(row)

		var sep: HSeparator = HSeparator.new()
		unlock_list.add_child(sep)
