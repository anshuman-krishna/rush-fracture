extends UiModal

# pick one of a few upgrades: three cards side by side. number keys, mouse,
# or gamepad. a run comes with a few rerolls, which deal a fresh hand in
# place of this one.

signal upgrade_selected(upgrade: Dictionary)
signal reroll_requested

var choices: Array[Dictionary] = []
var _cards: HBoxContainer
var _rerolls: int = 0


func _init() -> void:
	framed = false


## owned    id -> stacks already taken, shown as pips on cards that stack
## rerolls  how many fresh hands the player may still ask for
func show_choices(upgrade_choices: Array[Dictionary], heading: String = "choose an upgrade",
		owned: Dictionary = {}, rerolls: int = 0) -> void:
	choices = upgrade_choices
	_rerolls = rerolls
	var was_open: bool = _active
	_clear_content()
	_heading(heading, UiKit.BONE, "it stays with you for the rest of the run")
	_cards = _card_row()

	var count: int = choices.size()
	for i: int in count:
		var u: Dictionary = choices[i]
		var rarity: StringName = u.get("rarity", UpgradeDefinitions.RARITY_COMMON)
		var card: ChoiceCard = ChoiceCard.new()
		card.title = u.get("name", "")
		card.body = u.get("description", "")
		card.tint = UpgradeDefinitions.rarity_color(u)
		card.frame = rarity
		card.tag = String(rarity)
		card.glyph = UiGlyphs.for_upgrade(u)
		card.hotkey = str(i + 1)
		var weapon: StringName = u.get("weapon", &"")
		if weapon != &"":
			card.footer = WeaponDefs.display_name(weapon)
		var max_stacks: int = UpgradeDefinitions.max_stacks(u)
		if max_stacks > 1:
			card.pips = int(owned.get(u.get("id", &""), 0))
			card.pips_max = max_stacks
			card.pips_label = "held"
		card.tilt = (float(i) - float(count - 1) * 0.5) * 0.028
		card.appear_delay = 0.07 * float(i)
		var captured: Dictionary = u
		card.pressed.connect(func() -> void: _on_choice(captured))
		_cards.add_child(card)

	var keys: Array = []
	for i: int in count:
		keys.append(str(i + 1))
	var hints: Array = [[keys, "choose"]]
	if _rerolls > 0:
		hints.append(["R", "deal again  ·  %d left" % _rerolls])
	_hints(hints)

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
