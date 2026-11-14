extends EnemyBase

# "watcher stalk" — fragile, far away, and hits hard. it tracks you with a
# laser, then the laser locks and brightens for a beat before it fires down
# that fixed line. move during the lock and it misses.

const PREFERRED_RANGE: float = 22.0
const COOLDOWN: float = 3.6
const TRACK_TIME: float = 1.0
const LOCK_TIME: float = 0.3
const SHOT_RANGE: float = 80.0
const HIT_WIDTH: float = 0.75
const LASER_COLOR: Color = Color(1.0, 0.15, 0.1)

var _cooldown: float = 2.0
var _track: float = 0.0
var _lock: float = 0.0
var _aim_from: Vector3
var _aim_to: Vector3
var _laser: MeshInstance3D
var _laser_mat: StandardMaterial3D


func _setup() -> void:
	_cooldown = randf_range(1.5, 3.0)


func _ai(delta: float, dist: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)

	if _lock > 0.0:
		_lock -= delta
		_brake(40.0, delta)
		_draw_laser(true)
		if _lock <= 0.0:
			_fire()
		return

	if _track > 0.0:
		_track -= delta
		_brake(40.0, delta)
		_face_target(delta, 10.0)
		_aim_from = _muzzle_position()
		_aim_to = _aim_from + (target.global_position - _aim_from).normalized() * SHOT_RANGE
		_draw_laser(false)
		if _track <= 0.0:
			_lock = LOCK_TIME
			Game.sfx_at(&"sniper_lock", global_position, -8.0)
		return

	_keep_range(delta, dist, PREFERRED_RANGE, 9.0)
	if _cooldown <= 0.0 and _has_line_of_sight(target.global_position):
		_track = TRACK_TIME * (0.7 if is_elite else 1.0)


func _fire() -> void:
	_hide_laser()
	_cooldown = COOLDOWN
	var dir: Vector3 = (_aim_to - _aim_from).normalized()
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(_aim_from, _aim_to, Layers.WORLD)
	query.exclude = [get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	var end: Vector3 = hit.position if not hit.is_empty() else _aim_to
	if not hit.is_empty() and hit.collider is StaticBody3D and (hit.collider as StaticBody3D).has_meta("breakable"):
		var rooms: RoomController = Game.rooms()
		if rooms:
			rooms.damage_breakable(hit.collider as StaticBody3D, 2)

	Vfx.tracer(_aim_from, end, LASER_COLOR, 0.25, 0.05, 0.02)
	Vfx.light(_aim_from, LASER_COLOR, 3.0, 0.15, 6.0)
	Game.sfx_at(&"sniper_fire", _aim_from, -3.0, 0.05)

	var pm: PlayerManager = Game.players()
	if not pm:
		return
	for p: CharacterBody3D in pm.get_all_players():
		if not is_instance_valid(p) or p.get("is_dead") == true:
			continue
		var closest: Vector3 = Geometry3D.get_closest_point_to_segment(p.global_position, _aim_from, end)
		var off: Vector3 = closest - p.global_position
		if Vector2(off.x, off.z).length() <= HIT_WIDTH and absf(off.y) <= 1.1:
			_hit_player(p, damage(), DamageInfo.KIND_BULLET)


func _on_hurt(_amount: int, _info: DamageInfo) -> void:
	# a hit breaks its concentration
	if _track > 0.0 or _lock > 0.0:
		_track = 0.0
		_lock = 0.0
		_cooldown = COOLDOWN * 0.5
		_hide_laser()


func _on_death(_info: DamageInfo) -> void:
	_hide_laser()


func _exit_tree() -> void:
	if _laser and is_instance_valid(_laser):
		_laser.queue_free()


func _draw_laser(locked: bool) -> void:
	if not _laser:
		_laser = MeshInstance3D.new()
		_laser.top_level = true
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.radial_segments = 4
		cyl.height = 1.0
		_laser.mesh = cyl
		_laser_mat = StandardMaterial3D.new()
		_laser_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_laser_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_laser_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_laser.material_override = _laser_mat
		_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_laser)
	var span: Vector3 = _aim_to - _aim_from
	var length: float = span.length()
	if length < 0.1:
		return
	var cyl_mesh: CylinderMesh = _laser.mesh as CylinderMesh
	var width: float = 0.035 if locked else 0.012
	cyl_mesh.top_radius = width
	cyl_mesh.bottom_radius = width
	cyl_mesh.height = length
	var d: Vector3 = span / length
	var up: Vector3 = Vector3.UP if absf(d.y) < 0.99 else Vector3.RIGHT
	var x_axis: Vector3 = up.cross(d).normalized()
	var z_axis: Vector3 = x_axis.cross(d).normalized()
	_laser.global_transform = Transform3D(Basis(x_axis, d, z_axis), _aim_from + span * 0.5)
	_laser_mat.albedo_color = Color(1.0, 0.9, 0.7, 0.95) if locked else Color(LASER_COLOR.r, LASER_COLOR.g, LASER_COLOR.b, 0.55)
	_laser.visible = true


func _hide_laser() -> void:
	if _laser:
		_laser.visible = false
