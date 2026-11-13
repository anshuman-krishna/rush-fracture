class_name BeamEmitter
extends BaseWeapon

# "stinger" — a continuous beam. it cannot miss and it ramps up the longer it
# stays on one target, but it builds heat and locks out if you never let go.

const TICK: float = 0.05
const FOCUS_RAMP_TIME: float = 2.0
const FOCUS_MAX_BONUS: float = 0.6
const COOL_DELAY: float = 0.25

var heat: float = 0.0
var max_heat: float = 100.0
var heat_per_tick: float = 2.3
var cool_rate: float = 36.0
var overheat_cool_rate: float = 30.0
var overheated: bool = false

var _beam: MeshInstance3D
var _beam_mat: StandardMaterial3D
var _tick_timer: float = 0.0
var _idle_time: float = 0.0
var _focus_target: Node
var _focus_time: float = 0.0
var _firing: bool = false
var _sound_timer: float = 0.0


func _configure() -> void:
	weapon_id = &"beam_emitter"
	display_name = "stinger"
	model_path = "res://assets/models/grafted-brood-beam_emitter.glb"
	muzzle_fallback = Vector3(0, 0.12, -0.419)
	grip_lift = 0.09
	base_damage = 7.0
	fire_interval = TICK
	weapon_range = 60.0
	weak_mult = 1.4
	recoil_pitch = 0.0
	shake_on_fire = 0.25
	view_kick = 0.004
	tracer_color = Color(0.3, 0.9, 1.0)
	fire_sound = &"beam_fire"


func _ready() -> void:
	super._ready()
	_beam = MeshInstance3D.new()
	_beam.top_level = true
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.02
	cyl.bottom_radius = 0.02
	cyl.height = 1.0
	cyl.radial_segments = 6
	_beam.mesh = cyl
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.albedo_color = tracer_color
	_beam.material_override = _beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	add_child(_beam)


func reset_state() -> void:
	super.reset_state()
	heat = 0.0
	overheated = false
	_focus_time = 0.0
	_focus_target = null
	_hide_beam()


func _capacity() -> float:
	return max_heat * (1.5 if has_flag(&"capacity") else 1.0)


func _on_holster() -> void:
	_hide_beam()


func _tick(delta: float, held: bool, _pressed: bool, _released: bool) -> void:
	_firing = held and not overheated
	if not _firing:
		_hide_beam()
		_cool(delta)
		_focus_time = maxf(0.0, _focus_time - delta * 2.0)
		return

	_idle_time = 0.0
	_tick_timer -= delta
	var end: Vector3 = _update_beam()
	if _tick_timer > 0.0:
		return
	var interval: float = TICK * (0.8 if has_flag(&"rapid") else 1.0) / maxf(0.1, _stat(&"fire_rate"))
	_tick_timer = interval

	heat += heat_per_tick * _stat(&"heat_gain")
	if heat >= _capacity():
		heat = _capacity()
		overheated = true
		_hide_beam()
		Game.sfx(&"overheat", -4.0)
		return

	_damage_along_beam(end)
	_sound_timer -= interval
	if _sound_timer <= 0.0:
		_sound_timer = 0.11
		Game.sfx(fire_sound, -12.0, 0.04)
	if camera and camera.has_method("add_shake"):
		camera.add_shake(shake_on_fire)
	_kick = minf(_kick + view_kick, 0.02)
	fired.emit()


func _tick_holstered(delta: float) -> void:
	_cool(delta)


func _cool(delta: float) -> void:
	_idle_time += delta
	if overheated:
		heat = maxf(0.0, heat - overheat_cool_rate * delta)
		if heat <= 0.0:
			overheated = false
	elif _idle_time >= COOL_DELAY:
		heat = maxf(0.0, heat - cool_rate * delta)


func _damage_along_beam(_end: Vector3) -> void:
	var dir: Vector3 = _aim_dir()
	var from: Vector3 = _aim_origin()
	var damage: float = base_damage * (0.9 if has_flag(&"rapid") else 1.0)
	var excluded: Array[RID] = []
	var max_targets: int = 5 if has_flag(&"piercing") else 1
	var first_body: Node = null

	for n: int in max_targets:
		var result: Dictionary = _ray(from, dir, weapon_range, excluded)
		if result.is_empty():
			break
		if not result.collider is CharacterBody3D:
			_resolve_hit(result.collider, result.position, result.normal, dir, damage, {"kind": DamageInfo.KIND_BEAM})
			break
		var body: CharacterBody3D = result.collider as CharacterBody3D
		if n == 0:
			first_body = body
			if body == _focus_target:
				_focus_time = minf(_focus_time + TICK, FOCUS_RAMP_TIME)
			else:
				_focus_target = body
				_focus_time = 0.0
		var focus: float = 1.0 + FOCUS_MAX_BONUS * (_focus_time / FOCUS_RAMP_TIME) if n == 0 else 1.0
		_resolve_hit(body, result.position, result.normal, dir, damage * focus * pow(0.8, n),
			{"kind": DamageInfo.KIND_BEAM, "can_crit": n == 0})
		excluded.append(body.get_rid())

	if not first_body:
		_focus_target = null
		_focus_time = maxf(0.0, _focus_time - TICK * 2.0)
	elif has_flag(&"chain"):
		var next: Node3D = Combat.nearest_enemy(get_tree(), (first_body as Node3D).global_position, 7.0, [first_body])
		if next:
			var a: Vector3 = first_body.aim_point() if first_body.has_method("aim_point") else (first_body as Node3D).global_position
			var b: Vector3 = next.aim_point() if next.has_method("aim_point") else next.global_position
			Vfx.lightning(a, b, tracer_color, 0.08, 0.25, 0.014)
			var combat: Combat = Game.combat()
			if combat:
				combat.deal(next, damage * 0.45, {"position": b, "kind": DamageInfo.KIND_BEAM, "weapon": weapon_id, "can_proc": false, "quiet": true})


## moves the beam mesh to span muzzle → first thing hit. returns the end point.
func _update_beam() -> Vector3:
	var dir: Vector3 = _aim_dir()
	var from: Vector3 = _aim_origin()
	var end: Vector3 = from + dir * weapon_range
	var result: Dictionary = _ray(from, dir, weapon_range)
	if not result.is_empty() and not has_flag(&"piercing"):
		end = result.position
	elif not result.is_empty() and not result.collider is CharacterBody3D:
		end = result.position

	var start: Vector3 = _muzzle_pos()
	var span: Vector3 = end - start
	var length: float = span.length()
	if length < 0.05:
		_beam.visible = false
		return end
	(_beam.mesh as CylinderMesh).height = length
	var d: Vector3 = span / length
	var up: Vector3 = Vector3.UP if absf(d.y) < 0.99 else Vector3.RIGHT
	var x_axis: Vector3 = up.cross(d).normalized()
	var z_axis: Vector3 = x_axis.cross(d).normalized()
	_beam.global_transform = Transform3D(Basis(x_axis, d, z_axis), start + span * 0.5)
	var heat_ratio: float = heat / _capacity()
	var focus_ratio: float = _focus_time / FOCUS_RAMP_TIME
	var c: Color = tracer_color.lerp(Color(1.0, 0.4, 0.15), heat_ratio * 0.8)
	_beam_mat.albedo_color = Color(c.r, c.g, c.b, 0.75 + randf() * 0.25)
	var width: float = 0.016 + focus_ratio * 0.02
	(_beam.mesh as CylinderMesh).top_radius = width
	(_beam.mesh as CylinderMesh).bottom_radius = width
	_beam.visible = true
	return end


func _hide_beam() -> void:
	if _beam:
		_beam.visible = false


func get_heat_ratio() -> float:
	return heat / _capacity()


func hud_state() -> Dictionary:
	var ratio: float = get_heat_ratio()
	return {
		"meter": ratio,
		"meter_color": Color(1.0, 0.2, 0.1) if overheated else Color(0.3, 0.9, 1.0).lerp(Color(1.0, 0.5, 0.1), ratio),
		"warn": overheated,
		"label": "overheat" if overheated else "heat",
	}
