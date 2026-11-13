class_name Hud
extends Control

# the in-run heads-up display, drawn directly each frame: crosshair and hit
# markers, health, dash charges, essence, weapon slots with their heat/charge
# meters, room and timer, combo, fracture timer, an enemy radar, the boss
# bar, damage-direction arcs, and prompts.

const RADAR_RANGE: float = 42.0
const RADAR_RADIUS: float = 92.0
const DAMAGE_ARC_TIME: float = 1.1

var accent: Color = Color(0.62, 1.0, 0.36)
var ui_scale: float = 1.0

var _player: CharacterBody3D
var _weapons: WeaponManager
var _run: RunManager
var _combo: ComboTracker
var _fracture: FractureManager
var _network: NetworkManager
var _pvp: PvPManager
var _boss: BossBase

var _prompt: String = ""
var _prompt_alpha: float = 0.0
var _hit_timer: float = 0.0
var _hit_color: Color = Color.WHITE
var _kill_timer: float = 0.0
var _ghost_health: float = 1.0
var _damage_arcs: Array[Dictionary] = []
var _enemy_count: int = 0
var _radar_dots: Array[Dictionary] = []
var _refresh: float = 0.0
var _boss_ghost: float = 1.0
var _essence_shown: float = 0.0
var _essence_pop: float = 0.0
var _last_essence: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind(player: CharacterBody3D, weapons: WeaponManager, run: RunManager, combo: ComboTracker, fracture: FractureManager) -> void:
	_player = player
	_weapons = weapons
	_run = run
	_combo = combo
	_fracture = fracture


func bind_network(manager: NetworkManager) -> void:
	_network = manager


func bind_pvp(manager: PvPManager) -> void:
	_pvp = manager


func set_boss(boss: BossBase) -> void:
	_boss = boss
	_boss_ghost = 1.0


func show_prompt(text: String) -> void:
	_prompt = text
	_prompt_alpha = 0.0


func hide_prompt() -> void:
	_prompt = ""


func show_hit(crit: bool, weak: bool) -> void:
	_hit_timer = 0.16
	_hit_color = Color(1.0, 0.3, 0.2) if crit else (Color(1.0, 0.82, 0.2) if weak else Color.WHITE)


func show_kill() -> void:
	_kill_timer = 0.3


## flashes an arc around the crosshair pointing at where damage came from.
func show_damage_from(world_pos: Vector3) -> void:
	_damage_arcs.append({"pos": world_pos, "time": DAMAGE_ARC_TIME})
	if _damage_arcs.size() > 6:
		_damage_arcs.pop_front()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		visible = not visible


func _process(delta: float) -> void:
	_hit_timer = maxf(0.0, _hit_timer - delta)
	_kill_timer = maxf(0.0, _kill_timer - delta)
	_essence_pop = maxf(0.0, _essence_pop - delta)
	if not _prompt.is_empty():
		_prompt_alpha = minf(1.0, _prompt_alpha + delta * 4.0)
	for arc: Dictionary in _damage_arcs:
		arc.time -= delta
	_damage_arcs = _damage_arcs.filter(func(a: Dictionary) -> bool: return a.time > 0.0)

	if is_instance_valid(_player):
		var ratio: float = float(_player.health) / float(maxi(_player.max_health, 1))
		_ghost_health = ratio if ratio > _ghost_health else maxf(ratio, _ghost_health - delta * 0.35)
	if is_instance_valid(_boss) and _boss.health:
		var br: float = _boss.health.ratio()
		_boss_ghost = br if br > _boss_ghost else maxf(br, _boss_ghost - delta * 0.25)
	if _run and _run.data:
		if _run.data.essence != _last_essence:
			_essence_pop = 0.25
			_last_essence = _run.data.essence
		_essence_shown = lerpf(_essence_shown, float(_run.data.essence), clampf(delta * 10.0, 0.0, 1.0))

	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.1
		_scan_enemies()
	queue_redraw()


func _scan_enemies() -> void:
	_radar_dots.clear()
	_enemy_count = 0
	if not is_instance_valid(_player):
		return
	var origin: Vector3 = _player.global_position
	var yaw: float = _player.rotation.y
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not e is Node3D or e.get("is_dying") == true:
			continue
		_enemy_count += 1
		var rel: Vector3 = (e as Node3D).global_position - origin
		# rotate into the player's frame: forward is up on the radar
		var local: Vector2 = Vector2(rel.x, rel.z).rotated(yaw)
		_radar_dots.append({"p": local, "elite": e.get("is_elite") == true, "boss": e is BossBase})


# --- drawing ------------------------------------------------------------------

func _draw() -> void:
	if not is_instance_valid(_player):
		return
	var s: Vector2 = size
	var k: float = ui_scale
	_draw_crosshair(s * 0.5, k)
	_draw_damage_arcs(s * 0.5, k)
	_draw_vitals(Vector2(56, s.y - 56) , k)
	_draw_weapons(Vector2(s.x - 56, s.y - 56), k)
	_draw_top(Vector2(s.x * 0.5, 34), k)
	_draw_combo(Vector2(56, 150), k)
	_draw_radar(Vector2(s.x - 56 - RADAR_RADIUS * k, 56 + RADAR_RADIUS * k), k)
	_draw_boss(Vector2(s.x * 0.5, 150), k)
	_draw_prompt(Vector2(s.x * 0.5, s.y - 150), k)


func _text(pos: Vector2, text: String, px: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, bold: bool = false) -> float:
	var font: Font = UiKit.font_bold() if bold else UiKit.font()
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var x: float = pos.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= w * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= w
	# a dark copy underneath keeps text readable over a bright scene
	draw_string(font, Vector2(x + 1.5, pos.y + 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(0, 0, 0, 0.7 * color.a))
	draw_string(font, Vector2(x, pos.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
	return w


func _bar(rect: Rect2, ratio: float, fill: Color, back: Color = Color(0, 0, 0, 0.55), ghost: float = -1.0) -> void:
	draw_rect(rect.grow(2.0), Color(0, 0, 0, 0.5))
	draw_rect(rect, back)
	if ghost > ratio:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ghost, 0.0, 1.0), rect.size.y)), Color(1, 1, 1, 0.55))
	if ratio > 0.0:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)), fill)


func _draw_crosshair(c: Vector2, k: float) -> void:
	var col: Color = Color(1, 1, 1, 0.9)
	if _player.is_invulnerable():
		col = Color(0.4, 0.9, 1.0, 0.95)
	var gap: float = 5.0 * k
	var length: float = 7.0 * k
	draw_circle(c, 1.8 * k, col)
	for d: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(c + d * gap, c + d * (gap + length), Color(0, 0, 0, 0.5), 4.0 * k)
		draw_line(c + d * gap, c + d * (gap + length), col, 2.0 * k)

	if _hit_timer > 0.0:
		var a: float = _hit_timer / 0.16
		var r0: float = (9.0 + (1.0 - a) * 5.0) * k
		var r1: float = r0 + 9.0 * k
		for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var n: Vector2 = d.normalized()
			draw_line(c + n * r0, c + n * r1, Color(_hit_color.r, _hit_color.g, _hit_color.b, a), 2.5 * k)
	if _kill_timer > 0.0:
		var a2: float = _kill_timer / 0.3
		var r: float = (16.0 + (1.0 - a2) * 16.0) * k
		draw_arc(c, r, 0.0, TAU, 28, Color(1.0, 0.35, 0.25, a2), 3.0 * k)

	# speed, the thing the whole game is about, right under the crosshair
	var speed: float = _player.horizontal_speed()
	var run_speed: float = _player.stats.value(&"move_speed")
	if speed > 2.0:
		var over: bool = speed > run_speed + 1.0
		_text(c + Vector2(0, 46 * k), "%d" % int(round(speed)), int(15 * k), accent if over else Color(1, 1, 1, 0.45), HORIZONTAL_ALIGNMENT_CENTER, over)


func _draw_damage_arcs(c: Vector2, k: float) -> void:
	for arc: Dictionary in _damage_arcs:
		var rel: Vector3 = arc.pos - _player.global_position
		var local: Vector2 = Vector2(rel.x, rel.z).rotated(_player.rotation.y)
		if local.length() < 0.1:
			continue
		# screen up is forward (-z in the player's frame)
		var angle: float = atan2(local.x, -local.y) - PI * 0.5
		var a: float = clampf(arc.time / DAMAGE_ARC_TIME, 0.0, 1.0)
		draw_arc(c, 150.0 * k, angle - 0.32, angle + 0.32, 14, Color(1.0, 0.15, 0.1, a * 0.9), 9.0 * k)


func _draw_vitals(anchor: Vector2, k: float) -> void:
	var w: float = 380.0 * k
	var h: float = 22.0 * k
	var rect: Rect2 = Rect2(anchor.x, anchor.y - h, w, h)
	var hp: int = _player.health
	var max_hp: int = _player.max_health
	var ratio: float = float(hp) / float(maxi(max_hp, 1))
	var fill: Color = accent
	if ratio <= 0.3:
		fill = Color(1.0, 0.25, 0.2).lerp(Color(1.0, 0.6, 0.5), 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012))
	elif ratio <= 0.6:
		fill = Color(1.0, 0.75, 0.2)
	_bar(rect, ratio, fill, Color(0, 0, 0, 0.55), _ghost_health)
	_text(Vector2(anchor.x, anchor.y - h - 10.0 * k), "%d" % hp, int(34 * k), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true)
	var hw: float = UiKit.font_bold().get_string_size("%d" % hp, HORIZONTAL_ALIGNMENT_LEFT, -1, int(34 * k)).x
	_text(Vector2(anchor.x + hw + 8.0 * k, anchor.y - h - 10.0 * k), "/ %d" % max_hp, int(18 * k), Color(1, 1, 1, 0.55))

	# dash charges: one diamond each, the next one filling as it recharges
	var charges: int = _player.dash_charges()
	var ready: int = _player.dash_charges_ready
	var recharge: float = _player.dash_recharge_ratio()
	for i: int in charges:
		var centre: Vector2 = Vector2(anchor.x + w + 28.0 * k + float(i) * 30.0 * k, anchor.y - h * 0.5)
		var fill_ratio: float = 1.0 if i < ready else (recharge if i == ready else 0.0)
		_diamond(centre, 11.0 * k, Color(0, 0, 0, 0.55))
		if fill_ratio > 0.0:
			_diamond(centre, 11.0 * k * (0.35 + 0.65 * fill_ratio), Color(0.4, 0.9, 1.0, 1.0 if fill_ratio >= 1.0 else 0.5))

	if _run and _run.data:
		var pop: float = 1.0 + _essence_pop * 1.2
		_diamond(Vector2(anchor.x + 9.0 * k, anchor.y + 20.0 * k), 7.0 * k * pop, accent)
		_text(Vector2(anchor.x + 24.0 * k, anchor.y + 27.0 * k), "%d" % int(round(_essence_shown)), int(20 * k), accent, HORIZONTAL_ALIGNMENT_LEFT, true)


func _diamond(c: Vector2, r: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), color)


func _draw_weapons(anchor: Vector2, k: float) -> void:
	if not is_instance_valid(_weapons) or _weapons.weapons.is_empty():
		return
	var y: float = anchor.y
	for i: int in range(_weapons.weapons.size() - 1, -1, -1):
		var weapon: BaseWeapon = _weapons.weapons[i]
		var active: bool = i == _weapons.active_index
		var px: int = int((26 if active else 17) * k)
		var col: Color = Color.WHITE if active else Color(1, 1, 1, 0.45)
		_text(Vector2(anchor.x, y), weapon.display_name, px, col, HORIZONTAL_ALIGNMENT_RIGHT, active)
		var name_w: float = (UiKit.font_bold() if active else UiKit.font()).get_string_size(weapon.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		_text(Vector2(anchor.x - name_w - 14.0 * k, y), "%d" % (i + 1), int(15 * k), accent if active else Color(1, 1, 1, 0.35), HORIZONTAL_ALIGNMENT_RIGHT, true)
		y -= float(px) + 6.0 * k

		if active:
			var state: Dictionary = weapon.hud_state()
			if state.has("meter"):
				var bw: float = 240.0 * k
				var rect: Rect2 = Rect2(anchor.x - bw, y - 2.0 * k, bw, 8.0 * k)
				_bar(rect, float(state.meter), state.get("meter_color", accent))
				var label: String = state.get("label", "")
				if not label.is_empty():
					var warn: bool = state.get("warn", false)
					var blink: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02) if warn else 1.0
					_text(Vector2(anchor.x - bw - 10.0 * k, y + 7.0 * k), label, int(14 * k),
						Color(1.0, 0.3, 0.2, blink) if warn else Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_RIGHT)
				y -= 22.0 * k


func _draw_top(c: Vector2, k: float) -> void:
	if not _run or not _run.data:
		return
	var data: RunData = _run.data
	var room: RunData.RoomData = data.current_room()
	if not room:
		return
	var head: String = "%s  ·  act %d" % [Biome.display_name(room.biome), room.act + 1]
	if data.is_endless():
		head = "%s  ·  depth %d" % [Biome.display_name(room.biome), data.current_room_index + 1]
	_text(c, head, int(15 * k), Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_CENTER)
	var line: String = "%s   %s" % [room.title(), UiKit.format_time(data.elapsed_time)]
	if not data.is_endless():
		line = "%d / %d   %s" % [data.current_room_index + 1, data.total_rooms(), line]
	_text(c + Vector2(0, 26 * k), line, int(22 * k), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	if _enemy_count > 0:
		_text(c + Vector2(0, 50 * k), "%d remaining" % _enemy_count, int(15 * k), Color(1.0, 0.6, 0.4, 0.9), HORIZONTAL_ALIGNMENT_CENTER)

	if is_instance_valid(_fracture) and _fracture.is_active:
		var fy: float = c.y + 74.0 * k
		var bw: float = 300.0 * k
		var col: Color = Color(0.95, 0.3, 1.0)
		_text(Vector2(c.x, fy), "fracture: %s" % _fracture.get_active_name(), int(17 * k), col, HORIZONTAL_ALIGNMENT_CENTER, true)
		_bar(Rect2(c.x - bw * 0.5, fy + 8.0 * k, bw, 5.0 * k), _fracture.get_time_ratio(), col)


func _draw_combo(anchor: Vector2, k: float) -> void:
	if not is_instance_valid(_combo) or _combo.combo_count < 2:
		return
	var mult: int = _combo.combo_multiplier
	var col: Color = Color(1.0, 0.85, 0.3) if mult >= 2 else Color(1, 1, 1, 0.8)
	var w: float = _text(anchor, "x%d" % mult, int(54 * k), col, HORIZONTAL_ALIGNMENT_LEFT, true)
	_text(anchor + Vector2(w + 12.0 * k, -8.0 * k), "%d kills" % _combo.combo_count, int(20 * k), Color(1, 1, 1, 0.8))
	_bar(Rect2(anchor.x, anchor.y + 10.0 * k, 190.0 * k, 5.0 * k), _combo.time_ratio(), col)


func _draw_radar(c: Vector2, k: float) -> void:
	var r: float = RADAR_RADIUS * k
	draw_circle(c, r, Color(0, 0, 0, 0.4))
	draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.22), 1.5)
	draw_arc(c, r * 0.5, 0.0, TAU, 28, Color(1, 1, 1, 0.1), 1.0)
	# the player: a small wedge pointing up (forward)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7) * k, c + Vector2(5, 5) * k, c + Vector2(-5, 5) * k]), accent)
	for dot: Dictionary in _radar_dots:
		var p: Vector2 = dot.p / RADAR_RANGE * r
		var far: bool = p.length() > r - 4.0
		if far:
			p = p.normalized() * (r - 4.0)
		var col: Color = Color(1.0, 0.3, 0.25, 0.5 if far else 0.95)
		var size_px: float = 3.2 * k
		if dot.boss:
			col = Color(1.0, 0.2, 0.9, 1.0)
			size_px = 7.0 * k
		elif dot.elite:
			col = Color(1.0, 0.7, 0.15, 1.0)
			size_px = 5.0 * k
		draw_circle(c + p, size_px, col)

	var y: float = c.y + r + 22.0 * k
	if is_instance_valid(_network) and _network.is_online():
		var ms: int = int(_network.estimated_ping_ms)
		var pc: Color = Color(0.5, 0.95, 0.55) if ms < 80 else (Color(0.95, 0.8, 0.3) if ms < 180 else Color(1.0, 0.4, 0.3))
		_text(Vector2(c.x + r, y), "ping %d ms" % ms, int(14 * k), pc, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 20.0 * k
	if is_instance_valid(_pvp) and _pvp.is_active():
		_text(Vector2(c.x + r, y), "pvp encounter", int(15 * k), Color(1.0, 0.3, 0.2), HORIZONTAL_ALIGNMENT_RIGHT, true)
		y += 20.0 * k
		_text(Vector2(c.x + r, y), "pvp health %d" % _pvp.get_pvp_health(_network.local_peer_id if _network else 1), int(14 * k), Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_boss(c: Vector2, k: float) -> void:
	if not is_instance_valid(_boss) or not _boss.health or _boss.is_dying:
		return
	var bw: float = 760.0 * k
	var bh: float = 16.0 * k
	var rect: Rect2 = Rect2(c.x - bw * 0.5, c.y, bw, bh)
	var ratio: float = _boss.health.ratio()
	var col: Color = Color(1.0, 0.3, 0.25) if not _boss.health.invulnerable else Color(0.7, 0.7, 0.75)
	_text(Vector2(c.x, c.y - 10.0 * k), _boss.title, int(24 * k), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	_bar(rect, ratio, col, Color(0, 0, 0, 0.6), _boss_ghost)
	# a tick at every phase threshold, so you can see the next change coming
	for t: float in _boss.phase_thresholds:
		var x: float = rect.position.x + bw * t
		draw_line(Vector2(x, rect.position.y - 3.0), Vector2(x, rect.position.y + bh + 3.0), Color(1, 1, 1, 0.8), 2.0)
	_text(Vector2(c.x + bw * 0.5, c.y + bh + 20.0 * k), "phase %d" % _boss.phase, int(14 * k), Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_prompt(c: Vector2, k: float) -> void:
	if _prompt.is_empty():
		return
	var px: int = int(22 * k)
	var w: float = UiKit.font_bold().get_string_size(_prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var pulse: float = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.005)
	draw_rect(Rect2(c.x - w * 0.5 - 22.0, c.y - px - 6.0, w + 44.0, px + 20.0), Color(0, 0, 0, 0.55 * _prompt_alpha))
	_text(c, _prompt, px, Color(1, 1, 1, _prompt_alpha * pulse), HORIZONTAL_ALIGNMENT_CENTER, true)
