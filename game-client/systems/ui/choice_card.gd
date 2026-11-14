class_name ChoiceCard
extends BaseButton

# one thing you can pick: an upgrade, a mutation, a room, something on the
# altar. the whole card is drawn here (plate, frame, glyph, text) so it can
# tilt, lift under the cursor and deal itself in, none of which a stack of
# stock controls can do.
#
# tall cards stand side by side in a row. wide cards stack in a list.

const CUT: float = 26.0
const TALL: Vector2 = Vector2(304, 416)
const WIDE: Vector2 = Vector2(470, 122)

var title: String = ""
var body: String = ""
## a second block under the body, in `alt_color`: what the choice costs
var body_alt: String = ""
var alt_color: Color = UiKit.DANGER
var footer: String = ""
## small spaced label in the top corner (a rarity, a threat level)
var tag: String = ""
var hotkey: String = ""
var glyph: StringName = &"claw"
var tint: Color = UiKit.BONE
## common | rare | epic | cursed: how much frame the card gets
var frame: StringName = &"common"
## a row of pips: `pips` filled out of `pips_max`. hidden when pips_max is 0.
var pips: int = 0
var pips_max: int = 0
var pips_label: String = ""
## [[text, color], ...] short coloured lines under the body
var chips: Array = []
var price: String = ""
var wide: bool = false
var tilt: float = 0.0
var appear_delay: float = 0.0
## already bought: stays visible, cannot be picked
var spent: bool = false
## skip the deal-in: for a card that replaces one already on screen
var instant: bool = false

var _hover: float = 0.0
var _appear: float = 0.0
var _wait: float = 0.0


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = WIDE if wide else TALL
	_wait = appear_delay
	modulate.a = 0.0
	if instant:
		_wait = 0.0
		_appear = 1.0
		modulate.a = 1.0
	mouse_entered.connect(func() -> void:
		if not disabled and not spent:
			Game.sfx(&"ui_hover", -18.0))


func _process(delta: float) -> void:
	# these panels open while the game may be in slow motion: undo the scale
	var dt: float = minf(0.1, delta / maxf(Engine.time_scale, 0.05))
	if _wait > 0.0:
		_wait -= dt
		return
	_appear = minf(1.0, _appear + dt * 5.5)
	var lit: bool = (is_hovered() or has_focus()) and not disabled and not spent
	_hover = move_toward(_hover, 1.0 if lit else 0.0, dt * 9.0)
	modulate.a = _appear
	queue_redraw()


func _draw() -> void:
	var eased: float = 1.0 - pow(1.0 - _appear, 3.0)
	var centre: Vector2 = size * 0.5
	var lift: float = (1.0 - eased) * 46.0 - (0.0 if wide else 14.0) * _hover
	var grow: float = 1.0 + (0.012 if wide else 0.035) * _hover
	draw_set_transform(centre + Vector2(0, lift), tilt * (1.0 - _hover) * eased, Vector2(grow, grow))

	var o: Vector2 = -centre
	var dim: float = 0.42 if (disabled or spent) else 1.0
	var ink: Color = Color(tint.r, tint.g, tint.b, dim)
	_draw_plate(o, ink, dim)
	if wide:
		_draw_wide(o, ink, dim)
	else:
		_draw_tall(o, ink, dim)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _outline(o: Vector2, inset: float) -> PackedVector2Array:
	var w: float = size.x
	var h: float = size.y
	var c: float = CUT - inset * 0.4
	return PackedVector2Array([
		o + Vector2(c + inset, inset), o + Vector2(w - inset, inset), o + Vector2(w - inset, h - c - inset),
		o + Vector2(w - c - inset, h - inset), o + Vector2(inset, h - inset), o + Vector2(inset, c + inset),
		o + Vector2(c + inset, inset),
	])


func _draw_plate(o: Vector2, ink: Color, dim: float) -> void:
	var shape: PackedVector2Array = _outline(o, 0.0)
	var fill: PackedVector2Array = shape.slice(0, 6)
	var top: Color = UiKit.CARD.lerp(Color(tint.r, tint.g, tint.b, 1.0), 0.13 + 0.1 * _hover)
	var bottom: Color = UiKit.CARD.darkened(0.25)
	top.a = 0.97
	bottom.a = 0.97
	# a shadow first, so a lifted card reads as lifted
	var shadow: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in fill:
		shadow.append(p + Vector2(0, 10.0 + 8.0 * _hover))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
	draw_polygon(fill, PackedColorArray([top, top, bottom, bottom, bottom, top]))

	var line: Color = Color(ink.r, ink.g, ink.b, (0.6 + 0.4 * _hover) * dim)
	draw_polyline(shape, line, 1.6 + 1.4 * _hover, true)
	if frame != &"common":
		draw_polyline(_outline(o, 7.0), Color(ink.r, ink.g, ink.b, 0.3 * dim), 1.0, true)
	if frame == &"epic":
		# a crest on the top edge
		for i: int in 3:
			var x: float = size.x * 0.5 + (float(i) - 1.0) * 22.0
			var tall: float = 14.0 if i == 1 else 9.0
			draw_colored_polygon(PackedVector2Array([o + Vector2(x - 8.0, 0.0), o + Vector2(x, -tall), o + Vector2(x + 8.0, 0.0)]), line)
	elif frame == &"cursed":
		# a crack running in from the corner
		var crack: PackedVector2Array = PackedVector2Array()
		var steps: Array = [Vector2(0, 0), Vector2(-18, 22), Vector2(-9, 40), Vector2(-34, 62), Vector2(-24, 84), Vector2(-46, 110)]
		for s: Vector2 in steps:
			crack.append(o + Vector2(size.x, 0) + s)
		draw_polyline(crack, Color(ink.r, ink.g, ink.b, 0.55 * dim), 1.4, true)


func _draw_tall(o: Vector2, ink: Color, dim: float) -> void:
	var w: float = size.x
	var h: float = size.y
	var text: Color = Color(UiKit.TEXT.r, UiKit.TEXT.g, UiKit.TEXT.b, dim)
	var faint: Color = Color(UiKit.TEXT_DIM.r, UiKit.TEXT_DIM.g, UiKit.TEXT_DIM.b, dim)

	_draw_keycap(o + Vector2(CUT + 6.0, 14.0), faint)
	if not tag.is_empty():
		var tag_font: Font = UiKit.font_tag()
		var tw: float = tag_font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(tag_font, o + Vector2(w - 18.0 - tw, 32.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)

	# the glyph sits on a medallion: a hexagon with a tick either side
	var gc: Vector2 = o + Vector2(w * 0.5, 122.0)
	var hexagon: PackedVector2Array = PackedVector2Array()
	for i: int in 7:
		hexagon.append(gc + Vector2.UP.rotated(TAU * float(i) / 6.0) * 70.0)
	draw_colored_polygon(hexagon.slice(0, 6), Color(0, 0, 0, 0.28 * dim))
	draw_polyline(hexagon, Color(ink.r, ink.g, ink.b, 0.38 * dim), 1.2, true)
	for s: float in [-1.0, 1.0]:
		draw_line(gc + Vector2(s * 82.0, 0), gc + Vector2(s * 112.0, 0), Color(ink.r, ink.g, ink.b, 0.38 * dim), 1.2, true)
		_diamond(gc + Vector2(s * 118.0, 0), 3.5, Color(ink.r, ink.g, ink.b, 0.6 * dim))
	UiGlyphs.draw(self, glyph, gc, 40.0 + 3.0 * _hover, ink)

	var y: float = 214.0
	y = _para(UiKit.font_title(), o, 20.0, y, title, w - 40.0, 25, Color(1, 1, 1, dim).lerp(ink, 0.35), 2) + 8.0
	draw_line(o + Vector2(w * 0.5 - 44.0, y), o + Vector2(w * 0.5 + 44.0, y), Color(ink.r, ink.g, ink.b, 0.5 * dim), 1.2, true)
	_diamond(o + Vector2(w * 0.5, y), 4.0, ink)
	y += 16.0
	y = _para(UiKit.font(), o, 24.0, y, body, w - 48.0, 17, text, 5)
	if not body_alt.is_empty():
		y += 9.0
		_dashes(o + Vector2(40.0, y), w - 80.0, Color(alt_color.r, alt_color.g, alt_color.b, 0.5 * dim))
		y += 11.0
		y = _para(UiKit.font(), o, 24.0, y, body_alt, w - 48.0, 16, Color(alt_color.r, alt_color.g, alt_color.b, dim), 4)
	for chip: Array in chips:
		y += 8.0
		var cc: Color = chip[1]
		y = _para(UiKit.font(), o, 24.0, y, String(chip[0]), w - 48.0, 14, Color(cc.r, cc.g, cc.b, dim), 3)

	var base: float = h - 22.0
	if not footer.is_empty():
		_line(UiKit.font(), o + Vector2(w * 0.5, base), footer, 14, faint)
		base -= 24.0
	if pips_max > 0:
		_draw_pips(o + Vector2(w * 0.5, base - 4.0), ink, faint)
	if not price.is_empty():
		_draw_price(o + Vector2(w - 16.0, h - CUT - 30.0), dim)
	if spent:
		_line(UiKit.font_title(), o + Vector2(w * 0.5, h * 0.5), "taken", 30, Color(1, 1, 1, 0.75))


func _draw_wide(o: Vector2, ink: Color, dim: float) -> void:
	var w: float = size.x
	var h: float = size.y
	var text: Color = Color(UiKit.TEXT.r, UiKit.TEXT.g, UiKit.TEXT.b, dim)
	var gc: Vector2 = o + Vector2(64.0, h * 0.5)
	var hexagon: PackedVector2Array = PackedVector2Array()
	for i: int in 7:
		hexagon.append(gc + Vector2.UP.rotated(TAU * float(i) / 6.0) * 40.0)
	draw_colored_polygon(hexagon.slice(0, 6), Color(0, 0, 0, 0.28 * dim))
	draw_polyline(hexagon, Color(ink.r, ink.g, ink.b, 0.38 * dim), 1.2, true)
	UiGlyphs.draw(self, glyph, gc, 23.0 + 2.0 * _hover, ink)

	var right: float = 104.0 if not price.is_empty() else 22.0
	var y: float = 18.0
	y = _para(UiKit.font_title(), o, 122.0, y, title, w - 122.0 - right, 21, Color(1, 1, 1, dim).lerp(ink, 0.35), 1, HORIZONTAL_ALIGNMENT_LEFT) + 4.0
	_para(UiKit.font(), o, 122.0, y, body, w - 122.0 - right, 15, text, 3, HORIZONTAL_ALIGNMENT_LEFT)
	if not price.is_empty():
		_draw_price(o + Vector2(w - 16.0, h * 0.5 - 14.0), dim)
	if spent:
		_line(UiKit.font_title(), o + Vector2(w - 62.0, h * 0.5 + 34.0), "taken", 15, Color(1, 1, 1, 0.7))


func _draw_keycap(at: Vector2, color: Color) -> void:
	if hotkey.is_empty():
		return
	draw_rect(Rect2(at, Vector2(24, 24)), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(at, Vector2(24, 24)), color, false, 1.2)
	_line(UiKit.font_bold(), at + Vector2(12.0, 18.0), hotkey, 15, color)


func _draw_pips(at: Vector2, ink: Color, faint: Color) -> void:
	var gap: float = 16.0
	var label_w: float = 0.0
	if not pips_label.is_empty():
		label_w = UiKit.font().get_string_size(pips_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 10.0
	var x: float = at.x - (float(pips_max - 1) * gap + label_w) * 0.5
	if not pips_label.is_empty():
		draw_string(UiKit.font(), Vector2(x, at.y + 5.0), pips_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, faint)
		x += label_w
	for i: int in pips_max:
		var p: Vector2 = Vector2(x + float(i) * gap, at.y)
		if i < pips:
			_diamond(p, 5.5, ink)
		else:
			draw_polyline(PackedVector2Array([p + Vector2(0, -5.5), p + Vector2(5.5, 0), p + Vector2(0, 5.5), p + Vector2(-5.5, 0), p + Vector2(0, -5.5)]),
				Color(faint.r, faint.g, faint.b, faint.a * 0.8), 1.0, true)


## a price tag, right-aligned at `at`. red when the card cannot be afforded.
func _draw_price(at: Vector2, dim: float) -> void:
	var font: Font = UiKit.font_bold()
	var tw: float = font.get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var gold: Color = UiKit.DANGER if disabled and not spent else UiKit.GOLD
	gold.a = dim if not disabled else 0.85
	var x: float = at.x - tw
	_diamond(Vector2(x - 14.0, at.y + 13.0), 6.0, gold)
	draw_string(font, Vector2(x, at.y + 20.0), price, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, gold)


func _diamond(c: Vector2, r: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), color)


func _dashes(from: Vector2, length: float, color: Color) -> void:
	var x: float = 0.0
	while x < length:
		draw_line(from + Vector2(x, 0), from + Vector2(minf(x + 7.0, length), 0), color, 1.2)
		x += 13.0


## one centred line of text with its baseline at `at`.
func _line(font: Font, at: Vector2, text: String, px: int, color: Color) -> void:
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(font, Vector2(at.x - tw * 0.5, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)


## a wrapped paragraph whose top-left is (x, y) on the card, the card itself
## starting at `o`. returns the y just below it, also on the card.
func _para(font: Font, o: Vector2, x: float, y: float, text: String, width: float, px: int, color: Color, max_lines: int,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> float:
	if text.is_empty():
		return y
	draw_multiline_string(font, o + Vector2(x, y + font.get_ascent(px)), text, align, width, px, max_lines, color)
	return y + font.get_multiline_string_size(text, align, width, px, max_lines).y
