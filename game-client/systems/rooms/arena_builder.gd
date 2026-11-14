class_name ArenaBuilder
extends RefCounted

# builds one room's arena: picks a layout, raises the walls, adds decks, ramps
# and jump pads, scatters cover and set dressing, and lays hazards.
#
# every random choice comes from the rng it is given, which the room seeds
# from the room's own seed, so every peer in a co-op game builds exactly the
# same arena without sending any of it over the network.

const WALL_HEIGHT: float = 9.0
const WALL_COLLISION_HEIGHT: float = 40.0
const WALL_THICKNESS: float = 1.2
const DECK_HEIGHT: float = 1.7
const RAMP_ANGLE: float = 0.47
const MAX_LAMPS: int = 6

const WALL_SHADER: String = """
shader_type spatial;
uniform vec3 base_color : source_color = vec3(0.1, 0.12, 0.1);
uniform vec3 glow_color : source_color = vec3(0.6, 1.0, 0.36);
uniform float wall_height = 9.0;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float h = clamp(wp.y / wall_height, 0.0, 1.0);
	float along = wp.x * 0.7 + wp.z * 0.7;
	float rib = smoothstep(0.38, 0.5, abs(fract(along / 2.6) - 0.5));
	float base_glow = pow(1.0 - h, 4.0);
	float crown = smoothstep(0.94, 1.0, h);
	float pulse = 0.8 + 0.2 * sin(TIME * 0.9 + along * 0.3);
	ALBEDO = base_color * (0.5 + 0.5 * (1.0 - rib));
	ROUGHNESS = 0.75;
	EMISSION = glow_color * (base_glow * 0.12 + crown * 0.55 + rib * (1.0 - h) * 0.05) * pulse;
}
"""

var room: RunData.RoomData
var rng: RandomNumberGenerator
var shape: ArenaShape
var template: StringName = &"open"
var player_spawn: Vector3 = Vector3(0, 2, 0)
var boss_spawn: Vector3 = Vector3(0, 0.2, -12)
var focus_point: Vector3 = Vector3.ZERO
var blocked: Array[Rect2] = []

var _arena_root: Node3D
var _hazard_root: Node3D
var _lib: ModelLibrary
var _biome: Dictionary
var _skin: StringName = &"default"
var _wall_material: ShaderMaterial
var _deck_material: StandardMaterial3D
var _glow_material: StandardMaterial3D
var _lamps: int = 0

static var _wall_shader: Shader


func build(p_room: RunData.RoomData, p_rng: RandomNumberGenerator, arena_root: Node3D, hazard_root: Node3D, lib: ModelLibrary) -> void:
	room = p_room
	rng = p_rng
	_arena_root = arena_root
	_hazard_root = hazard_root
	_lib = lib
	_biome = Biome.get_def(room.biome)
	_skin = _biome.obstacle_skin
	_make_materials()

	template = _choose_template()
	match template:
		&"sanctum": _layout_sanctum()
		&"tiers": _layout_tiers()
		&"hall": _layout_hall()
		&"junction": _layout_junction()
		&"orbit": _layout_orbit()
		&"lanes": _layout_lanes()
		&"grove": _layout_grove()
		&"bridges": _layout_bridges()
		&"colosseum": _layout_colosseum()
		&"warren": _layout_warren()
		&"spires": _layout_spires()
		&"boss_warden": _layout_boss_warden()
		&"boss_matriarch": _layout_boss_matriarch()
		&"boss_stalker": _layout_boss_stalker()
		&"boss_titan": _layout_boss_titan()
		&"boss_core": _layout_boss_core()
		&"boss_harrower": _layout_boss_harrower()
		&"boss_choir": _layout_boss_choir()
		_: _layout_open()

	_build_walls()
	_decorate()
	_place_hazards()
	_place_fields()


func _choose_template() -> StringName:
	match room.type:
		RoomDefinitions.RoomType.BOSS:
			match room.boss_id:
				&"warden": return &"boss_warden"
				&"matriarch": return &"boss_matriarch"
				&"stalker": return &"boss_stalker"
				&"core": return &"boss_core"
				&"harrower": return &"boss_harrower"
				&"choir": return &"boss_choir"
			return &"boss_titan"
		RoomDefinitions.RoomType.RECOVERY, RoomDefinitions.RoomType.SHOP, RoomDefinitions.RoomType.TRANSITION:
			return &"sanctum"
		RoomDefinitions.RoomType.GAUNTLET:
			return &"lanes" if rng.randf() < 0.6 else &"warren"
		RoomDefinitions.RoomType.ELITE_CHAMBER:
			return &"tiers" if rng.randf() < 0.6 else &"colosseum"
	var roll: float = rng.randf()
	# a room can name its own layout (tests do, to see a particular one)
	var named: String = String(room.metadata.get("layout", ""))
	if not named.is_empty() and has_method("_layout_%s" % named):
		return StringName(named)
	if room.type == RoomDefinitions.RoomType.SWARM:
		# swarms want floor: nothing that splits the room in two
		return _weighted(roll, [[&"open", 0.4], [&"hall", 0.2], [&"junction", 0.15], [&"colosseum", 0.15], [&"grove", 0.1]])
	return _weighted(roll, [
		[&"open", 0.16], [&"tiers", 0.12], [&"hall", 0.12], [&"junction", 0.1], [&"orbit", 0.1],
		[&"grove", 0.1], [&"bridges", 0.08], [&"colosseum", 0.08], [&"warren", 0.08], [&"spires", 0.06],
	])


## the entry of `table` ([[name, weight], ...]) that `roll` (0..1) lands in.
static func _weighted(roll: float, table: Array) -> StringName:
	var total: float = 0.0
	for entry: Array in table:
		total += float(entry[1])
	var at: float = roll * total
	for entry: Array in table:
		at -= float(entry[1])
		if at <= 0.0:
			return entry[0]
	return table[0][0]


## which side of a deck (as _deck numbers them) faces along `v`.
static func _side_toward(v: Vector3) -> int:
	if absf(v.x) >= absf(v.z):
		return 0 if v.x > 0.0 else 1
	return 2 if v.z > 0.0 else 3


# --- layouts -------------------------------------------------------------------

func _layout_open() -> void:
	shape = ArenaShape.disc(34.0)
	player_spawn = Vector3(0, 2, 0)
	_claim(Vector3.ZERO, 4.0, 4.0)
	var pads: int = 3
	for i: int in pads:
		var a: float = TAU * float(i) / float(pads) + rng.randf() * 0.6
		_jump_pad(Vector3(cos(a), 0, sin(a)) * 26.0, Vector3(-cos(a), 0, -sin(a)) * 9.0 + Vector3(0, 19, 0))
	_scatter_cover(_cover_count(8, 14))
	if room.difficulty >= 1.5:
		for i: int in 2:
			var p: Vector3 = _free_point(8.0, 5.0)
			if p != Vector3.INF:
				_deck(p, Vector3(rng.randf_range(4.0, 6.0), DECK_HEIGHT * 0.7, rng.randf_range(4.0, 6.0)), [0, 2])


func _layout_tiers() -> void:
	# a raised dais in the middle with ramps on all four sides
	shape = ArenaShape.disc(33.0)
	_deck(Vector3.ZERO, Vector3(13.0, DECK_HEIGHT, 13.0), [0, 1, 2, 3])
	player_spawn = Vector3(0, DECK_HEIGHT + 2.0, 0)
	for i: int in 4:
		var a: float = TAU * float(i) / 4.0 + PI * 0.25
		var at: Vector3 = Vector3(cos(a), 0, sin(a)) * 25.0
		_jump_pad(at, Vector3(-cos(a), 0, -sin(a)) * 12.0 + Vector3(0, 18, 0))
		_tall_pillar(Vector3(cos(a), 0, sin(a)) * 16.0)
	_scatter_cover(_cover_count(6, 10))


func _layout_hall() -> void:
	# a long hall with raised galleries down both sides
	shape = ArenaShape.rect(32.0, 19.0)
	player_spawn = Vector3(-24.0, 2, 0)
	_claim(player_spawn, 4.0, 4.0)
	for s: float in [-1.0, 1.0]:
		_deck(Vector3(0, 0, s * 15.0), Vector3(40.0, DECK_HEIGHT, 6.0), [0, 1])
		_jump_pad(Vector3(0, 0, s * 9.5), Vector3(0, 17, s * 6.0))
	for i: int in 5:
		_trunk(Vector3(-20.0 + float(i) * 10.0, 0, rng.randf_range(-2.0, 2.0)))
	_scatter_cover(_cover_count(5, 9))


func _layout_junction() -> void:
	# four arms meeting at a hub
	shape = ArenaShape.cross(9.5, 31.0)
	player_spawn = Vector3(0, 2, 0)
	_claim(Vector3.ZERO, 4.0, 4.0)
	for i: int in 4:
		var dir: Vector3 = Vector3(1, 0, 0).rotated(Vector3.UP, PI * 0.5 * float(i))
		# a deck at the end of each arm, ramp facing the hub
		_deck(dir * 25.0, Vector3(9.0, DECK_HEIGHT * 0.8, 9.0), [_side_toward(-dir)])
		_low_wall(dir * 12.0 + dir.cross(Vector3.UP) * rng.randf_range(-3.0, 3.0), atan2(dir.x, dir.z) + PI * 0.5)
		_jump_pad(dir * 16.5 + dir.cross(Vector3.UP) * 6.0, dir * 10.0 + Vector3(0, 17, 0))
	_scatter_cover(_cover_count(4, 8))


func _layout_orbit() -> void:
	# a ring around a mass that blocks every sightline through the middle
	shape = ArenaShape.ring(34.0, 9.0)
	player_spawn = Vector3(0, 2, 21.0)
	_claim(player_spawn, 4.0, 4.0)
	_central_mass(9.0)
	for i: int in 4:
		var a: float = TAU * float(i) / 4.0 + PI * 0.25
		_jump_pad(Vector3(cos(a), 0, sin(a)) * 27.0, Vector3(-sin(a), 0, cos(a)) * 13.0 + Vector3(0, 17, 0))
	for i: int in 3:
		var a: float = TAU * float(i) / 3.0 + rng.randf()
		_deck(Vector3(cos(a), 0, sin(a)) * 20.0, Vector3(6.0, DECK_HEIGHT * 0.75, 6.0), [0, 2])
	_scatter_cover(_cover_count(6, 11))


func _layout_lanes() -> void:
	# gauntlet: a long room of staggered barriers
	shape = ArenaShape.rect(34.0, 14.0)
	player_spawn = Vector3(-28.0, 2, 0)
	_claim(player_spawn, 4.0, 4.0)
	for i: int in 6:
		var x: float = -20.0 + float(i) * 8.0
		var z: float = (-5.5 if i % 2 == 0 else 5.5) + rng.randf_range(-1.5, 1.5)
		if i % 3 == 2:
			_breakable_wall(Vector3(x, 0, z), PI * 0.5)
		else:
			_half_cover(Vector3(x, 0, z), PI * 0.5)
	for i: int in 3:
		_tall_pillar(Vector3(-12.0 + float(i) * 12.0, 0, 0))
	_jump_pad(Vector3(0, 0, -10.5), Vector3(0, 17, 7.0))
	_jump_pad(Vector3(0, 0, 10.5), Vector3(0, 17, -7.0))


func _layout_grove() -> void:
	# a forest of trunks and spires: nothing has a long sightline, and everything is cover
	shape = ArenaShape.disc(33.0)
	player_spawn = Vector3(0, 2, 0)
	_claim(Vector3.ZERO, 4.0, 4.0)
	for ring: Array in [[9.5, 5], [17.0, 8], [25.5, 11]]:
		var turn: float = rng.randf() * TAU
		var count: int = ring[1]
		for i: int in count:
			var a: float = turn + TAU * float(i) / float(count) + rng.randf_range(-0.12, 0.12)
			var at: Vector3 = Vector3(cos(a), 0, sin(a)) * (float(ring[0]) + rng.randf_range(-1.2, 1.2))
			if i % 3 == 0:
				_trunk(at, rng.randf_range(1.0, 1.4))
			else:
				_tall_pillar(at)
	for i: int in 2:
		var a: float = PI * float(i) + rng.randf() * 0.8
		_jump_pad(Vector3(cos(a), 0, sin(a)) * 29.5, Vector3(-cos(a), 0, -sin(a)) * 12.0 + Vector3(0, 19, 0))
	_scatter_cover(_cover_count(2, 5))


func _layout_bridges() -> void:
	# two galleries and a crossing between them: the floor is two pits with high ground on three sides
	shape = ArenaShape.rect(31.0, 21.0)
	player_spawn = Vector3(-25.0, 2, 0)
	_claim(player_spawn, 4.0, 4.0)
	for s: float in [-1.0, 1.0]:
		_deck(Vector3(0, 0, s * 16.5), Vector3(38.0, DECK_HEIGHT, 6.0), [0, 1])
		_jump_pad(Vector3(s * 14.0, 0, s * 9.0), Vector3(0, 17, s * 6.5))
	_deck(Vector3(4.0, 0, 0), Vector3(9.0, DECK_HEIGHT, 11.0), [0, 1])
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_tall_pillar(Vector3(4.0 + sx * 13.0, 0, sz * 6.0))
	_scatter_cover(_cover_count(4, 8))


func _layout_colosseum() -> void:
	# a pit ringed with stands: fight in the open, or take a stand and hold its ramp
	shape = ArenaShape.disc(35.0)
	player_spawn = Vector3(0, 2, 0)
	_claim(Vector3.ZERO, 4.0, 4.0)
	var stands: int = 6
	var turn: float = rng.randf() * TAU
	for i: int in stands:
		var a: float = turn + TAU * float(i) / float(stands)
		var dir: Vector3 = Vector3(cos(a), 0, sin(a))
		_deck(dir * 25.5, Vector3(7.0, DECK_HEIGHT * (0.8 if i % 2 == 0 else 1.2), 7.0), [_side_toward(-dir)])
		var b: float = a + PI / float(stands)
		if i % 2 == 0:
			_jump_pad(Vector3(cos(b), 0, sin(b)) * 12.0, Vector3(cos(b), 0, sin(b)) * 12.0 + Vector3(0, 18, 0))
		else:
			_low_wall(Vector3(cos(b), 0, sin(b)) * 14.0, -b)
	_scatter_cover(_cover_count(3, 6))


func _layout_warren() -> void:
	# a grid of low walls: lanes to run, corners to break line of sight, nothing tall
	shape = ArenaShape.rect(31.0, 21.0)
	player_spawn = Vector3(-26.0, 2, 0)
	_claim(player_spawn, 4.0, 4.0)
	for gx: int in range(-2, 3):
		for gz: int in range(-1, 2):
			var at: Vector3 = Vector3(float(gx) * 10.5 + rng.randf_range(-1.5, 1.5), 0, float(gz) * 12.0 + rng.randf_range(-1.5, 1.5))
			var yaw: float = PI * 0.5 if (gx + gz) % 2 == 0 else 0.0
			match rng.randi() % 5:
				0: _breakable_wall(at, yaw)
				1: _half_cover(at, yaw)
				2: _barrier_arc(at, yaw)
				_: _low_wall(at, yaw)
	_jump_pad(Vector3(0, 0, -16.5), Vector3(0, 17, 8.0))
	_jump_pad(Vector3(0, 0, 16.5), Vector3(0, 17, -8.0))
	_scatter_cover(_cover_count(2, 4))


func _layout_spires() -> void:
	# five platforms climbing in a circle, each a step higher than the last
	shape = ArenaShape.disc(34.0)
	player_spawn = Vector3(0, 2, 0)
	_claim(Vector3.ZERO, 4.0, 4.0)
	var steps: int = 5
	var turn: float = rng.randf() * TAU
	for i: int in steps:
		var a: float = turn + TAU * float(i) / float(steps)
		var dir: Vector3 = Vector3(cos(a), 0, sin(a))
		var tangent: Vector3 = Vector3(-sin(a), 0, cos(a))
		var height: float = DECK_HEIGHT * (0.6 + 0.3 * float(i))
		# one ramp back toward the lower step, one toward the middle
		_deck(dir * 17.0, Vector3(7.0, height, 7.0), [_side_toward(-tangent), _side_toward(-dir)])
		var b: float = a + PI / float(steps)
		_jump_pad(Vector3(cos(b), 0, sin(b)) * 28.0, Vector3(-cos(b), 0, -sin(b)) * 11.0 + Vector3(0, 20, 0))
	_scatter_cover(_cover_count(3, 6))


func _layout_sanctum() -> void:
	# small, quiet, nothing to hide behind
	shape = ArenaShape.disc(17.0)
	player_spawn = Vector3(0, 2, 9.0)
	focus_point = Vector3(0, 0, -6.0)
	_claim(focus_point, 3.0, 3.0)
	_claim(player_spawn, 3.0, 3.0)
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0 + PI / 6.0
		_tall_pillar(Vector3(cos(a), 0, sin(a)) * 13.0)


func _layout_boss_warden() -> void:
	shape = ArenaShape.disc(32.0)
	player_spawn = Vector3(0, 2, 18.0)
	boss_spawn = Vector3(0, 0.2, -12.0)
	_claim(player_spawn, 4.0, 4.0)
	_claim(boss_spawn, 5.0, 5.0)
	for i: int in 8:
		var a: float = TAU * float(i) / 8.0 + PI / 8.0
		_low_wall(Vector3(cos(a), 0, sin(a)) * 15.0, -a)
	for i: int in 4:
		var a: float = TAU * float(i) / 4.0
		_tall_pillar(Vector3(cos(a), 0, sin(a)) * 23.0)
		var b: float = a + PI * 0.25
		_jump_pad(Vector3(cos(b), 0, sin(b)) * 26.0, Vector3(-cos(b), 0, -sin(b)) * 10.0 + Vector3(0, 18, 0))


func _layout_boss_matriarch() -> void:
	shape = ArenaShape.disc(36.0)
	player_spawn = Vector3(0, 2, 22.0)
	boss_spawn = Vector3(0, 0.2, -14.0)
	_claim(player_spawn, 4.0, 4.0)
	_claim(boss_spawn, 8.0, 8.0)
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0 + PI / 6.0
		_breakable_wall(Vector3(cos(a), 0, sin(a)) * 19.0, -a)
	for i: int in 3:
		var a: float = TAU * float(i) / 3.0 + PI * 0.5
		_deck(Vector3(cos(a), 0, sin(a)) * 28.0, Vector3(7.0, DECK_HEIGHT, 7.0), [0, 1, 2, 3])
		var b: float = a + PI / 3.0
		_jump_pad(Vector3(cos(b), 0, sin(b)) * 29.0, Vector3(-cos(b), 0, -sin(b)) * 11.0 + Vector3(0, 19, 0))


func _layout_boss_stalker() -> void:
	shape = ArenaShape.rect(28.0, 22.0)
	player_spawn = Vector3(0, 2, 14.0)
	boss_spawn = Vector3(0, 0.2, -12.0)
	_claim(player_spawn, 4.0, 4.0)
	_claim(boss_spawn, 4.0, 4.0)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_tall_pillar(Vector3(sx * 13.0, 0, sz * 10.0))
			_jump_pad(Vector3(sx * 23.0, 0, sz * 17.0), Vector3(-sx * 9.0, 18, -sz * 7.0))


func _layout_boss_titan() -> void:
	shape = ArenaShape.disc(36.0)
	player_spawn = Vector3(0, 2, 22.0)
	boss_spawn = Vector3(0, 0.2, -14.0)
	_claim(player_spawn, 4.0, 4.0)
	_claim(boss_spawn, 7.0, 7.0)
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0
		_trunk(Vector3(cos(a), 0, sin(a)) * 24.0, 1.6)
	for i: int in 4:
		var a: float = TAU * float(i) / 4.0 + PI * 0.25
		_jump_pad(Vector3(cos(a), 0, sin(a)) * 30.0, Vector3(-cos(a), 0, -sin(a)) * 12.0 + Vector3(0, 20, 0))


func _layout_boss_core() -> void:
	shape = ArenaShape.disc(34.0)
	player_spawn = Vector3(0, 2, 24.0)
	boss_spawn = Vector3(0, 0.2, 0)
	_claim(player_spawn, 4.0, 4.0)
	_claim(boss_spawn, 6.0, 6.0)
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0 + PI / 6.0
		_barrier_arc(Vector3(cos(a), 0, sin(a)) * 17.0, atan2(-cos(a), -sin(a)))
	for i: int in 4:
		var a: float = TAU * float(i) / 4.0
		_jump_pad(Vector3(cos(a), 0, sin(a)) * 28.0, Vector3(-sin(a), 0, cos(a)) * 12.0 + Vector3(0, 19, 0))


func _layout_boss_harrower() -> void:
	# wide and nearly bare: room to run, and a few trunks to put between you and it
	shape = ArenaShape.disc(38.0)
	player_spawn = Vector3(0, 2, 24.0)
	boss_spawn = Vector3(0, 0.2, -16.0)
	_claim(player_spawn, 4.0, 4.0)
	_claim(boss_spawn, 7.0, 7.0)
	for i: int in 5:
		var a: float = TAU * float(i) / 5.0 + PI * 0.1
		_trunk(Vector3(cos(a), 0, sin(a)) * 19.0, 1.5)
	for i: int in 4:
		var a: float = TAU * float(i) / 4.0 + PI * 0.25
		_jump_pad(Vector3(cos(a), 0, sin(a)) * 31.0, Vector3(-cos(a), 0, -sin(a)) * 13.0 + Vector3(0, 19, 0))


func _layout_boss_choir() -> void:
	# cover in rings: the patterns come from the middle, so what matters is what you can stand behind
	shape = ArenaShape.disc(36.0)
	player_spawn = Vector3(0, 2, 24.0)
	boss_spawn = Vector3(0, 0.2, -8.0)
	_claim(player_spawn, 4.0, 4.0)
	_claim(boss_spawn, 7.0, 7.0)
	for i: int in 5:
		var a: float = TAU * float(i) / 5.0 + PI * 0.3
		_barrier_arc(Vector3(cos(a), 0, sin(a)) * 21.0, atan2(-cos(a), -sin(a)))
	for i: int in 3:
		var a: float = TAU * float(i) / 3.0 + PI * 0.5
		_deck(Vector3(cos(a), 0, sin(a)) * 29.0, Vector3(6.0, DECK_HEIGHT * 0.8, 6.0), [0, 1, 2, 3])
	for i: int in 4:
		var a: float = TAU * float(i) / 4.0 + PI * 0.25
		_jump_pad(Vector3(cos(a), 0, sin(a)) * 13.0, Vector3(cos(a), 0, sin(a)) * 11.0 + Vector3(0, 18, 0))


func _cover_count(lo: int, hi: int) -> int:
	if room.type == RoomDefinitions.RoomType.SWARM:
		return lo - 2
	return clampi(lo + int((room.difficulty - 1.0) * 3.0), lo, hi)


# --- placement bookkeeping -------------------------------------------------------

## reserves a footprint. returns false if it overlaps something already there.
func _claim(centre: Vector3, half_x: float, half_z: float, margin: float = 1.2) -> bool:
	var r: Rect2 = Rect2(centre.x - half_x - margin, centre.z - half_z - margin, (half_x + margin) * 2.0, (half_z + margin) * 2.0)
	for existing: Rect2 in blocked:
		if existing.intersects(r):
			return false
	blocked.append(Rect2(centre.x - half_x, centre.z - half_z, half_x * 2.0, half_z * 2.0))
	return true


func is_blocked(x: float, z: float, margin: float = 0.8) -> bool:
	for r: Rect2 in blocked:
		if r.grow(margin).has_point(Vector2(x, z)):
			return true
	return false


## a random free point inside the arena, away from the walls. INF if none found.
func _free_point(wall_margin: float, clearance: float) -> Vector3:
	for attempt: int in 14:
		var p: Vector3 = shape.random_point(rng, wall_margin)
		if p.distance_to(Vector3(player_spawn.x, 0, player_spawn.z)) < 6.0:
			continue
		if is_blocked(p.x, p.z, clearance):
			continue
		return p
	return Vector3.INF


# --- structure -------------------------------------------------------------------

func _make_materials() -> void:
	if not _wall_shader:
		_wall_shader = Shader.new()
		_wall_shader.code = WALL_SHADER
	_wall_material = ShaderMaterial.new()
	_wall_material.shader = _wall_shader
	_wall_material.set_shader_parameter("base_color", _biome.wall)
	_wall_material.set_shader_parameter("glow_color", _biome.glow)
	_wall_material.set_shader_parameter("wall_height", WALL_HEIGHT)

	_deck_material = StandardMaterial3D.new()
	_deck_material.albedo_color = (_biome.wall as Color).lightened(0.08)
	_deck_material.roughness = 0.7
	_deck_material.metallic = 0.15

	_glow_material = StandardMaterial3D.new()
	_glow_material.albedo_color = _biome.glow
	_glow_material.emission_enabled = true
	_glow_material.emission = _biome.glow
	_glow_material.emission_energy_multiplier = 1.6


func _build_walls() -> void:
	var pts: PackedVector2Array = shape.outline(28)
	var count: int = pts.size()
	for i: int in count:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % count]
		var mid: Vector2 = (a + b) * 0.5
		var along: Vector2 = b - a
		var length: float = along.length()
		if length < 0.1:
			continue
		# push the wall out so its inner face sits on the boundary line
		var outward: Vector2 = Vector2(along.y, -along.x).normalized()
		if outward.dot(mid) < 0.0:
			outward = -outward
		var centre: Vector2 = mid + outward * WALL_THICKNESS * 0.5

		var wall: StaticBody3D = StaticBody3D.new()
		wall.collision_layer = Layers.WORLD
		wall.collision_mask = 0
		wall.position = Vector3(centre.x, 0, centre.y)
		wall.rotation.y = -atan2(along.y, along.x)

		var mesh: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(length + WALL_THICKNESS, WALL_HEIGHT, WALL_THICKNESS)
		mesh.mesh = box
		mesh.position.y = WALL_HEIGHT * 0.5
		mesh.material_override = _wall_material
		wall.add_child(mesh)

		# the collider is far taller than the wall you can see, so a jump pad
		# can never throw anyone out of the room
		var col: CollisionShape3D = CollisionShape3D.new()
		var cshape: BoxShape3D = BoxShape3D.new()
		cshape.size = Vector3(length + WALL_THICKNESS, WALL_COLLISION_HEIGHT, WALL_THICKNESS)
		col.shape = cshape
		col.position.y = WALL_COLLISION_HEIGHT * 0.5
		wall.add_child(col)
		_arena_root.add_child(wall)

		# a bone rib at every other corner breaks up the flat wall
		if i % 2 == 0 or (shape.kind != ArenaShape.Kind.DISC and shape.kind != ArenaShape.Kind.RING):
			var rib: Node3D = _lib.part("obstacles", "bone_spire")
			if rib:
				Skins.apply(rib, _skin)
				rib.scale = Vector3(2.2, WALL_HEIGHT * 1.15 / 4.57, 2.2)
				rib.position = Vector3(a.x, 0, a.y) + Vector3(outward.x, 0, outward.y) * 0.2
				_arena_root.add_child(rib)


func _central_mass(radius: float) -> void:
	_claim(Vector3.ZERO, radius, radius, 0.0)
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape3d: CylinderShape3D = CylinderShape3D.new()
	shape3d.radius = radius
	shape3d.height = WALL_COLLISION_HEIGHT
	col.shape = shape3d
	col.position.y = WALL_COLLISION_HEIGHT * 0.5
	body.add_child(col)

	var mesh: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = radius * 0.82
	cyl.bottom_radius = radius
	cyl.height = WALL_HEIGHT * 1.3
	cyl.radial_segments = 20
	mesh.mesh = cyl
	mesh.position.y = WALL_HEIGHT * 0.65
	mesh.material_override = _wall_material
	body.add_child(mesh)
	_arena_root.add_child(body)

	for i: int in 7:
		var a: float = TAU * float(i) / 7.0
		var trunk: Node3D = _lib.part("obstacles", "swollen_trunk")
		if trunk:
			Skins.apply(trunk, _skin)
			var s: float = rng.randf_range(1.5, 2.3)
			trunk.scale = Vector3(s, s * rng.randf_range(1.4, 2.0), s)
			trunk.position = Vector3(cos(a), 0, sin(a)) * (radius - 0.3)
			trunk.rotation.y = rng.randf() * TAU
			_arena_root.add_child(trunk)
	_lamp_light(Vector3(0, WALL_HEIGHT * 1.4, 0), 26.0, 3.0)


## a raised platform. `ramp_sides` lists which sides get a ramp:
## 0 = +x, 1 = -x, 2 = +z, 3 = -z.
func _deck(centre: Vector3, size: Vector3, ramp_sides: Array) -> void:
	if not _claim(centre, size.x * 0.5, size.z * 0.5, 0.5):
		return
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.position = Vector3(centre.x, 0, centre.z)

	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position.y = size.y * 0.5
	mesh.material_override = _deck_material
	body.add_child(mesh)
	var col: CollisionShape3D = CollisionShape3D.new()
	var cshape: BoxShape3D = BoxShape3D.new()
	cshape.size = size
	col.shape = cshape
	col.position.y = size.y * 0.5
	body.add_child(col)

	# glowing lip around the top edge
	for edge: Array in [
		[Vector3(size.x + 0.1, 0.08, 0.1), Vector3(0, size.y, size.z * 0.5)],
		[Vector3(size.x + 0.1, 0.08, 0.1), Vector3(0, size.y, -size.z * 0.5)],
		[Vector3(0.1, 0.08, size.z + 0.1), Vector3(size.x * 0.5, size.y, 0)],
		[Vector3(0.1, 0.08, size.z + 0.1), Vector3(-size.x * 0.5, size.y, 0)],
	]:
		var trim: MeshInstance3D = MeshInstance3D.new()
		var tbox: BoxMesh = BoxMesh.new()
		tbox.size = edge[0]
		trim.mesh = tbox
		trim.position = edge[1]
		trim.material_override = _glow_material
		trim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(trim)
	_arena_root.add_child(body)

	var dirs: Array[Vector3] = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	for side: Variant in ramp_sides:
		var dir: Vector3 = dirs[int(side)]
		var half_extent: float = size.x * 0.5 if int(side) < 2 else size.z * 0.5
		var span: float = size.z if int(side) < 2 else size.x
		_ramp(Vector3(centre.x, 0, centre.z) + dir * half_extent, dir, minf(span * 0.6, 4.5), size.y)


## a ramp from the floor up to `height`, rising toward `edge` from `dir_out`.
func _ramp(edge: Vector3, dir_out: Vector3, width: float, height: float) -> void:
	var run: float = height / tan(RAMP_ANGLE)
	var slope: float = sqrt(run * run + height * height)
	var centre: Vector3 = edge + dir_out * run * 0.5
	_claim(centre, (run * 0.5 if absf(dir_out.x) > 0.5 else width * 0.5), (run * 0.5 if absf(dir_out.z) > 0.5 else width * 0.5), 0.0)

	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.position = Vector3(centre.x, height * 0.5 - 0.14, centre.z)
	# local +z runs down the slope, away from the deck
	body.rotation = Vector3(RAMP_ANGLE, atan2(dir_out.x, dir_out.z), 0)

	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(width, 0.28, slope)
	mesh.mesh = box
	mesh.material_override = _deck_material
	body.add_child(mesh)
	var col: CollisionShape3D = CollisionShape3D.new()
	var cshape: BoxShape3D = BoxShape3D.new()
	cshape.size = Vector3(width, 0.28, slope)
	col.shape = cshape
	body.add_child(col)
	for s: float in [-1.0, 1.0]:
		var rail: MeshInstance3D = MeshInstance3D.new()
		var rbox: BoxMesh = BoxMesh.new()
		rbox.size = Vector3(0.08, 0.06, slope)
		rail.mesh = rbox
		rail.position = Vector3(s * width * 0.5, 0.16, 0)
		rail.material_override = _glow_material
		rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(rail)
	_arena_root.add_child(body)
	_ramp_fill(edge, dir_out, width, height, run)


## closes the space under a ramp. the slope itself is a thin slab; left open,
## the wedge of air beneath it is a pocket that enemies walk into and cannot
## leave, and that a sliding player fits under but cannot stand up in.
func _ramp_fill(edge: Vector3, dir_out: Vector3, width: float, height: float, run: float) -> void:
	var half: float = width * 0.5
	var fill: StaticBody3D = StaticBody3D.new()
	fill.collision_layer = Layers.WORLD
	fill.collision_mask = 0
	fill.position = edge
	# local +z points away from the deck, like the slab above it
	fill.rotation.y = atan2(dir_out.x, dir_out.z)

	# a hair below the slab, so feet still land on the slab's surface
	var top: float = height - 0.06
	var col: CollisionShape3D = CollisionShape3D.new()
	var wedge: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	wedge.points = PackedVector3Array([
		Vector3(-half, 0, 0), Vector3(half, 0, 0), Vector3(-half, top, 0), Vector3(half, top, 0),
		Vector3(-half, 0, run), Vector3(half, 0, run),
	])
	col.shape = wedge
	fill.add_child(col)

	# the two triangular sides are the only faces anyone can see
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s: float in [-1.0, 1.0]:
		var a: Vector3 = Vector3(s * half, 0, 0)
		var b: Vector3 = Vector3(s * half, top, 0)
		var c: Vector3 = Vector3(s * half, 0, run)
		st.set_normal(Vector3(s, 0, 0))
		for v: Vector3 in ([a, b, c] if s > 0.0 else [a, c, b]):
			st.add_vertex(v)
	var side: MeshInstance3D = MeshInstance3D.new()
	side.mesh = st.commit()
	var mat: StandardMaterial3D = (_deck_material as StandardMaterial3D).duplicate() as StandardMaterial3D if _deck_material is StandardMaterial3D else null
	if mat:
		# seen from either side whichever way the triangle winds
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		side.material_override = mat
	else:
		side.material_override = _deck_material
	fill.add_child(side)
	_arena_root.add_child(fill)


func _jump_pad(at: Vector3, launch: Vector3) -> void:
	var p: Vector3 = shape.clamp_point(Vector3(at.x, 0, at.z), 2.5)
	if not _claim(p, 1.3, 1.3, 0.3):
		return
	var pad: JumpPad = JumpPad.new()
	pad.launch_velocity = launch
	pad.color = _biome.glow
	pad.position = Vector3(p.x, 0.1, p.z)
	var model: Node3D = _lib.part("props", "jump_pad")
	if model:
		Skins.apply(model, _skin)
		pad.add_child(model)
	_arena_root.add_child(pad)


# --- cover -----------------------------------------------------------------------

func _scatter_cover(count: int) -> void:
	for i: int in maxi(0, count):
		var p: Vector3 = _free_point(5.0, 2.5)
		if p == Vector3.INF:
			continue
		var facing: float = atan2(p.x, p.z) + rng.randf_range(-0.6, 0.6)
		match rng.randi() % 10:
			0: _pillar(p)
			1: _low_wall(p, facing)
			2: _egg_crates(p)
			3: _ramp_prop(p, facing)
			4: _tall_pillar(p)
			5: _trunk(p)
			6: _half_cover(p, facing)
			7: _barrier_arc(p, facing)
			_: _breakable_wall(p, facing)


func _static_body(at: Vector3, yaw: float = 0.0) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.position = Vector3(at.x, 0.1, at.z)
	body.rotation.y = yaw
	return body


func _add_box(body: StaticBody3D, size: Vector3, offset: Vector3, yaw: float = 0.0) -> void:
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape3d: BoxShape3D = BoxShape3D.new()
	shape3d.size = size
	col.shape = shape3d
	col.position = offset
	col.rotation.y = yaw
	body.add_child(col)


func _add_model(body: Node3D, part_name: String, model_scale: Vector3, offset: Vector3 = Vector3.ZERO, yaw: float = 0.0) -> Node3D:
	var model: Node3D = _lib.part("obstacles", part_name)
	if not model:
		return null
	Skins.apply(model, _skin)
	model.scale = model_scale
	model.position = offset
	model.rotation.y = yaw
	body.add_child(model)
	return model


func _pillar(at: Vector3) -> void:
	var w: float = rng.randf_range(1.0, 1.6)
	var h: float = rng.randf_range(2.2, 3.8)
	if not _claim(at, w * 0.5, w * 0.5):
		return
	var body: StaticBody3D = _static_body(at)
	_add_box(body, Vector3(w, h, w), Vector3(0, h * 0.5, 0))
	_add_model(body, "pillar_rib_arch", Vector3(w / 1.1, h / 3.44, w / 1.1))
	_arena_root.add_child(body)


func _tall_pillar(at: Vector3) -> void:
	var w: float = rng.randf_range(0.8, 1.2)
	var h: float = rng.randf_range(4.5, 6.5)
	if not _claim(at, w * 0.5, w * 0.5):
		return
	var body: StaticBody3D = _static_body(at)
	_add_box(body, Vector3(w, h, w), Vector3(0, h * 0.5, 0))
	_add_model(body, "bone_spire", Vector3(w / 0.78, h / 4.57, w / 0.78))
	_arena_root.add_child(body)


func _trunk(at: Vector3, size_mult: float = 1.0) -> void:
	var r: float = rng.randf_range(0.8, 1.3) * size_mult
	var h: float = rng.randf_range(2.8, 4.6) * size_mult
	if not _claim(at, r, r):
		return
	var body: StaticBody3D = _static_body(at)
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape3d: CylinderShape3D = CylinderShape3D.new()
	shape3d.radius = r
	shape3d.height = h
	col.shape = shape3d
	col.position.y = h * 0.5
	body.add_child(col)
	_add_model(body, "swollen_trunk", Vector3(r / 0.95, h / 3.25, r / 0.95))
	_arena_root.add_child(body)


func _low_wall(at: Vector3, yaw: float) -> void:
	var length: float = rng.randf_range(3.0, 5.5)
	var h: float = rng.randf_range(1.0, 1.4)
	if not _claim(at, length * 0.5, length * 0.5, 0.4):
		return
	var body: StaticBody3D = _static_body(at, yaw)
	_add_box(body, Vector3(length, h, 0.5), Vector3(0, h * 0.5, 0))
	_add_model(body, "rib_fence", Vector3(length / 3.46, h / 1.15, 1.0))
	_arena_root.add_child(body)


func _half_cover(at: Vector3, yaw: float) -> void:
	# a screen with a gap in the middle to shoot through
	var length: float = rng.randf_range(4.5, 6.5)
	var h: float = rng.randf_range(1.5, 1.9)
	var gap: float = length * 0.24
	if not _claim(at, length * 0.5, length * 0.5, 0.4):
		return
	var body: StaticBody3D = _static_body(at, yaw)
	var half_len: float = (length - gap) * 0.5
	for s: float in [-1.0, 1.0]:
		_add_box(body, Vector3(half_len, h, 0.4), Vector3(s * (half_len + gap) * 0.5, h * 0.5, 0))
	_add_model(body, "split_carapace_screen", Vector3(length / 5.06, h / 1.713, 1.0))
	_arena_root.add_child(body)


func _barrier_arc(at: Vector3, yaw: float) -> void:
	var arc_radius: float = rng.randf_range(2.6, 3.8)
	var h: float = rng.randf_range(1.1, 1.6)
	if not _claim(at, arc_radius, arc_radius, 0.4):
		return
	var body: StaticBody3D = _static_body(at, yaw)
	var segments: int = 3
	for i: int in segments:
		var a: float = (float(i) / float(segments - 1) - 0.5) * PI * 0.6
		var seg_pos: Vector3 = Vector3(sin(a) * arc_radius, 0, cos(a) * arc_radius - arc_radius)
		var seg_len: float = 2.0 * arc_radius * sin(PI * 0.6 / float(2 * segments)) + 0.5
		_add_box(body, Vector3(seg_len, h, 0.35), seg_pos + Vector3(0, h * 0.5, 0), a)
		_add_model(body, "corral_segment", Vector3(seg_len / 1.76, h / 1.1, 1.0), seg_pos, a)
	_arena_root.add_child(body)


func _egg_crates(at: Vector3) -> void:
	if not _claim(at, 1.6, 1.6):
		return
	var sizes: Array[float] = [0.84, 0.68, 0.6, 0.6]
	for i: int in 2 + rng.randi() % 3:
		var s: float = rng.randf_range(0.8, 1.3)
		var h: float = rng.randf_range(0.8, 1.5)
		var offset: Vector3 = Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-1.0, 1.0))
		var body: StaticBody3D = _static_body(at + offset)
		_add_box(body, Vector3(s, h, s), Vector3(0, h * 0.5, 0))
		var variant: int = i % 4
		var egg: Node3D = _lib.group("obstacles", ["eggsac_%d" % (variant + 1), "eggsac_core_%d" % (variant + 1)])
		Skins.apply(egg, _skin)
		var natural: float = sizes[variant]
		egg.scale = Vector3(s / natural, h / (natural * 1.25), s / natural)
		egg.position.y = h * 0.5
		body.add_child(egg)
		_arena_root.add_child(body)


func _ramp_prop(at: Vector3, yaw: float) -> void:
	# a small kicker ramp: run up it for a free jump
	var length: float = rng.randf_range(3.0, 4.4)
	var width: float = rng.randf_range(1.8, 2.6)
	var tilt: float = 0.42
	var h: float = length * tan(tilt)
	if not _claim(at, length * 0.5, length * 0.5, 0.4):
		return
	var body: StaticBody3D = _static_body(at, yaw)
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape3d: BoxShape3D = BoxShape3D.new()
	shape3d.size = Vector3(width, 0.2, length / cos(tilt))
	col.shape = shape3d
	col.position = Vector3(0, h * 0.5, 0)
	col.rotation.x = -tilt
	body.add_child(col)
	var slope: float = length / 2.6
	_add_model(body, "carapace_ramp", Vector3(width / 1.5, slope, slope))
	_arena_root.add_child(body)


func _breakable_wall(at: Vector3, yaw: float) -> void:
	var length: float = rng.randf_range(3.2, 5.0)
	var h: float = rng.randf_range(1.8, 2.3)
	if not _claim(at, length * 0.5, length * 0.5, 0.4):
		return
	var body: StaticBody3D = _static_body(at, yaw)
	body.set_meta("breakable", true)
	body.set_meta("hit_points", 6)
	body.set_meta("max_hit_points", 6)
	body.add_to_group("breakables")
	_add_box(body, Vector3(length, h, 0.45), Vector3(0, h * 0.5, 0))
	var model: Node3D = _add_model(body, "breakable_membrane_wall", Vector3(length / 2.23, h / 2.02, 1.0))
	if model:
		model.name = "WallModel"
	_arena_root.add_child(body)


# --- set dressing ----------------------------------------------------------------

func _decorate() -> void:
	var props: Array = _biome.props
	var ring_r: float = shape.bounding_radius()
	var count: int = 10 if shape.kind == ArenaShape.Kind.DISC or shape.kind == ArenaShape.Kind.RING else 8
	if template == &"sanctum":
		count = 5
	for i: int in count:
		# hug the walls: walk inward from outside until inside the shape
		var a: float = TAU * float(i) / float(count) + rng.randf() * 0.3
		var dir: Vector3 = Vector3(cos(a), 0, sin(a))
		var p: Vector3 = shape.clamp_point(dir * (ring_r + 5.0), 2.2)
		if is_blocked(p.x, p.z, 1.5):
			continue
		var prop_name: String = props[rng.randi() % props.size()]
		var prop: Node3D = _lib.part("props", prop_name)
		if not prop:
			continue
		Skins.apply(prop, _skin)
		var s: float = rng.randf_range(0.9, 1.5)
		prop.scale = Vector3.ONE * s
		prop.position = Vector3(p.x, 0.1, p.z)
		prop.rotation.y = atan2(-dir.x, -dir.z) + rng.randf_range(-0.4, 0.4)
		_arena_root.add_child(prop)
		_claim(p, 1.0, 1.0, 0.0)
		if prop_name == "lamp_stalk":
			_lamp_light(prop.position + Vector3(0, 2.7 * s, 0), 15.0, 2.4)

	# every room gets a few lights even if no lamps were rolled
	var guard: int = 0
	while _lamps < 3 and guard < 8:
		guard += 1
		var a: float = rng.randf() * TAU
		var p: Vector3 = shape.clamp_point(Vector3(cos(a), 0, sin(a)) * ring_r * 0.75, 3.0)
		_lamp_light(p + Vector3(0, 5.5, 0), 20.0, 2.0)


func _lamp_light(at: Vector3, light_range: float, energy: float) -> void:
	if _lamps >= MAX_LAMPS:
		return
	_lamps += 1
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = _biome.glow
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	l.position = at
	_arena_root.add_child(l)


# --- hazards ---------------------------------------------------------------------

func _place_hazards() -> void:
	if room.is_peaceful() or room.is_boss():
		return
	var count: int = 0
	if room.type == RoomDefinitions.RoomType.HAZARD:
		count = clampi(5 + int(room.difficulty * 1.5), 6, 11)
	elif room.difficulty >= 1.6:
		count = clampi(int((room.difficulty - 1.3) * 2.0), 1, 4)
	var color: Color = _biome.hazard
	var tick_damage: int = maxi(4, int(5.0 + room.difficulty * 1.5))
	for i: int in count:
		var p: Vector3 = _free_point(4.0, 2.0)
		if p == Vector3.INF:
			continue
		var zone: HazardZone = HazardZone.create(rng.randf_range(2.0, 3.4), tick_damage, color)
		match rng.randi() % 3:
			1:
				# a vent: off, then a warning flicker, then on
				zone.pulse_on = 1.4
				zone.pulse_off = 2.2
				zone.damage = int(tick_damage * 1.5)
			2:
				zone.slows = true
				zone.radius *= 1.2
				zone.damage = maxi(2, tick_damage / 2)
		zone.position = Vector3(p.x, 0.1, p.z)
		_hazard_root.add_child(zone)


## zero to two fields: marked ground that changes whoever stands on it, the
## brood as much as the player. never on the opening floor, never with a boss.
func _place_fields() -> void:
	if room.is_peaceful() or room.is_boss() or room.floor_index <= 0:
		return
	var roll: float = rng.randf()
	var count: int = 0 if roll < 0.3 else (1 if roll < 0.75 else 2)
	if room.type == RoomDefinitions.RoomType.GAUNTLET:
		count = maxi(count, 1)
	if room.metadata.get("dense_fields", false):
		count = 3
	var kinds: Array = FieldZone.KINDS.keys()
	var placed: Array[Vector3] = []
	var used: Array = []
	for i: int in count:
		var kind: StringName = kinds[rng.randi() % kinds.size()]
		var radius: float = rng.randf_range(3.2, 4.4)
		var p: Vector3 = _free_point(6.0, 3.0)
		if p == Vector3.INF or used.has(kind):
			continue
		var crowded: bool = false
		for other: Vector3 in placed:
			if other.distance_to(p) < 11.0:
				crowded = true
		if crowded:
			continue
		used.append(kind)
		placed.append(p)
		var zone: FieldZone = FieldZone.create(kind, radius)
		zone.position = Vector3(p.x, 0.1, p.z)
		_hazard_root.add_child(zone)
