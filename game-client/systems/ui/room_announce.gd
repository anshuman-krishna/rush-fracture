extends Control

# big centre-screen announcements: room names, clears, boss intros, fracture
# events, and one-line callouts.

const COLOR_DEFAULT: Color = Color(0.92, 0.95, 0.92)
const COLOR_DANGER: Color = Color(1.0, 0.2, 0.12)
const COLOR_CLEAR: Color = Color(0.4, 1.0, 0.5)
const COLOR_FRACTURE: Color = Color(0.95, 0.3, 1.0)

var _main: Label
var _sub: Label
var _tween: Tween
var _sub_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main = _make_label(46, 0.3)
	_sub = _make_label(22, 0.37)
	_main.modulate.a = 0.0
	_sub.modulate.a = 0.0


func _make_label(px: int, y_ratio: float) -> Label:
	var l: Label = Label.new()
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = y_ratio
	l.anchor_bottom = y_ratio
	l.offset_top = -40.0
	l.offset_bottom = 40.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", UiKit.font_bold())
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 10)
	add_child(l)
	return l


func show_room_enter(room: RunData.RoomData, room_number: int, total: int) -> void:
	var color: Color = COLOR_DEFAULT
	match room.type:
		RoomDefinitions.RoomType.ELITE, RoomDefinitions.RoomType.ELITE_CHAMBER:
			color = Color(1.0, 0.6, 0.12)
		RoomDefinitions.RoomType.SWARM, RoomDefinitions.RoomType.GAUNTLET:
			color = Color(1.0, 0.35, 0.3)
		RoomDefinitions.RoomType.HAZARD:
			color = Color(1.0, 0.5, 0.1)
		RoomDefinitions.RoomType.RECOVERY:
			color = COLOR_CLEAR
		RoomDefinitions.RoomType.SHOP:
			color = Color(1.0, 0.85, 0.45)
	_show(room.title(), color, 1.3)
	show_subtitle("%d of %d" % [room_number, total])


func show_subtitle(text: String, color: Color = Color(1, 1, 1, 0.8)) -> void:
	if _sub_tween and _sub_tween.is_valid():
		_sub_tween.kill()
	_sub.text = text
	_sub.add_theme_color_override("font_color", color)
	_sub.modulate.a = 0.0
	_sub_tween = create_tween()
	_sub_tween.tween_property(_sub, "modulate:a", 1.0, 0.2)
	_sub_tween.tween_interval(1.6)
	_sub_tween.tween_property(_sub, "modulate:a", 0.0, 0.4)


func show_room_clear() -> void:
	_show("cleared", COLOR_CLEAR, 0.7)


func show_boss_intro(boss_name: String, tagline: String) -> void:
	_show(boss_name, COLOR_DANGER, 2.4, true)
	show_subtitle(tagline, Color(1.0, 0.7, 0.6))


func show_boss_defeated() -> void:
	_show("defeated", COLOR_CLEAR, 1.6, true)


func show_fracture(fracture_name: String, description: String = "") -> void:
	_show(fracture_name, COLOR_FRACTURE, 1.4)
	if not description.is_empty():
		show_subtitle(description, Color(0.95, 0.7, 1.0))


## a one-line callout in any colour.
func show_text(text: String, color: Color = COLOR_DEFAULT, hold: float = 1.1) -> void:
	_show(text, color, hold)


func _show(text: String, color: Color, hold: float, punch: bool = false) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_main.text = text
	_main.add_theme_color_override("font_color", color)
	_main.pivot_offset = _main.size * 0.5
	_main.modulate.a = 0.0
	_main.scale = Vector2.ONE * (1.35 if punch else 1.08)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_main, "modulate:a", 1.0, 0.14)
	_tween.tween_property(_main, "scale", Vector2.ONE, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.chain().tween_interval(hold)
	_tween.tween_property(_main, "modulate:a", 0.0, 0.35)
