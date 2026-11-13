class_name Vfx
extends Node3D

# pooled transient world effects: rings, blasts, sparks, tracers, lights,
# floating numbers and ground telegraphs.
#
# one instance lives inside the run scene (registered as Game.fx_root), so
# everything it spawns is freed with the scene. call sites use the static
# helpers, which quietly do nothing when no instance exists (menus, tests).

const GROUND_Y: float = 0.13

const FLAT_SHADER_CODE: String = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float inner = 0.85;
instance uniform float fill = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float edge = smoothstep(1.0, 0.965, d);
	float ring = edge * smoothstep(inner - 0.03, inner + 0.01, d);
	float filled = edge * smoothstep(fill, fill - 0.06, d) * 0.4 * step(0.001, fill);
	ALBEDO = tint.rgb;
	ALPHA = clamp(ring + filled, 0.0, 1.0) * tint.a;
}
"""

const LINE_SHADER_CODE: String = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float fill = 0.0;
void fragment() {
	vec2 p = UV;
	float border = max(step(p.x, 0.04), step(0.96, p.x));
	border = max(border, max(step(p.y, 0.012), step(0.988, p.y)));
	float filled = step(p.y, fill) * 0.4;
	ALBEDO = tint.rgb;
	ALPHA = clamp(border + filled, 0.0, 1.0) * tint.a;
}
"""

const RING_POOL: int = 28
const BLAST_POOL: int = 12
const SPARK_POOL: int = 16
const CHUNK_POOL: int = 10
const LIGHT_POOL: int = 8
const NUMBER_POOL: int = 36
const TRACER_POOL: int = 48

static var _flat_shader: Shader
static var _line_shader: Shader

var _rings: Array[MeshInstance3D] = []
var _ring_tweens: Array[Tween] = []
var _ring_next: int = 0

var _blasts: Array[MeshInstance3D] = []
var _blast_mats: Array[StandardMaterial3D] = []
var _blast_tweens: Array[Tween] = []
var _blast_next: int = 0

var _sparks: Array[GPUParticles3D] = []
var _spark_next: int = 0
var _chunks: Array[GPUParticles3D] = []
var _chunk_next: int = 0

var _lights: Array[OmniLight3D] = []
var _light_tweens: Array[Tween] = []
var _light_next: int = 0

var _numbers: Array[Label3D] = []
var _number_tweens: Array[Tween] = []
var _number_next: int = 0

var _tracers: Array[MeshInstance3D] = []
var _tracer_mats: Array[StandardMaterial3D] = []
var _tracer_cyls: Array[CylinderMesh] = []
var _tracer_tweens: Array[Tween] = []
var _tracer_next: int = 0

var _flat_material: ShaderMaterial
var _line_material: ShaderMaterial
var _plane: PlaneMesh
var numbers_enabled: bool = true


func _ready() -> void:
	if not _flat_shader:
		_flat_shader = Shader.new()
		_flat_shader.code = FLAT_SHADER_CODE
		_line_shader = Shader.new()
		_line_shader.code = LINE_SHADER_CODE
	_flat_material = ShaderMaterial.new()
	_flat_material.shader = _flat_shader
	_line_material = ShaderMaterial.new()
	_line_material.shader = _line_shader
	_plane = PlaneMesh.new()
	_plane.size = Vector2(2, 2)
	_build_pools()


# --- static entry points -------------------------------------------------

static func inst() -> Vfx:
	return Game.fx_root() as Vfx


static func ring(pos: Vector3, radius: float, color: Color, duration: float = 0.4,
		start_radius: float = 0.3, thickness: float = 0.15) -> void:
	var v: Vfx = inst()
	if v:
		v._ring(pos, radius, color, duration, start_radius, thickness)


static func disc(pos: Vector3, radius: float, color: Color, duration: float = 0.4) -> void:
	var v: Vfx = inst()
	if v:
		v._ring(pos, radius, color, duration, radius, 1.0)


static func blast(pos: Vector3, radius: float, color: Color, with_light: bool = true) -> void:
	var v: Vfx = inst()
	if v:
		v._blast(pos, radius, color, with_light)


static func sparks(pos: Vector3, dir: Vector3, color: Color, speed: float = 7.0, spread: float = 35.0) -> void:
	var v: Vfx = inst()
	if v:
		v._emit_sparks(pos, dir, color, speed, spread)


static func chunks(pos: Vector3, color: Color, speed: float = 6.0) -> void:
	var v: Vfx = inst()
	if v:
		v._emit_chunks(pos, color, speed)


static func light(pos: Vector3, color: Color, energy: float = 3.0, duration: float = 0.2, light_range: float = 8.0) -> void:
	var v: Vfx = inst()
	if v:
		v._flash_light(pos, color, energy, duration, light_range)


static func number(pos: Vector3, amount: int, color: Color = Color.WHITE, big: bool = false) -> void:
	var v: Vfx = inst()
	if v and v.numbers_enabled:
		v._number(pos, str(amount), color, big)


static func text(pos: Vector3, message: String, color: Color = Color.WHITE, big: bool = false) -> void:
	var v: Vfx = inst()
	if v:
		v._number(pos, message, color, big)


static func tracer(from_pos: Vector3, to_pos: Vector3, color: Color = Color(1.0, 0.7, 0.2),
		duration: float = 0.1, width: float = 0.012, width_end: float = -1.0) -> void:
	var v: Vfx = inst()
	if v:
		v._tracer(from_pos, to_pos, color, duration, width, width_end)


## jagged bolt between two points, drawn as a few tracer segments.
static func lightning(from_pos: Vector3, to_pos: Vector3, color: Color, duration: float = 0.12,
		jitter: float = 0.35, width: float = 0.02) -> void:
	var v: Vfx = inst()
	if not v:
		return
	var segments: int = clampi(int(from_pos.distance_to(to_pos) / 1.6), 2, 6)
	var prev: Vector3 = from_pos
	for i: int in range(1, segments + 1):
		var t: float = float(i) / float(segments)
		var p: Vector3 = from_pos.lerp(to_pos, t)
		if i < segments:
			p += Vector3(randf_range(-jitter, jitter), randf_range(-jitter, jitter), randf_range(-jitter, jitter))
		v._tracer(prev, p, color, duration, width, width)
		prev = p


## ground warning for an area attack: an outline that fills over `duration`.
## returns the node so the caller can free it early if the attack is cancelled.
static func telegraph_circle(pos: Vector3, radius: float, duration: float, color: Color = Color(1.0, 0.25, 0.1)) -> Node3D:
	var v: Vfx = inst()
	if not v:
		return null
	return v._telegraph_circle(pos, radius, duration, color)


## ground warning for a line attack (charges, beams).
static func telegraph_line(from_pos: Vector3, to_pos: Vector3, width: float, duration: float,
		color: Color = Color(1.0, 0.25, 0.1)) -> Node3D:
	var v: Vfx = inst()
	if not v:
		return null
	return v._telegraph_line(from_pos, to_pos, width, duration, color)


# --- pools ---------------------------------------------------------------

func _build_pools() -> void:
	for i: int in RING_POOL:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = _plane
		mi.material_override = _flat_material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_rings.append(mi)
		_ring_tweens.append(null)

	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	for i: int in BLAST_POOL:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = sphere
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_blasts.append(mi)
		_blast_mats.append(mat)
		_blast_tweens.append(null)

	for i: int in SPARK_POOL:
		_sparks.append(_make_emitter(14, 0.35, false))
	for i: int in CHUNK_POOL:
		_chunks.append(_make_emitter(12, 0.7, true))

	for i: int in LIGHT_POOL:
		var l: OmniLight3D = OmniLight3D.new()
		l.light_energy = 0.0
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		_lights.append(l)
		_light_tweens.append(null)

	for i: int in NUMBER_POOL:
		var label: Label3D = Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = true
		label.pixel_size = 0.0011
		label.font_size = 40
		label.outline_size = 10
		label.outline_modulate = Color(0, 0, 0, 0.85)
		label.render_priority = 5
		label.visible = false
		add_child(label)
		_numbers.append(label)
		_number_tweens.append(null)

	for i: int in TRACER_POOL:
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.radial_segments = 4
		cyl.rings = 0
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		var t: MeshInstance3D = MeshInstance3D.new()
		t.mesh = cyl
		t.material_override = mat
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t.visible = false
		add_child(t)
		_tracers.append(t)
		_tracer_mats.append(mat)
		_tracer_cyls.append(cyl)
		_tracer_tweens.append(null)


func _make_emitter(amount: int, lifetime: float, chunky: bool) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0 if chunky else 35.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0, -16.0 if chunky else -6.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	pm.damping_min = 0.5
	pm.damping_max = 1.5
	if chunky:
		pm.angular_velocity_min = -360.0
		pm.angular_velocity_max = 360.0
	p.process_material = pm

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	if chunky:
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.11, 0.11, 0.11)
		box.material = mat
		p.draw_pass_1 = box
	else:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(0.07, 0.07)
		quad.material = mat
		p.draw_pass_1 = quad
	add_child(p)
	return p


# --- implementations ------------------------------------------------------

func _ring(pos: Vector3, radius: float, color: Color, duration: float, start_radius: float, thickness: float) -> void:
	var idx: int = _ring_next
	_ring_next = (_ring_next + 1) % RING_POOL
	var mi: MeshInstance3D = _rings[idx]
	if _ring_tweens[idx] and _ring_tweens[idx].is_valid():
		_ring_tweens[idx].kill()
	mi.position = Vector3(pos.x, maxf(pos.y, GROUND_Y), pos.z)
	mi.rotation = Vector3.ZERO
	mi.scale = Vector3(start_radius, 1.0, start_radius)
	mi.set_instance_shader_parameter("inner", clampf(1.0 - thickness, 0.0, 0.98))
	mi.set_instance_shader_parameter("fill", 0.0)
	mi.set_instance_shader_parameter("tint", color)
	mi.visible = true

	var tw: Tween = create_tween().set_parallel(true)
	_ring_tweens[idx] = tw
	tw.tween_property(mi, "scale", Vector3(radius, 1.0, radius), duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(func(a: float) -> void:
		mi.set_instance_shader_parameter("tint", Color(color.r, color.g, color.b, color.a * a)),
		1.0, 0.0, duration).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void: mi.visible = false)


func _blast(pos: Vector3, radius: float, color: Color, with_light: bool) -> void:
	var idx: int = _blast_next
	_blast_next = (_blast_next + 1) % BLAST_POOL
	var mi: MeshInstance3D = _blasts[idx]
	var mat: StandardMaterial3D = _blast_mats[idx]
	if _blast_tweens[idx] and _blast_tweens[idx].is_valid():
		_blast_tweens[idx].kill()
	mi.position = pos
	mi.scale = Vector3.ONE * radius * 0.25
	mat.albedo_color = Color(color.r, color.g, color.b, 0.85)
	mi.visible = true

	var tw: Tween = create_tween().set_parallel(true)
	_blast_tweens[idx] = tw
	tw.tween_property(mi, "scale", Vector3.ONE * radius, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void: mi.visible = false)

	_ring(Vector3(pos.x, GROUND_Y, pos.z), radius * 1.25, color, 0.35, radius * 0.3, 0.2)
	_emit_sparks(pos, Vector3.UP, color, 9.0, 180.0)
	if with_light:
		_flash_light(pos, color, 4.0 + radius * 0.6, 0.25, radius * 3.0)


func _emit_sparks(pos: Vector3, dir: Vector3, color: Color, speed: float, spread: float) -> void:
	var p: GPUParticles3D = _sparks[_spark_next]
	_spark_next = (_spark_next + 1) % SPARK_POOL
	var pm: ParticleProcessMaterial = p.process_material as ParticleProcessMaterial
	pm.direction = dir.normalized() if dir.length() > 0.01 else Vector3.UP
	pm.spread = spread
	pm.initial_velocity_min = speed * 0.4
	pm.initial_velocity_max = speed
	pm.color = color
	p.position = pos
	p.restart()
	p.emitting = true


func _emit_chunks(pos: Vector3, color: Color, speed: float) -> void:
	var p: GPUParticles3D = _chunks[_chunk_next]
	_chunk_next = (_chunk_next + 1) % CHUNK_POOL
	var pm: ParticleProcessMaterial = p.process_material as ParticleProcessMaterial
	pm.initial_velocity_min = speed * 0.4
	pm.initial_velocity_max = speed
	pm.color = color
	p.position = pos
	p.restart()
	p.emitting = true


func _flash_light(pos: Vector3, color: Color, energy: float, duration: float, light_range: float) -> void:
	var idx: int = _light_next
	_light_next = (_light_next + 1) % LIGHT_POOL
	var l: OmniLight3D = _lights[idx]
	if _light_tweens[idx] and _light_tweens[idx].is_valid():
		_light_tweens[idx].kill()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.visible = true
	var tw: Tween = create_tween()
	_light_tweens[idx] = tw
	tw.tween_property(l, "light_energy", 0.0, duration)
	tw.tween_callback(func() -> void: l.visible = false)


func _number(pos: Vector3, message: String, color: Color, big: bool) -> void:
	var idx: int = _number_next
	_number_next = (_number_next + 1) % NUMBER_POOL
	var label: Label3D = _numbers[idx]
	if _number_tweens[idx] and _number_tweens[idx].is_valid():
		_number_tweens[idx].kill()
	label.text = message
	label.modulate = color
	label.font_size = 64 if big else 40
	label.position = pos + Vector3(randf_range(-0.25, 0.25), randf_range(0.0, 0.2), randf_range(-0.25, 0.25))
	label.visible = true

	var rise: float = 1.4 if big else 0.9
	var tw: Tween = create_tween().set_parallel(true)
	_number_tweens[idx] = tw
	tw.tween_property(label, "position:y", label.position.y + rise, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(label, "modulate:a", 0.0, 0.25).set_delay(0.35)
	tw.chain().tween_callback(func() -> void: label.visible = false)


func _tracer(from_pos: Vector3, to_pos: Vector3, color: Color, duration: float, width: float, width_end: float) -> void:
	var dist: float = from_pos.distance_to(to_pos)
	if dist < 0.1:
		return
	var idx: int = _tracer_next
	_tracer_next = (_tracer_next + 1) % TRACER_POOL
	var t: MeshInstance3D = _tracers[idx]
	var mat: StandardMaterial3D = _tracer_mats[idx]
	var cyl: CylinderMesh = _tracer_cyls[idx]
	if _tracer_tweens[idx] and _tracer_tweens[idx].is_valid():
		_tracer_tweens[idx].kill()

	cyl.top_radius = width
	cyl.bottom_radius = width_end if width_end >= 0.0 else width
	cyl.height = dist
	mat.albedo_color = Color(color.r, color.g, color.b, 0.9)

	var dir: Vector3 = (to_pos - from_pos) / dist
	# a cylinder's long axis is +Y: build a basis whose Y points along the shot
	var up: Vector3 = Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	var x_axis: Vector3 = up.cross(dir).normalized()
	var z_axis: Vector3 = x_axis.cross(dir).normalized()
	t.global_transform = Transform3D(Basis(x_axis, dir, z_axis), (from_pos + to_pos) * 0.5)
	t.visible = true

	var tw: Tween = create_tween()
	_tracer_tweens[idx] = tw
	tw.tween_property(mat, "albedo_color:a", 0.0, duration)
	tw.tween_callback(func() -> void: t.visible = false)


func _telegraph_circle(pos: Vector3, radius: float, duration: float, color: Color) -> Node3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _plane
	mi.material_override = _flat_material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position = Vector3(pos.x, maxf(pos.y, GROUND_Y) + 0.01, pos.z)
	mi.scale = Vector3(radius, 1.0, radius)
	mi.set_instance_shader_parameter("inner", 0.94)
	mi.set_instance_shader_parameter("tint", Color(color.r, color.g, color.b, 0.9))
	mi.set_instance_shader_parameter("fill", 0.001)
	var tw: Tween = mi.create_tween()
	tw.tween_method(func(f: float) -> void: mi.set_instance_shader_parameter("fill", f), 0.001, 1.0, duration)
	tw.tween_callback(mi.queue_free)
	return mi


func _telegraph_line(from_pos: Vector3, to_pos: Vector3, width: float, duration: float, color: Color) -> Node3D:
	var flat_from: Vector3 = Vector3(from_pos.x, 0, from_pos.z)
	var flat_to: Vector3 = Vector3(to_pos.x, 0, to_pos.z)
	var length: float = flat_from.distance_to(flat_to)
	if length < 0.1:
		return null
	var mi: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(width, length)
	mi.mesh = plane
	mi.material_override = _line_material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var mid: Vector3 = (flat_from + flat_to) * 0.5
	mi.position = Vector3(mid.x, GROUND_Y + 0.01, mid.z)
	# PlaneMesh UV.y runs along local +Z; aim +Z from the attacker to the far
	# end so the fill sweeps outward along the attack
	var dir: Vector3 = (flat_to - flat_from) / length
	mi.rotation.y = atan2(dir.x, dir.z)
	mi.set_instance_shader_parameter("tint", Color(color.r, color.g, color.b, 0.85))
	mi.set_instance_shader_parameter("fill", 0.0)
	var tw: Tween = mi.create_tween()
	tw.tween_method(func(f: float) -> void: mi.set_instance_shader_parameter("fill", f), 0.0, 1.0, duration)
	tw.tween_callback(mi.queue_free)
	return mi


## a standalone flat ring/disc mesh using the shared ground shader, for effects
## that need to drive their own size every frame (shockwaves, auras). the
## caller owns the returned node. `inner` is the hole size as a fraction (0 = disc).
static func make_flat(inner: float, color: Color) -> MeshInstance3D:
	if not _flat_shader:
		_flat_shader = Shader.new()
		_flat_shader.code = FLAT_SHADER_CODE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _flat_shader
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(2, 2)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("inner", clampf(inner, 0.0, 0.98))
	mi.set_instance_shader_parameter("fill", 0.0)
	mi.set_instance_shader_parameter("tint", color)
	return mi
