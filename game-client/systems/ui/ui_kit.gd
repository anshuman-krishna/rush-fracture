class_name UiKit
extends RefCounted

# the shared look of every menu and panel: fonts, colours, and factories for
# the handful of pieces (panels, cards, buttons, labels) they are all built from.

const BG: Color = Color(0.035, 0.04, 0.045, 0.94)
const PANEL: Color = Color(0.07, 0.08, 0.085, 0.96)
const CARD: Color = Color(0.1, 0.115, 0.12, 0.97)
const CARD_HOVER: Color = Color(0.14, 0.165, 0.17, 1.0)
const LINE: Color = Color(0.3, 0.36, 0.34, 0.8)
const TEXT: Color = Color(0.9, 0.93, 0.9)
const TEXT_DIM: Color = Color(0.58, 0.63, 0.6)
const ACCENT: Color = Color(0.62, 1.0, 0.36)
const DANGER: Color = Color(1.0, 0.3, 0.22)
const WARN: Color = Color(1.0, 0.72, 0.2)
const GOOD: Color = Color(0.4, 1.0, 0.5)

static var _font: Font
static var _font_bold: Font
static var _theme: Theme


## body font. a system font where one is available, the engine default otherwise.
static func font() -> Font:
	if not _font:
		var f: SystemFont = SystemFont.new()
		f.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Inter", "Noto Sans", "DejaVu Sans", "Arial"])
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_font = f
	return _font


static func font_bold() -> Font:
	if not _font_bold:
		var f: SystemFont = SystemFont.new()
		f.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Inter", "Noto Sans", "DejaVu Sans", "Arial"])
		f.font_weight = 700
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_font_bold = f
	return _font_bold


## theme applied at the root of each ui tree so plain controls pick up the look.
static func theme() -> Theme:
	if _theme:
		return _theme
	var t: Theme = Theme.new()
	t.default_font = font()
	t.default_font_size = 18

	t.set_stylebox("normal", "Button", box(CARD, LINE, 1, 6))
	t.set_stylebox("hover", "Button", box(CARD_HOVER, ACCENT, 2, 6))
	t.set_stylebox("pressed", "Button", box(Color(0.2, 0.26, 0.22), ACCENT, 2, 6))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), ACCENT, 2, 6))
	t.set_stylebox("disabled", "Button", box(Color(0.07, 0.075, 0.08, 0.8), Color(0.2, 0.22, 0.22, 0.6), 1, 6))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.4, 0.43, 0.42))
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", box(PANEL, LINE, 1, 10, 22))
	t.set_stylebox("normal", "LineEdit", box(Color(0.05, 0.055, 0.06), LINE, 1, 5, 8))
	t.set_stylebox("focus", "LineEdit", box(Color(0.05, 0.055, 0.06), ACCENT, 2, 5, 8))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 12)
	_theme = t
	return t


static func box(bg: Color, border: Color = Color(0, 0, 0, 0), border_width: int = 0, radius: int = 6, margin: int = 12) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s


static func label(text: String, size: int = 18, color: Color = TEXT, bold: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", font_bold())
	return l


static func button(text: String, size: int = 18, min_size: Vector2 = Vector2(200, 46)) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			Game.sfx(&"ui_hover", -18.0))
	return b


## a dim full-screen backdrop behind a modal panel.
static func backdrop(alpha: float = 0.62) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = Color(0.0, 0.01, 0.01, alpha)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r


## a panel centred on screen with a fixed width; height follows its content.
static func centered_panel(width: float) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.custom_minimum_size = Vector2(width, 0)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	return p


## a selectable card: coloured left edge, title, body text, optional footer.
## returns the Button that wraps it, so it takes focus, hover and clicks.
static func card(title: String, body: String, edge: Color, footer: String = "", hotkey: String = "") -> Button:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(0, 104)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", _card_box(CARD, edge, false))
	b.add_theme_stylebox_override("hover", _card_box(CARD_HOVER, edge, true))
	b.add_theme_stylebox_override("focus", _card_box(Color(0, 0, 0, 0), edge, true))
	b.add_theme_stylebox_override("pressed", _card_box(CARD_HOVER.lightened(0.05), edge, true))
	b.add_theme_stylebox_override("disabled", _card_box(Color(0.06, 0.065, 0.07, 0.9), Color(0.25, 0.27, 0.27), false))

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	b.add_child(margin)

	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 3)
	margin.add_child(col)

	var head: HBoxContainer = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var t: Label = label(title, 21, edge.lightened(0.25), true)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	if not hotkey.is_empty():
		var k: Label = label(hotkey, 15, TEXT_DIM)
		k.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(k)

	var d: Label = label(body, 16, TEXT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(d)
	if not footer.is_empty():
		var f: Label = label(footer, 14, TEXT_DIM)
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(f)

	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			Game.sfx(&"ui_hover", -18.0))
	return b


static func _card_box(bg: Color, edge: Color, lit: bool) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge if lit else Color(edge.r, edge.g, edge.b, 0.55)
	s.border_width_left = 6
	s.border_width_top = 2 if lit else 1
	s.border_width_right = 2 if lit else 1
	s.border_width_bottom = 2 if lit else 1
	s.set_corner_radius_all(6)
	return s


static func format_time(seconds: float) -> String:
	var total: int = int(seconds)
	return "%d:%02d" % [total / 60, total % 60]
