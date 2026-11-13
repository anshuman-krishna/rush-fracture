extends UiModal

# between rooms: choose where to go next. each option shows what kind of room
# it is, how dangerous, and what it pays.

signal path_chosen(index: int)

const DANGER_COLORS: Array[Color] = [Color(0.4, 1.0, 0.5), Color(0.9, 0.9, 0.9), Color(1.0, 0.72, 0.2), Color(1.0, 0.3, 0.22)]

var options: Array = []
var _cards: VBoxContainer


func show_options(room_options: Array, floor_number: int, total_floors: int) -> void:
	options = room_options
	_clear_content()
	_title("choose your path", UiKit.TEXT)
	_note("floor %d of %d" % [floor_number, total_floors])
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 10)
	_content.add_child(_cards)

	for i: int in options.size():
		var room: RunData.RoomData = options[i]
		var danger: int = clampi(RoomDefinitions.danger(room.type), 0, 3)
		var edge: Color = DANGER_COLORS[danger]
		var threat: String = ["safe", "danger: low", "danger: medium", "danger: high"][danger]
		var footer: String = "%s   ·   reward: %s" % [threat, RoomDefinitions.reward_name(room.reward)]
		var card: Button = UiKit.card(room.title(), RoomDefinitions.blurb(room.type), edge, footer, "[%d]" % (i + 1))
		var index: int = i
		card.pressed.connect(func() -> void: _choose(index))
		_cards.add_child(card)

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
	if idx >= 0 and idx < options.size():
		get_viewport().set_input_as_handled()
		_choose(idx)


func _choose(index: int) -> void:
	if not _active:
		return
	hide_panel()
	path_chosen.emit(index)
