class_name UiGlyphs
extends RefCounted

# the game's icons, drawn from lines and polygons at whatever size is asked
# for. there are no icon files: a card calls draw() from its own _draw().
#
# every glyph is designed in a square from -1 to 1 (y down) and scaled by `r`.

const WEAPON_GLYPHS: Dictionary = {
	&"pulse_rifle": &"w_rifle", &"scatter_cannon": &"w_scatter", &"beam_emitter": &"w_beam",
	&"needler": &"w_needles", &"spore_launcher": &"w_mortar", &"rail_lance": &"w_lance",
	&"arc_caster": &"w_arc", &"ripper": &"w_disc",
}

## which glyph stands for a player stat on an upgrade card
const STAT_GLYPHS: Dictionary = {
	&"damage": &"claw", &"fire_rate": &"chevrons", &"max_health": &"heart",
	&"dash_cooldown": &"dash", &"dash_charges": &"dash", &"dash_force": &"dash",
	&"move_speed": &"chevrons", &"crit_chance": &"crosshair", &"crit_mult": &"crosshair",
	&"weak_damage": &"eye", &"damage_taken": &"shield", &"jump_force": &"wing",
	&"air_jumps": &"wing", &"air_acceleration": &"wing", &"heat_gain": &"frost",
	&"blast_damage": &"burst", &"blast_radius": &"burst", &"pickup_radius": &"gem",
	&"essence_gain": &"gem", &"swap_speed": &"blade", &"recoil": &"blade",
	&"dot_damage": &"flame", &"orb_heal": &"drop", &"combo_time": &"hourglass",
	&"slide_friction": &"blade", &"fov_bias": &"eye",
}

## and for an upgrade whose effect is scripted
const SPECIAL_GLYPHS: Dictionary = {
	&"kill_heal": &"drop", &"heal_25": &"heart", &"heal_40": &"heart", &"heal_full": &"heart",
	&"momentum_rounds": &"chevrons", &"kinetic_plating": &"shield", &"adrenaline_surge": &"chevrons",
	&"chain_reaction": &"burst", &"explosive_dash": &"burst", &"null_field": &"pulse",
	&"unstable_rounds": &"burst", &"temporal_break": &"hourglass", &"impact_slam": &"slam",
	&"razor_slide": &"blade", &"second_wind": &"heart", &"leech": &"drop",
	&"executioner": &"skull", &"phase_dash": &"dash", &"ignition": &"flame",
	&"cryo_rounds": &"frost", &"hunter_mark": &"eye", &"pyromaniac": &"flame",
	&"opening_shot": &"crosshair", &"elite_hunter": &"skull", &"shrapnel": &"shards",
	&"bloodlust": &"claw", &"predator_reflex": &"dash", &"sky_hunter": &"wing",
	&"full_bloom": &"heart", &"gilded_marrow": &"gem", &"bone_plating": &"shield",
	&"thorns": &"shards", &"adrenal_rush": &"bolt", &"recoil_pulse": &"pulse",
	&"storm_caller": &"bolt", &"brood_familiar": &"orbit", &"power_surge": &"bolt",
	&"berserker_pact": &"skull", &"borrowed_time": &"hourglass",
}

const ROOM_GLYPHS: Dictionary = {
	RoomDefinitions.RoomType.COMBAT: &"claw",
	RoomDefinitions.RoomType.SWARM: &"pack",
	RoomDefinitions.RoomType.ELITE: &"crown",
	RoomDefinitions.RoomType.RECOVERY: &"heart",
	RoomDefinitions.RoomType.TRANSITION: &"chevrons",
	RoomDefinitions.RoomType.BOSS: &"horns",
	RoomDefinitions.RoomType.HAZARD: &"flame",
	RoomDefinitions.RoomType.GAUNTLET: &"waves",
	RoomDefinitions.RoomType.ELITE_CHAMBER: &"skull",
	RoomDefinitions.RoomType.SHOP: &"gem",
}


static func for_upgrade(u: Dictionary) -> StringName:
	var weapon: StringName = u.get("weapon", &"")
	if weapon != &"":
		return WEAPON_GLYPHS.get(weapon, &"claw")
	var special: StringName = u.get("special", &"")
	if SPECIAL_GLYPHS.has(special):
		return SPECIAL_GLYPHS[special]
	for mod: Array in u.get("mods", []):
		if STAT_GLYPHS.has(mod[0]):
			return STAT_GLYPHS[mod[0]]
	return &"claw"


static func for_room(type: int) -> StringName:
	return ROOM_GLYPHS.get(type, &"claw")


static func known() -> Array[StringName]:
	return [
		&"claw", &"chevrons", &"heart", &"dash", &"crosshair", &"shield", &"wing", &"burst",
		&"gem", &"flame", &"frost", &"bolt", &"skull", &"orbit", &"hourglass", &"blade",
		&"drop", &"helix", &"pulse", &"eye", &"slam", &"shards", &"pack", &"crown", &"waves",
		&"horns", &"dice", &"w_rifle", &"w_scatter", &"w_beam", &"w_needles", &"w_mortar",
		&"w_lance", &"w_arc", &"w_disc",
	]


## draws glyph `id` centred on `c`, fitting a square of half-size `r`.
static func draw(ci: CanvasItem, id: StringName, c: Vector2, r: float, col: Color, width: float = 0.0) -> void:
	var w: float = width if width > 0.0 else maxf(1.5, r * 0.085)
	match id:
		&"claw":
			for i: int in 3:
				var x: float = -0.5 + float(i) * 0.5
				ci.draw_colored_polygon(_pts(c, r, [Vector2(x - 0.2, -0.8), Vector2(x + 0.06, -0.8), Vector2(x + 0.34, 0.8), Vector2(x + 0.2, 0.8)]), col)
		&"chevrons":
			for i: int in 3:
				var x: float = -0.7 + float(i) * 0.5
				ci.draw_polyline(_pts(c, r, [Vector2(x, -0.6), Vector2(x + 0.45, 0.0), Vector2(x, 0.6)]), col, w * 1.3, true)
		&"heart":
			var pts: PackedVector2Array = PackedVector2Array()
			for i: int in 28:
				var t: float = TAU * float(i) / 28.0
				pts.append(c + Vector2(16.0 * pow(sin(t), 3.0), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))) * (r / 18.0))
			ci.draw_colored_polygon(pts, col)
		&"dash":
			ci.draw_line(c + Vector2(-0.25, 0.0) * r, c + Vector2(0.45, 0.0) * r, col, w * 1.4, true)
			ci.draw_colored_polygon(_pts(c, r, [Vector2(0.9, 0.0), Vector2(0.35, -0.42), Vector2(0.35, 0.42)]), col)
			for i: int in 3:
				var y: float = -0.42 + float(i) * 0.42
				ci.draw_line(c + Vector2(-0.9, y) * r, c + Vector2(-0.45 - absf(y) * 0.3, y) * r, col, w, true)
		&"crosshair":
			ci.draw_arc(c, r * 0.58, 0.0, TAU, 28, col, w, true)
			for i: int in 4:
				var d: Vector2 = Vector2.RIGHT.rotated(PI * 0.5 * float(i))
				ci.draw_line(c + d * r * 0.32, c + d * r * 0.95, col, w, true)
			ci.draw_circle(c, r * 0.1, col)
		&"shield":
			var outline: PackedVector2Array = _pts(c, r, [Vector2(0, -0.9), Vector2(0.75, -0.6), Vector2(0.75, 0.05), Vector2(0, 0.92), Vector2(-0.75, 0.05), Vector2(-0.75, -0.6), Vector2(0, -0.9)])
			ci.draw_polyline(outline, col, w * 1.2, true)
			ci.draw_colored_polygon(_pts(c, r, [Vector2(0, -0.55), Vector2(0.42, -0.4), Vector2(0.42, 0.0), Vector2(0, 0.5)]), col)
		&"wing":
			for i: int in 4:
				var a: float = -1.25 + float(i) * 0.36
				var tip: Vector2 = Vector2(cos(a), sin(a)) * (1.5 - float(i) * 0.2) + Vector2(-0.75, 0.7)
				ci.draw_colored_polygon(_pts(c, r, [Vector2(-0.75, 0.7), tip + Vector2(-0.1, -0.06), tip, Vector2(-0.55, 0.78)]), col)
		&"burst":
			var star: PackedVector2Array = PackedVector2Array()
			for i: int in 16:
				var rad: float = 0.95 if i % 2 == 0 else 0.42
				star.append(c + Vector2.UP.rotated(TAU * float(i) / 16.0) * r * rad)
			ci.draw_colored_polygon(star, col)
		&"gem":
			ci.draw_polyline(_pts(c, r, [Vector2(0, -0.9), Vector2(0.7, -0.2), Vector2(0, 0.9), Vector2(-0.7, -0.2), Vector2(0, -0.9)]), col, w * 1.2, true)
			ci.draw_polyline(_pts(c, r, [Vector2(-0.7, -0.2), Vector2(0.7, -0.2)]), col, w, true)
			ci.draw_polyline(_pts(c, r, [Vector2(-0.28, -0.2), Vector2(0, 0.9), Vector2(0.28, -0.2), Vector2(0, -0.9), Vector2(-0.28, -0.2)]), col, w * 0.7, true)
		&"flame":
			ci.draw_colored_polygon(_pts(c, r, [
				Vector2(0.05, -0.95), Vector2(0.5, -0.3), Vector2(0.38, 0.0), Vector2(0.68, -0.18), Vector2(0.62, 0.5),
				Vector2(0.3, 0.9), Vector2(-0.3, 0.9), Vector2(-0.62, 0.5), Vector2(-0.55, -0.05), Vector2(-0.25, 0.2), Vector2(-0.2, -0.4),
			]), col)
		&"frost":
			for i: int in 3:
				var d: Vector2 = Vector2.UP.rotated(PI / 3.0 * float(i))
				ci.draw_line(c - d * r * 0.9, c + d * r * 0.9, col, w, true)
				for s: float in [-1.0, 1.0]:
					var base: Vector2 = c + d * r * 0.55 * s
					ci.draw_line(base, base + d.rotated(0.9) * r * 0.26 * s, col, w, true)
					ci.draw_line(base, base + d.rotated(-0.9) * r * 0.26 * s, col, w, true)
		&"bolt":
			ci.draw_colored_polygon(_pts(c, r, [Vector2(0.25, -0.95), Vector2(-0.55, 0.12), Vector2(-0.05, 0.12), Vector2(-0.3, 0.95), Vector2(0.6, -0.2), Vector2(0.08, -0.2)]), col)
		&"skull":
			_skull(ci, c, r, col, w)
		&"horns":
			_skull(ci, c + Vector2(0, r * 0.18), r * 0.8, col, w)
			for s: float in [-1.0, 1.0]:
				ci.draw_colored_polygon(_pts(c, r, [Vector2(s * 0.42, -0.42), Vector2(s * 0.95, -0.95), Vector2(s * 0.8, -0.3), Vector2(s * 0.56, -0.12)]), col)
		&"orbit":
			ci.draw_circle(c, r * 0.28, col)
			var ring: PackedVector2Array = PackedVector2Array()
			for i: int in 33:
				var t: float = TAU * float(i) / 32.0
				ring.append(c + Vector2(cos(t) * 0.92, sin(t) * 0.42).rotated(-0.5) * r)
			ci.draw_polyline(ring, col, w, true)
			ci.draw_circle(c + Vector2(0.92, 0.0).rotated(-0.5) * r, r * 0.14, col)
		&"hourglass":
			ci.draw_colored_polygon(_pts(c, r, [Vector2(-0.6, -0.85), Vector2(0.6, -0.85), Vector2(0.0, 0.0)]), col)
			ci.draw_polyline(_pts(c, r, [Vector2(0.0, 0.0), Vector2(0.6, 0.85), Vector2(-0.6, 0.85), Vector2(0.0, 0.0)]), col, w * 1.2, true)
			ci.draw_line(c + Vector2(-0.75, -0.9) * r, c + Vector2(0.75, -0.9) * r, col, w * 1.4, true)
			ci.draw_line(c + Vector2(-0.75, 0.9) * r, c + Vector2(0.75, 0.9) * r, col, w * 1.4, true)
		&"blade":
			ci.draw_arc(c + Vector2(0.15, 0.15) * r, r * 0.75, PI * 0.95, PI * 1.9, 20, col, w * 2.4, true)
			ci.draw_line(c + Vector2(-0.6, 0.35) * r, c + Vector2(-0.85, 0.9) * r, col, w * 1.6, true)
		&"drop":
			var drop: PackedVector2Array = PackedVector2Array([c + Vector2(0, -0.95) * r])
			for i: int in 15:
				var t: float = -0.25 + (PI + 0.5) * float(i) / 14.0
				drop.append(c + Vector2(cos(t) * 0.6, 0.3 + sin(t) * 0.6) * r)
			ci.draw_colored_polygon(drop, col)
		&"helix":
			var left: PackedVector2Array = PackedVector2Array()
			var right: PackedVector2Array = PackedVector2Array()
			for i: int in 25:
				var y: float = -0.9 + 1.8 * float(i) / 24.0
				var x: float = sin(y * 3.4) * 0.5
				left.append(c + Vector2(x, y) * r)
				right.append(c + Vector2(-x, y) * r)
				if i % 4 == 2:
					ci.draw_line(c + Vector2(x, y) * r, c + Vector2(-x, y) * r, col, w * 0.7, true)
			ci.draw_polyline(left, col, w * 1.3, true)
			ci.draw_polyline(right, col, w * 1.3, true)
		&"pulse":
			ci.draw_circle(c, r * 0.16, col)
			for i: int in 3:
				ci.draw_arc(c, r * (0.4 + 0.26 * float(i)), -0.9, 0.9, 12, col, w, true)
				ci.draw_arc(c, r * (0.4 + 0.26 * float(i)), PI - 0.9, PI + 0.9, 12, col, w, true)
		&"eye":
			var lid: PackedVector2Array = PackedVector2Array()
			for i: int in 17:
				var t: float = float(i) / 16.0
				lid.append(c + Vector2(-0.95 + 1.9 * t, -sin(t * PI) * 0.6) * r)
			for i: int in 17:
				var t: float = float(i) / 16.0
				lid.append(c + Vector2(0.95 - 1.9 * t, sin(t * PI) * 0.6) * r)
			lid.append(lid[0])
			ci.draw_polyline(lid, col, w * 1.2, true)
			ci.draw_circle(c, r * 0.3, col)
		&"slam":
			ci.draw_line(c + Vector2(0, -0.9) * r, c + Vector2(0, 0.1) * r, col, w * 1.6, true)
			ci.draw_colored_polygon(_pts(c, r, [Vector2(0, 0.55), Vector2(-0.4, 0.0), Vector2(0.4, 0.0)]), col)
			ci.draw_line(c + Vector2(-0.9, 0.7) * r, c + Vector2(0.9, 0.7) * r, col, w * 1.4, true)
			for s: float in [-1.0, 1.0]:
				ci.draw_line(c + Vector2(s * 0.55, 0.55) * r, c + Vector2(s * 0.85, 0.2) * r, col, w, true)
		&"shards":
			for i: int in 5:
				var a: float = -PI * 0.5 + (float(i) - 2.0) * 0.5
				var d: Vector2 = Vector2(cos(a), sin(a))
				var n: Vector2 = d.orthogonal()
				var base: Vector2 = c + Vector2(0, 0.75 * r) + d * r * 0.25
				ci.draw_colored_polygon(PackedVector2Array([base + n * r * 0.1, base + d * r * (1.25 - absf(float(i) - 2.0) * 0.16), base - n * r * 0.1]), col)
		&"pack":
			for p: Vector2 in [Vector2(0, -0.55), Vector2(-0.6, 0.4), Vector2(0.6, 0.4), Vector2(0, 0.08)]:
				ci.draw_circle(c + p * r, r * (0.26 if p.y != 0.08 else 0.14), col)
		&"crown":
			ci.draw_colored_polygon(_pts(c, r, [
				Vector2(-0.85, 0.55), Vector2(-0.95, -0.5), Vector2(-0.45, 0.05), Vector2(0.0, -0.8),
				Vector2(0.45, 0.05), Vector2(0.95, -0.5), Vector2(0.85, 0.55),
			]), col)
			ci.draw_line(c + Vector2(-0.85, 0.8) * r, c + Vector2(0.85, 0.8) * r, col, w * 1.4, true)
		&"waves":
			for i: int in 3:
				var wave: PackedVector2Array = PackedVector2Array()
				var y: float = -0.55 + 0.55 * float(i)
				for j: int in 17:
					var t: float = float(j) / 16.0
					wave.append(c + Vector2(-0.9 + 1.8 * t, y + sin(t * TAU * 1.5) * 0.16) * r)
				ci.draw_polyline(wave, col, w * 1.2, true)
		&"dice":
			ci.draw_polyline(_pts(c, r, [Vector2(-0.75, -0.75), Vector2(0.75, -0.75), Vector2(0.75, 0.75), Vector2(-0.75, 0.75), Vector2(-0.75, -0.75)]), col, w * 1.2, true)
			for p: Vector2 in [Vector2(-0.38, -0.38), Vector2(0.38, 0.38), Vector2(0, 0), Vector2(0.38, -0.38), Vector2(-0.38, 0.38)]:
				ci.draw_circle(c + p * r, r * 0.11, col)
		&"w_rifle":
			ci.draw_line(c + Vector2(-0.9, 0.0) * r, c + Vector2(0.1, 0.0) * r, col, w * 2.4, true)
			ci.draw_line(c + Vector2(-0.7, 0.0) * r, c + Vector2(-0.85, 0.55) * r, col, w * 1.8, true)
			for i: int in 3:
				ci.draw_line(c + Vector2(0.3 + 0.24 * float(i), 0.0) * r, c + Vector2(0.42 + 0.24 * float(i), 0.0) * r, col, w * 1.3, true)
		&"w_scatter":
			for i: int in 5:
				var a: float = (float(i) - 2.0) * 0.3
				ci.draw_line(c + Vector2(-0.8, 0.0) * r, c + Vector2(-0.8, 0.0) * r + Vector2(cos(a), sin(a)) * r * 1.3, col, w, true)
				ci.draw_circle(c + Vector2(-0.8, 0.0) * r + Vector2(cos(a), sin(a)) * r * 1.5, r * 0.1, col)
		&"w_beam":
			ci.draw_line(c + Vector2(-0.9, 0.0) * r, c + Vector2(0.45, 0.0) * r, col, w * 2.6, true)
			ci.draw_arc(c + Vector2(0.6, 0.0) * r, r * 0.3, 0.0, TAU, 18, col, w, true)
			ci.draw_circle(c + Vector2(0.6, 0.0) * r, r * 0.12, col)
		&"w_needles":
			for i: int in 4:
				var o: Vector2 = Vector2(-0.45 + 0.3 * float(i), 0.3 - 0.2 * float(i))
				ci.draw_colored_polygon(_pts(c, r, [o + Vector2(-0.5, 0.42), o + Vector2(0.55, -0.5), o + Vector2(-0.38, 0.5)]), col)
		&"w_mortar":
			var arc: PackedVector2Array = PackedVector2Array()
			for i: int in 17:
				var t: float = float(i) / 16.0
				arc.append(c + Vector2(-0.85 + 1.5 * t, 0.6 - sin(t * PI) * 1.3) * r)
			ci.draw_polyline(arc, col, w, true)
			ci.draw_circle(c + Vector2(0.65, 0.6) * r, r * 0.24, col)
		&"w_lance":
			ci.draw_line(c + Vector2(-0.95, 0.55) * r, c + Vector2(0.35, -0.2) * r, col, w * 1.6, true)
			ci.draw_colored_polygon(_pts(c, r, [Vector2(0.95, -0.55), Vector2(0.25, -0.38), Vector2(0.42, -0.02)]), col)
		&"w_arc":
			ci.draw_polyline(_pts(c, r, [Vector2(-0.9, 0.1), Vector2(-0.45, -0.45), Vector2(-0.1, 0.35), Vector2(0.3, -0.4), Vector2(0.6, 0.25), Vector2(0.92, -0.15)]), col, w * 1.5, true)
		&"w_disc":
			ci.draw_arc(c, r * 0.5, 0.0, TAU, 24, col, w * 1.4, true)
			ci.draw_circle(c, r * 0.14, col)
			for i: int in 8:
				var a: float = TAU * float(i) / 8.0
				var d: Vector2 = Vector2(cos(a), sin(a))
				ci.draw_colored_polygon(PackedVector2Array([c + d * r * 0.55, c + d.rotated(0.32) * r * 0.95, c + d.rotated(0.5) * r * 0.55]), col)
		_:
			ci.draw_arc(c, r * 0.6, 0.0, TAU, 20, col, w, true)


static func _skull(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
	var head: PackedVector2Array = PackedVector2Array()
	for i: int in 17:
		var t: float = PI + PI * float(i) / 16.0
		head.append(c + Vector2(cos(t) * 0.75, -0.1 + sin(t) * 0.75) * r)
	head.append_array(_pts(c, r, [Vector2(0.75, 0.3), Vector2(0.45, 0.45), Vector2(0.45, 0.9), Vector2(-0.45, 0.9), Vector2(-0.45, 0.45), Vector2(-0.75, 0.3)]))
	head.append(head[0])
	ci.draw_polyline(head, col, w * 1.2, true)
	ci.draw_circle(c + Vector2(-0.3, 0.0) * r, r * 0.19, col)
	ci.draw_circle(c + Vector2(0.3, 0.0) * r, r * 0.19, col)
	for i: int in 3:
		var x: float = -0.22 + 0.22 * float(i)
		ci.draw_line(c + Vector2(x, 0.55) * r, c + Vector2(x, 0.9) * r, col, w * 0.8, true)


static func _pts(c: Vector2, r: float, unit: Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in unit:
		out.append(c + p * r)
	return out
