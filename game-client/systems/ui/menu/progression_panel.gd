class_name ProgressionPanel
extends Control

# the shard shop and record book: permanent upgrades, unlocks (weapon
# variants, perks, cosmetics), achievements, and lifetime stats.

signal closed
signal profile_changed

const TABS: Array[String] = ["upgrades", "unlocks", "achievements", "stats"]

var _profile: PlayerProfile
var _tab: String = "upgrades"
var _tab_row: HBoxContainer
var _list: VBoxContainer
var _shards_label: Label


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
	panel.custom_minimum_size = Vector2(860, 0)
	margin.add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var head: HBoxContainer = HBoxContainer.new()
	col.add_child(head)
	var title: Label = UiKit.label("progression", 34, UiKit.ACCENT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_shards_label = UiKit.label("", 20, UiKit.ACCENT, true)
	head.add_child(_shards_label)

	_tab_row = HBoxContainer.new()
	_tab_row.add_theme_constant_override("separation", 8)
	col.add_child(_tab_row)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 560)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)

	var back: Button = UiKit.button("back", 18, Vector2(180, 44))
	back.pressed.connect(_close)
	col.add_child(back)


func open(profile: PlayerProfile) -> void:
	_profile = profile
	visible = true
	_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	visible = false
	closed.emit()


func _rebuild() -> void:
	_shards_label.text = "%d shards" % _profile.fracture_shards
	for child: Node in _tab_row.get_children():
		child.queue_free()
	for child: Node in _list.get_children():
		child.queue_free()

	for name: String in TABS:
		var b: Button = UiKit.button(name, 17, Vector2(170, 42))
		if name == _tab:
			b.add_theme_stylebox_override("normal", UiKit.box(Color(0.14, 0.2, 0.15), UiKit.ACCENT, 2, 6))
		var tab_name: String = name
		b.pressed.connect(func() -> void:
			_tab = tab_name
			_rebuild())
		_tab_row.add_child(b)

	match _tab:
		"upgrades": _build_upgrades()
		"unlocks": _build_unlocks()
		"achievements": _build_achievements()
		"stats": _build_stats()


func _build_upgrades() -> void:
	for entry: Dictionary in MetaProgression.META_CATALOG:
		var level: int = _profile.get_meta_level(entry.id)
		var max_level: int = int(entry.max_level)
		var maxed: bool = level >= max_level
		var cost: int = MetaProgression.get_upgrade_cost(entry.id, level)
		var footer: String = "level %d / %d" % [level, max_level]
		footer += "   ·   maxed" if maxed else "   ·   next: %d shards" % cost
		var card: Button = UiKit.card(entry.name, entry.description, UiKit.WARN if maxed else UiKit.ACCENT, footer)
		card.custom_minimum_size = Vector2(0, 84)
		card.disabled = not MetaProgression.can_purchase(_profile, entry.id)
		var id: String = entry.id
		card.pressed.connect(func() -> void:
			if MetaProgression.purchase(_profile, id):
				Game.sfx(&"upgrade_pick", -4.0)
				profile_changed.emit()
				_rebuild())
		_list.add_child(card)


func _build_unlocks() -> void:
	var last_category: String = ""
	for entry: Dictionary in MetaProgression.unlock_catalog:
		var category: String = entry.category
		# weapons and skins are bought in the armory, next to their previews
		if category == "weapon" or category == "skin":
			continue
		if category != last_category:
			last_category = category
			_list.add_child(UiKit.label(category.replace("_", " ") + "s", 16, UiKit.TEXT_DIM, true))
		var owned: bool = _profile.has_unlock(entry.id)
		var req: String = MetaProgression.requirement_text(entry.get("requirement", ""))
		var met: bool = MetaProgression.is_requirement_met(_profile, entry.id)
		var footer: String = "owned" if owned else "%d shards" % int(entry.cost)
		if not owned and not req.is_empty():
			footer += "   ·   needs %s%s" % [req, "" if met else " (not yet)"]
		var card: Button = UiKit.card(entry.name, entry.description, UiKit.WARN if owned else UiKit.ACCENT, footer)
		card.custom_minimum_size = Vector2(0, 84)
		card.disabled = owned or not MetaProgression.can_unlock(_profile, entry.id)
		var id: String = entry.id
		card.pressed.connect(func() -> void:
			if MetaProgression.purchase_unlock(_profile, id):
				Game.sfx(&"upgrade_pick", -4.0)
				profile_changed.emit()
				_rebuild())
		_list.add_child(card)


func _build_achievements() -> void:
	var earned: int = 0
	for a: Dictionary in MetaProgression.ACHIEVEMENTS:
		if _profile.achievements.has(a.id):
			earned += 1
	_list.add_child(UiKit.label("%d of %d earned" % [earned, MetaProgression.ACHIEVEMENTS.size()], 16, UiKit.TEXT_DIM))
	for a: Dictionary in MetaProgression.ACHIEVEMENTS:
		var done: bool = _profile.achievements.has(a.id)
		var card: Button = UiKit.card(a.name, a.description, UiKit.WARN if done else UiKit.TEXT_DIM,
			"earned" if done else "reward: %d shards" % int(a.reward))
		card.custom_minimum_size = Vector2(0, 78)
		card.disabled = true
		_list.add_child(card)


func _build_stats() -> void:
	var lines: PackedStringArray = _profile.get_stat_summary()
	lines.append("time played: %d h %02d m" % [int(_profile.total_time_played) / 3600, (int(_profile.total_time_played) % 3600) / 60])
	lines.append("essence gathered: %d" % _profile.total_essence)
	lines.append("sprint wins: %d   ·   boss rush wins: %d" % [_profile.sprint_wins, _profile.boss_rush_wins])
	lines.append("best daily kills: %d" % _profile.daily_best_kills)
	for line: String in lines:
		_list.add_child(UiKit.label(line, 19, UiKit.TEXT))
