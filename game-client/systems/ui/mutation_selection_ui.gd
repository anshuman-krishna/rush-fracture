extends UiModal

# offer a mutation: a strong upside with a real cost, both written on the
# card. refusing is always allowed.

signal mutation_selected(mutation: Dictionary)
signal mutation_skipped

const MUTATION_COLOR: Color = Color(1.0, 0.55, 0.15)

var choices: Array[Dictionary] = []
var _chosen: bool = true
var _cards: HBoxContainer


func _init() -> void:
	framed = false


func show_choices(mutation_choices: Array[Dictionary]) -> void:
	choices = mutation_choices
	_chosen = false
	_clear_content()
	_heading("mutate", MUTATION_COLOR, "permanent for this run. each one costs you something.")
	_cards = _card_row(34)

	var count: int = choices.size()
	for i: int in count:
		var m: Dictionary = choices[i]
		var card: ChoiceCard = ChoiceCard.new()
		card.title = m.get("name", "")
		card.body = String(m.get("upside", ""))
		card.body_alt = String(m.get("downside", ""))
		card.tint = MUTATION_COLOR
		card.frame = &"rare"
		card.tag = "mutation"
		card.glyph = &"helix"
		card.hotkey = str(i + 1)
		card.tilt = (float(i) - float(count - 1) * 0.5) * 0.03
		card.appear_delay = 0.08 * float(i)
		var captured: Dictionary = m
		card.pressed.connect(func() -> void: _on_choice(captured))
		_cards.add_child(card)

	var keys: Array = []
	for i: int in count:
		keys.append(str(i + 1))
	var hints: HBoxContainer = _hints([[keys, "take it"], [str(count + 1), "or"]])
	var skip: Button = UiKit.button("stay as you are", 16, Vector2(190, 36))
	skip.pressed.connect(_on_skip)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(18, 0)
	hints.add_child(gap)
	hints.add_child(skip)

	_open()
	_focus_first(_cards)


func _unhandled_input(event: InputEvent) -> void:
	if not _active or _chosen or not event is InputEventKey or not event.pressed or event.echo:
		return
	var idx: int = -1
	match (event as InputEventKey).keycode:
		KEY_1: idx = 0
		KEY_2: idx = 1
		KEY_3: idx = 2
	if idx < 0:
		return
	get_viewport().set_input_as_handled()
	if idx < choices.size():
		_on_choice(choices[idx])
	elif idx == choices.size():
		_on_skip()


func _on_choice(mutation: Dictionary) -> void:
	if _chosen:
		return
	_chosen = true
	hide_panel()
	mutation_selected.emit(mutation)


func _on_skip() -> void:
	if _chosen:
		return
	_chosen = true
	hide_panel()
	mutation_skipped.emit()
