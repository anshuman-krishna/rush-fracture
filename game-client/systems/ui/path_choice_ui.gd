extends UiModal

# between rooms: choose where to go next. each card shows what kind of room
# it is, how dangerous, what it pays, and anything strange about the place.

signal path_chosen(index: int)

const DANGER_COLORS: Array[Color] = [Color(0.45, 1.0, 0.5), Color(0.86, 0.8, 0.68), Color(1.0, 0.72, 0.2), Color(1.0, 0.33, 0.26)]
const DANGER_WORDS: PackedStringArray = ["safe", "low threat", "dangerous", "deadly"]

var options: Array = []
var _cards: HBoxContainer


func _init() -> void:
	framed = false


func show_options(room_options: Array, floor_number: int, total_floors: int) -> void:
	options = room_options
	_clear_content()
	_heading("choose your path", UiKit.BONE, "floor %d of %d" % [floor_number, total_floors])
	_cards = _card_row()

	var count: int = options.size()
	for i: int in count:
		var room: RunData.RoomData = options[i]
		var danger: int = clampi(RoomDefinitions.danger(room.type), 0, 3)
		var card: ChoiceCard = ChoiceCard.new()
		card.title = room.title()
		card.body = RoomDefinitions.blurb(room.type)
		card.tint = DANGER_COLORS[danger]
		card.frame = &"rare" if danger >= 2 else &"common"
		card.tag = DANGER_WORDS[danger]
		card.glyph = UiGlyphs.for_room(room.type)
		card.hotkey = str(i + 1)
		card.pips = danger
		card.pips_max = 3
		card.pips_label = "threat"
		card.footer = "pays: %s" % RoomDefinitions.reward_name(room.reward)
		var condition: StringName = RoomConditions.of(room)
		if condition != &"":
			card.chips.append(["%s: %s" % [RoomConditions.display_name(condition), RoomConditions.text(condition)], RoomConditions.color(condition)])
		card.tilt = (float(i) - float(count - 1) * 0.5) * 0.028
		card.appear_delay = 0.07 * float(i)
		var index: int = i
		card.pressed.connect(func() -> void: _choose(index))
		_cards.add_child(card)

	var keys: Array = []
	for i: int in count:
		keys.append(str(i + 1))
	_hints([[keys, "go"]])

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
