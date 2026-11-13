class_name ArmoryPanel
extends Control

# the armory: choose the three weapons you carry and the skin you wear.
# weapons and skins you don't own yet can be bought here with shards once
# their requirement is met.

signal closed
signal preview_requested(model_path: String, skin: StringName)
signal profile_changed

var _profile: PlayerProfile
var _selected_slot: int = 0
var _slots_row: HBoxContainer
var _weapon_list: VBoxContainer
var _skin_row: HFlowContainer
var _shards_label: Label
var _detail: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	visible = false

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 70)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 60)
	margin.add_theme_constant_override("margin_right", 70)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.custom_minimum_size = Vector2(820, 0)
	margin.add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var head: HBoxContainer = HBoxContainer.new()
	col.add_child(head)
	var title: Label = UiKit.label("armory", 34, UiKit.ACCENT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_shards_label = UiKit.label("", 20, UiKit.ACCENT, true)
	head.add_child(_shards_label)

	col.add_child(UiKit.label("loadout: pick a slot, then pick a weapon for it", 15, UiKit.TEXT_DIM))
	_slots_row = HBoxContainer.new()
	_slots_row.add_theme_constant_override("separation", 10)
	col.add_child(_slots_row)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 430)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_weapon_list = VBoxContainer.new()
	_weapon_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_weapon_list)

	col.add_child(UiKit.label("skin", 15, UiKit.TEXT_DIM))
	_skin_row = HFlowContainer.new()
	_skin_row.add_theme_constant_override("h_separation", 8)
	_skin_row.add_theme_constant_override("v_separation", 8)
	col.add_child(_skin_row)

	_detail = UiKit.label("", 15, UiKit.TEXT_DIM)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_detail)

	var back: Button = UiKit.button("back", 18, Vector2(180, 44))
	back.pressed.connect(_close)
	col.add_child(back)


func open(profile: PlayerProfile) -> void:
	_profile = profile
	_selected_slot = 0
	visible = true
	_rebuild()
	_preview(_profile.loadout[_selected_slot])


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	visible = false
	closed.emit()


func _rebuild() -> void:
	_shards_label.text = "%d shards" % _profile.fracture_shards
	for child: Node in _slots_row.get_children():
		child.queue_free()
	for child: Node in _weapon_list.get_children():
		child.queue_free()
	for child: Node in _skin_row.get_children():
		child.queue_free()

	for i: int in WeaponDefs.LOADOUT_SIZE:
		var id: StringName = _profile.loadout[i]
		var b: Button = UiKit.button("%d   %s" % [i + 1, WeaponDefs.display_name(id)], 18, Vector2(250, 50))
		if i == _selected_slot:
			b.add_theme_stylebox_override("normal", UiKit.box(Color(0.14, 0.2, 0.15), UiKit.ACCENT, 2, 6))
		var slot: int = i
		b.pressed.connect(func() -> void:
			_selected_slot = slot
			_rebuild()
			_preview(_profile.loadout[slot]))
		_slots_row.add_child(b)

	for id: StringName in WeaponDefs.ORDER:
		_weapon_list.add_child(_weapon_card(id))
	for id: StringName in Skins.PLAYER_SKINS:
		_skin_row.add_child(_skin_button(id))


func _weapon_card(id: StringName) -> Control:
	var def: Dictionary = WeaponDefs.CATALOG[id]
	var owned: bool = _profile.owns_weapon(id)
	var equipped_at: int = _profile.loadout.find(id)
	var footer: String = String(def.role)
	var edge: Color = UiKit.ACCENT if owned else UiKit.TEXT_DIM
	if equipped_at >= 0:
		footer += "   ·   in slot %d" % (equipped_at + 1)
		edge = UiKit.WARN
	elif owned:
		footer += "   ·   click to equip in slot %d" % (_selected_slot + 1)
	else:
		var req: String = MetaProgression.requirement_text(def.requirement)
		var met: bool = MetaProgression.is_requirement_met(_profile, String(id))
		footer += "   ·   %d shards" % int(def.cost)
		if not req.is_empty():
			footer += "   ·   needs %s%s" % [req, "" if met else " (not yet)"]
	var card: Button = UiKit.card(def.name, def.description, edge, footer)
	card.custom_minimum_size = Vector2(0, 92)
	card.mouse_entered.connect(func() -> void: _preview(id))
	card.focus_entered.connect(func() -> void: _preview(id))
	if owned:
		card.pressed.connect(func() -> void:
			_profile.set_loadout_slot(_selected_slot, id)
			_profile.save()
			Game.sfx(&"ui_select", -6.0)
			profile_changed.emit()
			_rebuild())
	else:
		card.disabled = not MetaProgression.can_unlock(_profile, String(id))
		card.pressed.connect(func() -> void:
			if MetaProgression.purchase_unlock(_profile, String(id)):
				Game.sfx(&"upgrade_pick", -4.0)
				profile_changed.emit()
				_rebuild())
	return card


func _skin_button(id: StringName) -> Control:
	var owned: bool = _profile.owns_skin(id)
	var entry: Dictionary = MetaProgression.unlock_entry("skin:%s" % String(id))
	var text: String = Skins.display_name(id)
	if not owned:
		text += "  (%d)" % int(entry.get("cost", 0))
	var b: Button = UiKit.button(text, 16, Vector2(170, 42))
	var swatch: Color = Skins.accent(id)
	b.add_theme_color_override("font_color", swatch if owned else UiKit.TEXT_DIM)
	if _profile.skin == id:
		b.add_theme_stylebox_override("normal", UiKit.box(Color(0.12, 0.14, 0.14), swatch, 2, 6))
	b.mouse_entered.connect(func() -> void:
		_preview(_profile.loadout[_selected_slot], id)
		if not owned:
			var req: String = MetaProgression.requirement_text(entry.get("requirement", ""))
			_detail.text = "%s: %s%s" % [Skins.display_name(id), entry.get("description", ""), ("   needs " + req) if not req.is_empty() else ""]
		else:
			_detail.text = "")
	if owned:
		b.pressed.connect(func() -> void:
			_profile.skin = id
			_profile.save()
			Game.sfx(&"ui_select", -6.0)
			profile_changed.emit()
			_rebuild()
			_preview(_profile.loadout[_selected_slot]))
	else:
		b.disabled = not MetaProgression.can_unlock(_profile, "skin:%s" % String(id))
		b.pressed.connect(func() -> void:
			if MetaProgression.purchase_unlock(_profile, "skin:%s" % String(id)):
				_profile.skin = id
				_profile.save()
				Game.sfx(&"upgrade_pick", -4.0)
				profile_changed.emit()
				_rebuild())
	return b


func _preview(weapon_id: StringName, skin: Variant = null) -> void:
	var use_skin: StringName = _profile.skin if skin == null else StringName(String(skin))
	preview_requested.emit("res://assets/models/grafted-brood-%s.glb" % String(weapon_id), use_skin)
