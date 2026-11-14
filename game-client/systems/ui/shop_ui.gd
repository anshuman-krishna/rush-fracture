extends UiModal

# the tithe altar: spend essence on healing and upgrades. it only displays
# what game_manager gives it and reports what was clicked; prices and effects
# live there.

signal buy_requested(index: int)
signal closed

const SHOP_COLOR: Color = Color(1.0, 0.82, 0.42)
const KIND_GLYPHS: Dictionary = {"heal": &"drop", "graft": &"heart", "reroll": &"dice"}

var _items: Array[Dictionary] = []
var _cards: GridContainer


func _init() -> void:
	framed = false


func show_shop(items: Array[Dictionary], essence: int) -> void:
	_items = items
	var was_open: bool = _active
	_clear_content()
	_heading("tithe altar", SHOP_COLOR, "%d essence to spend" % essence)

	_cards = GridContainer.new()
	_cards.columns = 2
	_cards.add_theme_constant_override("h_separation", 22)
	_cards.add_theme_constant_override("v_separation", 18)
	_cards.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(_cards)

	for i: int in items.size():
		var item: Dictionary = items[i]
		var cost: int = int(item.get("cost", 0))
		var sold: bool = item.get("sold", false)
		var card: ChoiceCard = ChoiceCard.new()
		card.wide = true
		card.title = item.get("name", "")
		card.body = item.get("description", "")
		card.price = str(cost)
		card.spent = sold
		card.disabled = sold or essence < cost
		card.appear_delay = 0.04 * float(i)
		card.instant = was_open
		if item.has("upgrade"):
			card.tint = UpgradeDefinitions.rarity_color(item.upgrade)
			card.frame = item.upgrade.get("rarity", UpgradeDefinitions.RARITY_COMMON)
			card.glyph = UiGlyphs.for_upgrade(item.upgrade)
		else:
			card.tint = SHOP_COLOR
			card.glyph = KIND_GLYPHS.get(item.get("kind", ""), &"gem")
		var index: int = i
		card.pressed.connect(func() -> void: buy_requested.emit(index))
		_cards.add_child(card)

	var row: HBoxContainer = _hints([["esc", "leave"]])
	var leave: Button = UiKit.button("leave the altar", 16, Vector2(190, 36))
	leave.pressed.connect(_close)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(18, 0)
	row.add_child(gap)
	row.add_child(leave)

	if not was_open:
		_open()
	if not Input.get_connected_joypads().is_empty():
		leave.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if _active and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	if not _active:
		return
	hide_panel()
	closed.emit()
