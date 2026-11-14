class_name UiKit
extends RefCounted

# the shared look of every menu and panel: fonts, colours, and factories for
# the handful of pieces (panels, cards, buttons, labels) they are all built from.
#
# the palette is the brood's own materials: dark chitin for plates, bone for
# lines and text, the hive's glow as the one accent. nothing is rounded;
# plates have two corners cut off, like something broken from a larger shell.

const BG: Color = Color(0.045, 0.034, 0.05, 0.95)
const PANEL: Color = Color(0.078, 0.06, 0.082, 0.97)
const CARD: Color = Color(0.112, 0.088, 0.115, 0.98)
const CARD_HOVER: Color = Color(0.17, 0.135, 0.17, 1.0)
const LINE: Color = Color(0.5, 0.45, 0.38, 0.8)
const TEXT: Color = Color(0.94, 0.91, 0.84)
const TEXT_DIM: Color = Color(0.64, 0.6, 0.55)
const BONE: Color = Color(0.86, 0.8, 0.68)
const ACCENT: Color = Color(0.62, 1.0, 0.36)
const DANGER: Color = Color(1.0, 0.33, 0.26)
const WARN: Color = Color(1.0, 0.72, 0.2)
const GOOD: Color = Color(0.45, 1.0, 0.5)
const GOLD: Color = Color(1.0, 0.82, 0.42)

const CUT: int = 12
const FACES: PackedStringArray = ["Bahnschrift", "Segoe UI", "Inter", "Noto Sans", "DejaVu Sans", "Arial"]

static var _font: Font
static var _font_bold: Font
static var _font_title: Font
static var _font_tag: Font
static var _theme: Theme


## body font. a system font where one is available, the engine default otherwise.
static func font() -> Font:
	if not _font:
		var f: SystemFont = SystemFont.new()
		f.font_names = FACES
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_font = f
	return _font


static func font_bold() -> Font:
	if not _font_bold:
		var f: SystemFont = SystemFont.new()
		f.font_names = FACES
		f.font_weight = 700
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_font_bold = f
	return _font_bold


## names and headings: the bold face, narrower, with a little air between letters.
static func font_title() -> Font:
	if not _font_title:
		var f: SystemFont = SystemFont.new()
		f.font_names = FACES
		f.font_weight = 700
		f.font_stretch = 82
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		var spaced: FontVariation = FontVariation.new()
		spaced.base_font = f
		spaced.spacing_glyph = 1
		_font_title = spaced
	return _font_title


## small labels (a rarity, a key hint): widely spaced so they read as tags, not sentences.
static func font_tag() -> Font:
	if not _font_tag:
		var spaced: FontVariation = FontVariation.new()
		spaced.base_font = font_bold()
		spaced.spacing_glyph = 3
		_font_tag = spaced
	return _font_tag


## theme applied at the root of each ui tree so plain controls pick up the look.
static func theme() -> Theme:
	if _theme:
		return _theme
	var t: Theme = Theme.new()
	t.default_font = font()
	t.default_font_size = 18

	t.set_stylebox("normal", "Button", box(CARD, LINE, 1))
	t.set_stylebox("hover", "Button", box(CARD_HOVER, BONE, 2))
	t.set_stylebox("pressed", "Button", box(Color(0.24, 0.2, 0.22), BONE, 2))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), ACCENT, 2))
	t.set_stylebox("disabled", "Button", box(Color(0.07, 0.06, 0.075, 0.8), Color(0.24, 0.22, 0.22, 0.6), 1))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.42, 0.4, 0.4))
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", box(PANEL, LINE, 1, 22, 26))
	t.set_stylebox("normal", "LineEdit", box(Color(0.045, 0.035, 0.05), LINE, 1, 6, 8))
	t.set_stylebox("focus", "LineEdit", box(Color(0.045, 0.035, 0.05), ACCENT, 2, 6, 8))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 12)
	_theme = t
	return t


## a plate: flat fill, thin border, the top-left and bottom-right corners cut.
static func box(bg: Color, border: Color = Color(0, 0, 0, 0), border_width: int = 0, cut: int = CUT, margin: int = 12) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	# one segment per corner turns a rounded corner into a straight cut
	s.corner_detail = 1
	s.corner_radius_top_left = cut
	s.corner_radius_bottom_right = cut
	s.corner_radius_top_right = 0
	s.corner_radius_bottom_left = 0
	s.anti_aliasing = true
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


## a key drawn as a small plate, for "press this" hints.
static func keycap(text: String) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(Color(0, 0, 0, 0.45), BONE, 1, 5, 5))
	p.custom_minimum_size = Vector2(30, 30)
	var l: Label = label(text, 15, BONE, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## a dim full-screen backdrop behind a modal panel.
static func backdrop(alpha: float = 0.62) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = Color(0.01, 0.0, 0.015, alpha)
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


## a list row you can select: a cut plate with a title, body text and an
## optional footer. for long lists (the shop of permanent upgrades, the
## codex); choices made mid-run use ChoiceCard instead.
static func card(title: String, body: String, edge: Color, footer: String = "", hotkey: String = "") -> Button:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(0, 104)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", _card_box(CARD, edge, false))
	b.add_theme_stylebox_override("hover", _card_box(CARD_HOVER, edge, true))
	b.add_theme_stylebox_override("focus", _card_box(Color(0, 0, 0, 0), edge, true))
	b.add_theme_stylebox_override("pressed", _card_box(CARD_HOVER.lightened(0.05), edge, true))
	b.add_theme_stylebox_override("disabled", _card_box(Color(0.07, 0.058, 0.075, 0.9), Color(0.3, 0.28, 0.27), false))

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 18)
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
	var t: Label = label(title, 21, Color.WHITE.lerp(edge, 0.45))
	t.add_theme_font_override("font", font_title())
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
	var s: StyleBoxFlat = box(bg, edge if lit else Color(edge.r, edge.g, edge.b, 0.45), 2 if lit else 1, 14, 0)
	return s


static func format_time(seconds: float) -> String:
	var total: int = int(seconds)
	return "%d:%02d" % [total / 60, total % 60]
