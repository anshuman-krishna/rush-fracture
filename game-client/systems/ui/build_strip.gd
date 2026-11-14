class_name BuildStrip
extends Control

# the build so far, as a row of small tiles: one per upgrade taken (with a
# count when it was taken more than once) and one per mutation. used by the
# pause menu and the end-of-run screen.

const TILE: float = 50.0
const GAP: float = 8.0
const COLUMNS: int = 11
const MUTATION_COLOR: Color = Color(1.0, 0.55, 0.15)

## {glyph, color, count, name}
var _entries: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func is_empty() -> bool:
	return _entries.is_empty()


## the names behind the tiles, in the same order, for a line of text under them.
func names() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for e: Dictionary in _entries:
		out.append(e.name if e.count == 1 else "%s x%d" % [e.name, e.count])
	return out


func set_build(upgrades: Array, mutations: Array) -> void:
	_entries.clear()
	var index: Dictionary = {}
	for u: Dictionary in upgrades:
		var key: String = String(u.get("id", u.get("name", "")))
		if index.has(key):
			_entries[index[key]].count += 1
			continue
		index[key] = _entries.size()
		_entries.append({
			"glyph": UiGlyphs.for_upgrade(u), "color": UpgradeDefinitions.rarity_color(u),
			"count": 1, "name": String(u.get("name", "")),
		})
	for m: Dictionary in mutations:
		_entries.append({"glyph": &"helix", "color": MUTATION_COLOR, "count": 1, "name": String(m.get("name", ""))})

	var n: int = _entries.size()
	var cols: int = mini(maxi(n, 1), COLUMNS)
	var rows: int = int(ceil(float(n) / float(COLUMNS)))
	custom_minimum_size = Vector2(float(cols) * (TILE + GAP) - GAP, float(maxi(rows, 0)) * (TILE + GAP) - GAP if n > 0 else 0.0)
	queue_redraw()


func _draw() -> void:
	for i: int in _entries.size():
		var e: Dictionary = _entries[i]
		var cell: Vector2 = Vector2(float(i % COLUMNS) * (TILE + GAP), float(i / COLUMNS) * (TILE + GAP))
		var c: Vector2 = cell + Vector2(TILE, TILE) * 0.5
		var tint: Color = e.color
		var hexagon: PackedVector2Array = PackedVector2Array()
		for k: int in 7:
			hexagon.append(c + Vector2.UP.rotated(TAU * float(k) / 6.0) * TILE * 0.5)
		draw_colored_polygon(hexagon.slice(0, 6), Color(0, 0, 0, 0.4))
		draw_polyline(hexagon, Color(tint.r, tint.g, tint.b, 0.6), 1.2, true)
		UiGlyphs.draw(self, e.glyph, c, TILE * 0.27, tint)
		if int(e.count) > 1:
			var label: String = "x%d" % int(e.count)
			var font: Font = UiKit.font_bold()
			var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_rect(Rect2(cell.x + TILE - w - 6.0, cell.y + TILE - 16.0, w + 6.0, 16.0), Color(0, 0, 0, 0.75))
			draw_string(font, Vector2(cell.x + TILE - w - 3.0, cell.y + TILE - 3.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
