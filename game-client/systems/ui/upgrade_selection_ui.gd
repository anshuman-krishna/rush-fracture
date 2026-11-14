extends UiModal

# pick one of a few upgrades. number keys, mouse, or gamepad. a run comes
# with a few rerolls, which deal a fresh hand in place of this one.

signal upgrade_selected(upgrade: Dictionary)
signal reroll_requested

var choices: Array[Dictionary] = []
var _cards: VBoxContainer
var _rerolls: int = 0


## owned    id -> stacks already taken, shown on cards that stack
## rerolls  how many fresh hands the player may still ask for
func show_choices(upgrade_choices: Array[Dictionary], heading: String = "choose an upgrade",
		owned: Dictionary = {}, rerolls: int = 0) -> void:
	choices = upgrade_choices
	_rerolls = rerolls
	var was_open: bool = _active
	_clear_content()
	_title(heading, UiKit.ACCENT)
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 10)
	_content.add_child(_cards)

	for i: int in choices.size():
		var u: Dictionary = choices[i]
		var rarity: StringName = u.get("rarity", UpgradeDefinitions.RARITY_COMMON)
		var footer: String = String(rarity)
		var weapon: StringName = u.get("weapon", &"")
		if weapon != &"":
			footer += "  ·  %s" % WeaponDefs.display_name(weapon)
		var max_stacks: int = UpgradeDefinitions.max_stacks(u)
		if max_stacks > 1:
			footer += "  ·  you have %d of %d" % [int(owned.get(u.get("id", &""), 0)), max_stacks]
		var card: Button = UiKit.card(u.get("name", ""), u.get("description", ""), UpgradeDefinitions.rarity_color(u), footer, "[%d]" % (i + 1))
		var captured: Dictionary = u
		card.pressed.connect(func() -> void: _on_choice(captured))
		_cards.add_child(card)

	if _rerolls > 0:
		var again: Button = UiKit.button("reroll [R]  ·  %d left" % _rerolls, 16, Vector2(0, 40))
		again.pressed.connect(_on_reroll)
		_cards.add_child(again)

	if not was_open:
		_open()
	_focus_first(_cards)


func _unhandled_input(event: InputEvent) -> void:
	if not _active or not event is InputEventKey or not event.pressed or event.echo:
		return
	var idx: int = -1
	match (event as InputEventKey).keycode:
		KEY_1: idx = 0
		KEY_2: idx = 1
		KEY_3: idx = 2
		KEY_R:
			get_viewport().set_input_as_handled()
			_on_reroll()
			return
	if idx >= 0 and idx < choices.size():
		get_viewport().set_input_as_handled()
		_on_choice(choices[idx])


func _on_reroll() -> void:
	if _active and _rerolls > 0:
		reroll_requested.emit()


func _on_choice(upgrade: Dictionary) -> void:
	if not _active:
		return
	hide_panel()
	upgrade_selected.emit(upgrade)
