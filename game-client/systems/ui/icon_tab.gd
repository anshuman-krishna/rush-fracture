class_name IconTab
extends BaseButton

# a small tile with a glyph and a caption: one choice out of a set shown all
# at once (the run modes on the title screen). the chosen one is lit.

var glyph: StringName = &"claw"
var caption: String = ""
var tint: Color = UiKit.BONE
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(104, 76)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	mouse_entered.connect(func() -> void:
		if not disabled:
			Game.sfx(&"ui_hover", -18.0)
		queue_redraw())
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _draw() -> void:
	var lit: bool = selected or ((is_hovered() or has_focus()) and not disabled)
	var dim: float = 0.35 if disabled else 1.0
	var ink: Color = tint if selected else (Color(tint.r, tint.g, tint.b, 0.85) if lit else UiKit.TEXT_DIM)
	ink.a *= dim
	var cut: float = 10.0
	var plate: PackedVector2Array = PackedVector2Array([
		Vector2(cut, 0), Vector2(size.x, 0), Vector2(size.x, size.y - cut), Vector2(size.x - cut, size.y),
		Vector2(0, size.y), Vector2(0, cut), Vector2(cut, 0),
	])
	var fill: Color = UiKit.CARD_HOVER if lit else UiKit.CARD
	if selected:
		fill = fill.lerp(Color(tint.r, tint.g, tint.b, 1.0), 0.16)
	fill.a = 0.92 * (0.6 if disabled else 1.0)
	draw_colored_polygon(plate.slice(0, 6), fill)
	draw_polyline(plate, Color(ink.r, ink.g, ink.b, ink.a * (1.0 if selected else 0.6)), 2.0 if selected else 1.0, true)
	if selected:
		# a notch of light under the tile says which one is in play
		draw_rect(Rect2(size.x * 0.5 - 16.0, size.y - 4.0, 32.0, 4.0), tint)
	UiGlyphs.draw(self, glyph, Vector2(size.x * 0.5, 28.0), 17.0, ink)
	var font: Font = UiKit.font_bold() if selected else UiKit.font()
	var w: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(font, Vector2((size.x - w) * 0.5, size.y - 11.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
