class_name TracerPool
extends RefCounted

# pooled tracer meshes — weapons and ranged enemies used to alloc a new
# MeshInstance3D + CylinderMesh + StandardMaterial3D on every single shot
# and queue_free() it a moment later. fast-firing weapons and multi-pellet
# shots made this the single hottest allocation path in combat. this pool
# preallocates a fixed set of tracers once and reuses them round-robin.

const POOL_SIZE: int = 32

static var _pool: Array[MeshInstance3D] = []
static var _mats: Array[StandardMaterial3D] = []
static var _cyls: Array[CylinderMesh] = []
static var _tweens: Array[Tween] = []
static var _next: int = 0
static var _initialized: bool = false


static func _ensure_init(host: Node) -> void:
	if _initialized:
		return
	_initialized = true

	for i in POOL_SIZE:
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.radial_segments = 4

		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.emission_enabled = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

		var tracer: MeshInstance3D = MeshInstance3D.new()
		tracer.mesh = cyl
		tracer.material_override = mat
		tracer.visible = false

		host.get_tree().root.add_child(tracer)

		_pool.append(tracer)
		_mats.append(mat)
		_cyls.append(cyl)
		_tweens.append(null)


static func spawn(host: Node, from_pos: Vector3, to_pos: Vector3, color: Color = Color(1.0, 0.7, 0.2),
		duration: float = 0.1, width_start: float = 0.012, width_end: float = -1.0) -> void:
	var dist: float = from_pos.distance_to(to_pos)
	if dist < 0.1:
		return

	_ensure_init(host)

	var idx: int = _next
	_next = (_next + 1) % POOL_SIZE

	var tracer: MeshInstance3D = _pool[idx]
	var mat: StandardMaterial3D = _mats[idx]
	var cyl: CylinderMesh = _cyls[idx]

	cyl.top_radius = width_start
	cyl.bottom_radius = width_end if width_end >= 0.0 else width_start
	cyl.height = dist

	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	mat.albedo_color = Color(color.r, color.g, color.b, 0.8)

	tracer.global_position = (from_pos + to_pos) / 2.0
	var dir: Vector3 = (to_pos - from_pos).normalized()
	if dir.length() > 0.001:
		tracer.look_at(tracer.global_position + dir)
		tracer.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	tracer.visible = true

	# a still-fading reuse of this slot shouldn't fight the new one
	if _tweens[idx] and is_instance_valid(_tweens[idx]):
		_tweens[idx].kill()

	var tween: Tween = tracer.create_tween()
	_tweens[idx] = tween
	tween.tween_property(mat, "albedo_color:a", 0.0, duration)
	tween.parallel().tween_property(mat, "emission_energy_multiplier", 0.0, duration)
	tween.chain().tween_callback(func(): tracer.visible = false)
