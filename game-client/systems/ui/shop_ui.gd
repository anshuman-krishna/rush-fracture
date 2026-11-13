extends UiModal

# the tithe altar: spend essence on healing and upgrades. it only displays
# what game_manager gives it and reports what was clicked; prices and effects
# live there.

signal buy_requested(index: int)
signal closed

const SHOP_COLOR: Color = Color(1.0, 0.85, 0.45)

var _items: Array[Dictionary] = []
var _cards: VBoxContainer


func show_shop(items: Array[Dictionary], essence: int) -> void:
	_items = items
	var was_open: bool = _active
	_clear_content()
	_title("tithe altar", SHOP_COLOR)
	_note("%d essence to spend" % essence, UiKit.ACCENT, 19)
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 8)
	_content.add_child(_cards)

	for i: int in items.size():
		var item: Dictionary = items[i]
		var cost: int = int(item.get("cost", 0))
		var sold: bool = item.get("sold", false)
		var edge: Color = SHOP_COLOR
		if item.has("upgrade"):
			edge = UpgradeDefinitions.rarity_color(item.upgrade)
		var footer: String = "sold" if sold else "%d essence" % cost
		var card: Button = UiKit.card(item.get("name", ""), item.get("description", ""), edge, footer)
		card.custom_minimum_size = Vector2(0, 88)
		card.disabled = sold or essence < cost
		var index: int = i
		card.pressed.connect(func() -> void: buy_requested.emit(index))
		_cards.add_child(card)

	var leave: Button = UiKit.button("leave", 18, Vector2(0, 46))
	leave.pressed.connect(_close)
	_cards.add_child(leave)

	if not was_open:
		_open()
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
