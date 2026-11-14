class_name UiModal
extends Control

# base for the panels that take over the screen mid-run (rewards, path
# choice, shop, summary, pause): a shade over the game, the content, a short
# fade, and handing the mouse to the player while it is open.
#
# two shapes. a framed modal puts its content on one plate (pause, summary).
# an unframed one is a stage: a heading, a row of cards standing on their
# own, and a line of key hints, between two dark bars.

var _active: bool = false
var _shade: Shade
var _panel: PanelContainer
var _content: VBoxContainer
var _tween: Tween

## panel width in pixels; set before the first show
var panel_width: float = 760.0
var backdrop_alpha: float = 0.6
## false for a stage of cards: no plate behind the content
var framed: bool = true


## the dimming behind a modal. a stage also gets a bar along the top and
## bottom, so the cards sit in a band of the game rather than over a void.
class Shade extends Control:
	var alpha: float = 0.6
	var bars: bool = false

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.0, 0.025, alpha))
		if not bars:
			return
		var bar: float = size.y * 0.13
		for top: bool in [true, false]:
			var y: float = 0.0 if top else size.y - bar
			draw_rect(Rect2(0, y, size.x, bar), Color(0.03, 0.02, 0.035, 0.9))
			var edge: float = bar if top else size.y - bar
			draw_line(Vector2(0, edge), Vector2(size.x, edge), Color(UiKit.BONE.r, UiKit.BONE.g, UiKit.BONE.b, 0.35), 1.5)
			# a row of small ticks along the edge
			var step: float = 48.0
			var x: float = fmod(size.x * 0.5, step)
			while x < size.x:
				draw_line(Vector2(x, edge), Vector2(x, edge + (-7.0 if top else 7.0)), Color(UiKit.BONE.r, UiKit.BONE.g, UiKit.BONE.b, 0.3), 1.0)
				x += step


## a heading with a rule running out to either side of it.
class Heading extends Control:
	var text: String = ""
	var sub: String = ""
	var color: Color = UiKit.BONE

	func _init() -> void:
		custom_minimum_size = Vector2(0, 86)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var font: Font = UiKit.font_title()
		var px: int = 40
		var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var cx: float = size.x * 0.5
		var base: float = 42.0
		draw_string(font, Vector2(cx - tw * 0.5 + 2.0, base + 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(0, 0, 0, 0.6))
		draw_string(font, Vector2(cx - tw * 0.5, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
		var mid: float = base - 14.0
		var reach: float = minf(260.0, size.x * 0.5 - tw * 0.5 - 40.0)
		if reach > 20.0:
			for s: float in [-1.0, 1.0]:
				var near_x: float = cx + s * (tw * 0.5 + 24.0)
				var far_x: float = near_x + s * reach
				draw_line(Vector2(near_x, mid), Vector2(far_x, mid), Color(color.r, color.g, color.b, 0.5), 1.5, true)
				draw_colored_polygon(PackedVector2Array([Vector2(near_x, mid - 5), Vector2(near_x + 5, mid), Vector2(near_x, mid + 5), Vector2(near_x - 5, mid)]), color)
				draw_line(Vector2(far_x, mid - 6), Vector2(far_x, mid + 6), Color(color.r, color.g, color.b, 0.5), 1.5)
		if not sub.is_empty():
			var sf: Font = UiKit.font()
			var sw: float = sf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
			draw_string(sf, Vector2(cx - sw * 0.5, base + 30.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UiKit.TEXT_DIM)


class Rule extends Control:
	var color: Color = UiKit.LINE

	func _init() -> void:
		custom_minimum_size = Vector2(0, 14)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y: float = size.y * 0.5
		var cx: float = size.x * 0.5
		draw_line(Vector2(0, y), Vector2(cx - 12.0, y), color, 1.2)
		draw_line(Vector2(cx + 12.0, y), Vector2(size.x, y), color, 1.2)
		draw_colored_polygon(PackedVector2Array([Vector2(cx, y - 5), Vector2(cx + 5, y), Vector2(cx, y + 5), Vector2(cx - 5, y)]), color)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_frame()


func _build_frame() -> void:
	_shade = Shade.new()
	_shade.alpha = backdrop_alpha
	_shade.bars = not framed
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shade)
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(panel_width, 0)
	if not framed:
		_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	centre.add_child(_panel)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12 if framed else 22)
	_panel.add_child(_content)


func is_open() -> bool:
	return _active


func _clear_content() -> void:
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


func _open() -> void:
	_active = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _tween and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.14)


## closes without emitting anything. safe to call when already closed.
func hide_panel() -> void:
	if not _active and not visible:
		return
	_active = false
	visible = false
	if _tween and _tween.is_valid():
		_tween.kill()
	_recapture_mouse()


func _recapture_mouse() -> void:
	# hand the mouse back to the game unless another panel still wants it
	if get_tree().paused:
		return
	var parent: Node = get_parent()
	if parent:
		for sibling: Node in parent.get_children():
			if sibling != self and sibling is UiModal and (sibling as UiModal).is_open():
				return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _title(text: String, color: Color = UiKit.ACCENT, size: int = 30) -> Label:
	var l: Label = UiKit.label(text, size, color)
	l.add_theme_font_override("font", UiKit.font_title())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(l)
	return l


func _note(text: String, color: Color = UiKit.TEXT_DIM, size: int = 16) -> Label:
	var l: Label = UiKit.label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(l)
	return l


## a thin rule across the panel, with a diamond at its centre.
func _rule(color: Color = UiKit.LINE) -> Control:
	var r: Rule = Rule.new()
	r.color = color
	_content.add_child(r)
	return r


## stage heading: a large title with rules either side and a line under it.
func _heading(text: String, color: Color = UiKit.BONE, sub: String = "") -> void:
	var h: Heading = Heading.new()
	h.text = text
	h.sub = sub
	h.color = color
	_content.add_child(h)


## the row a stage's cards stand in.
func _card_row(separation: int = 26) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", separation)
	_content.add_child(row)
	return row


## a centred line of key hints. each item is [keys, what they do], keys being
## one string or an array of them.
func _hints(items: Array) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	_content.add_child(row)
	for i: int in items.size():
		if i > 0:
			var gap: Control = Control.new()
			gap.custom_minimum_size = Vector2(26, 0)
			row.add_child(gap)
		var keys: Array = items[i][0] if items[i][0] is Array else [items[i][0]]
		for k: Variant in keys:
			row.add_child(UiKit.keycap(String(k)))
		var what: Label = UiKit.label(String(items[i][1]), 16, UiKit.TEXT_DIM)
		what.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(what)
	return row


## gives the first button the focus, for someone playing on a pad. with a
## mouse nothing starts out selected, so no card looks already chosen.
func _focus_first(container: Node) -> void:
	if Input.get_connected_joypads().is_empty():
		return
	for child: Node in container.get_children():
		if child is BaseButton and not (child as BaseButton).disabled:
			(child as BaseButton).grab_focus.call_deferred()
			return
