class_name ProgressionUI
extends Control

# meta progression screen. shows upgrades, unlocks, and currency.
# accessed from main menu via "upgrades" button.

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
	# focus first interactive element
	close_button.call_deferred("grab_focus")


func _refresh() -> void:
	shards_label.text = "%d shards" % _profile.fracture_shards

	# stats
	var stat_lines: PackedStringArray = _profile.get_stat_summary()
	stats_label.text = " | ".join(stat_lines) if stat_lines.size() > 0 else "no runs yet"

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

		var info: Label = Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if maxed:
			info.text = "%s [max]" % entry.name
		else:
			info.text = "%s  lv%d/%d" % [entry.name, current, max_level]
		info.add_theme_font_size_override("font_size", 13)
		info.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		row.add_child(info)

		var desc: Label = Label.new()
		desc.text = entry.description
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc)

		if not maxed:
			var btn: Button = Button.new()
			btn.text = "%d shards" % cost
			btn.add_theme_font_size_override("font_size", 12)
			btn.disabled = not MetaProgression.can_purchase(_profile, id)
			var captured_id: String = id
			btn.pressed.connect(func():
				if MetaProgression.purchase(_profile, captured_id):
					_refresh()
			)
			row.add_child(btn)

		upgrade_list.add_child(row)


func _build_unlocks() -> void:
	for child in unlock_list.get_children():
		child.queue_free()

	for entry: Dictionary in MetaProgression.unlock_catalog:
		var id: String = entry.id
		var owned: bool = _profile.has_unlock(id)
		var req_met: bool = MetaProgression.is_requirement_met(_profile, id)

		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var info: Label = Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if owned:
			info.text = "%s [owned]" % entry.name
			info.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		elif not req_met:
			info.text = "%s [locked]" % entry.name
			info.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		else:
			info.text = entry.name
			info.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		info.add_theme_font_size_override("font_size", 13)
		row.add_child(info)

		var desc: Label = Label.new()
		desc.text = entry.description
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc)

		if not owned and req_met:
			var btn: Button = Button.new()
			btn.text = "%d shards" % entry.cost
			btn.add_theme_font_size_override("font_size", 12)
			btn.disabled = not MetaProgression.can_unlock(_profile, id)
			var captured_id: String = id
			btn.pressed.connect(func():
				if MetaProgression.purchase_unlock(_profile, captured_id):
					_refresh()
			)
			row.add_child(btn)
		elif not owned and not req_met:
			var req_label: Label = Label.new()
			req_label.text = entry.requirement
			req_label.add_theme_font_size_override("font_size", 10)
			req_label.add_theme_color_override("font_color", Color(0.5, 0.3, 0.3))
			row.add_child(req_label)

		unlock_list.add_child(row)
