extends UiModal

# offer a mutation: a strong upside with a real cost. refusing is always allowed.

signal mutation_selected(mutation: Dictionary)
signal mutation_skipped

const MUTATION_COLOR: Color = Color(1.0, 0.55, 0.15)

var choices: Array[Dictionary] = []
var _chosen: bool = true
var _cards: VBoxContainer


func show_choices(mutation_choices: Array[Dictionary]) -> void:
	choices = mutation_choices
	_chosen = false
	_clear_content()
	_title("mutate", MUTATION_COLOR)
	_note("permanent for this run. each one costs you something.")
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 10)
	_content.add_child(_cards)

	for i: int in choices.size():
		var m: Dictionary = choices[i]
		var card: Button = UiKit.card(m.get("name", ""), "+ %s" % m.get("upside", ""), MUTATION_COLOR,
			"-  %s" % m.get("downside", ""), "[%d]" % (i + 1))
		var captured: Dictionary = m
		card.pressed.connect(func() -> void: _on_choice(captured))
		_cards.add_child(card)

	var skip: Button = UiKit.button("stay as you are  [%d]" % (choices.size() + 1), 17, Vector2(0, 44))
	skip.pressed.connect(_on_skip)
	_cards.add_child(skip)

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
