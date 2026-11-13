class_name BaseWeapon
extends Node3D

# shared behaviour for every weapon: the viewmodel and its motion, aim rays,
# hit resolution, cooldown, recoil and sound. a concrete weapon sets its
# numbers in _configure() and implements _tick() to decide when to fire.

signal fired

const VIEW_REST: Vector3 = Vector3(0.2, -0.19, -0.42)
const VIEW_SCALE: float = 0.42
const EQUIP_TIME: float = 0.28

var weapon_id: StringName = &""
var display_name: String = ""
var model_path: String = ""
## fallback muzzle offset in model space, for models without an anchor_muzzle node
var muzzle_fallback: Vector3 = Vector3(0, 0.1, -0.4)
## how far the model's origin (its lowest point) sits below the grip
var grip_lift: float = 0.09

var base_damage: float = 10.0
## seconds between shots at fire_rate 1.0
var fire_interval: float = 0.2
var weapon_range: float = 100.0
var weak_mult: float = 1.5
var recoil_pitch: float = 0.5
var shake_on_fire: float = 1.0
var view_kick: float = 0.035
var tracer_color: Color = Color(1.0, 0.7, 0.2)
var fire_sound: StringName = &"pulse_fire"
var fire_volume: float = -6.0

var owner_player: CharacterBody3D
var camera: Camera3D
var viewmodel: Node3D
var model: Node3D
var muzzle: Node3D
var is_active: bool = false
var skin_id: StringName = &"default"

var _cooldown: float = 0.0
var _equip_timer: float = 0.0
var _kick: float = 0.0
var _bob_phase: float = 0.0
var _sway: Vector2 = Vector2.ZERO
var _last_yaw: float = 0.0
var _last_pitch: float = 0.0
var _flags: Dictionary = {}
var _flash: MeshInstance3D
var _flash_timer: float = 0.0


func _ready() -> void:
	_configure()
	_build_viewmodel()
	set_active(false)


## override: set id, name, model, damage, timing, colours.
func _configure() -> void:
	pass


## override: called every frame while this is the held weapon.
func _tick(_delta: float, _held: bool, _pressed: bool, _released: bool) -> void:
	pass


## override: called every frame while holstered (cooling, recharging).
func _tick_holstered(_delta: float) -> void:
	pass


## override: extra state for the hud. keys: meter (0..1), meter_color, warn, label.
func hud_state() -> Dictionary:
	return {}


## override: reset per-run state (heat, charge, stacks).
func reset_state() -> void:
	_cooldown = 0.0


func setup(player: CharacterBody3D, cam: Camera3D) -> void:
	owner_player = player
	camera = cam


func set_flag(flag: StringName, value: Variant = true) -> void:
	_flags[flag] = value


func has_flag(flag: StringName) -> bool:
	return _flags.get(flag, false) != false


func flag_value(flag: StringName, fallback: Variant = 0) -> Variant:
	return _flags.get(flag, fallback)


func clear_flags() -> void:
	_flags.clear()


func set_skin(id: StringName) -> void:
	skin_id = id
	if model:
		Skins.apply(model, id)
	tracer_color = _skinned_color(tracer_color)


func set_active(active: bool) -> void:
	is_active = active
	visible = active
	if active:
		_equip_timer = EQUIP_TIME / maxf(0.2, _stat(&"swap_speed"))
		_on_equip()
	else:
		_on_holster()


func _on_equip() -> void:
	pass


func _on_holster() -> void:
	pass


## true once the raise animation is done and the weapon may fire.
func is_ready() -> bool:
	return is_active and _equip_timer <= 0.0


func tick(delta: float, held: bool, pressed: bool, released: bool) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _equip_timer > 0.0:
		_equip_timer = maxf(0.0, _equip_timer - delta)
		_animate_view(delta)
		_tick(delta, false, false, false)
		return
	_tick(delta, held, pressed, released)
	_animate_view(delta)


func tick_holstered(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_tick_holstered(delta)


# --- helpers for concrete weapons -------------------------------------------

func _stat(key: StringName) -> float:
	if is_instance_valid(owner_player) and "stats" in owner_player:
		return owner_player.stats.value(key)
	return 1.0


func _can_fire() -> bool:
	return _cooldown <= 0.0


func _start_cooldown(scale: float = 1.0) -> void:
	_cooldown = fire_interval * scale / maxf(0.1, _stat(&"fire_rate"))


func _aim_origin() -> Vector3:
	if camera and is_instance_valid(camera):
		var head: Node3D = camera.get_parent() as Node3D
		return head.global_position if head else camera.global_position
	return global_position


func _aim_dir() -> Vector3:
	if camera and is_instance_valid(camera):
		# the head, not the camera: recoil and shake live on the camera node
		# and must never move where shots actually go
		var head: Node3D = camera.get_parent() as Node3D
		if head:
			return -head.global_transform.basis.z
		return -camera.global_transform.basis.z
	return -global_transform.basis.z


## direction with random spread, in radians of half-angle.
func _spread_dir(spread: float) -> Vector3:
	var dir: Vector3 = _aim_dir()
	if spread <= 0.0:
		return dir
	var right: Vector3 = dir.cross(Vector3.UP).normalized()
	if right.length() < 0.01:
		right = Vector3.RIGHT
	var up: Vector3 = right.cross(dir).normalized()
	var angle: float = randf() * TAU
	var mag: float = sqrt(randf()) * tan(spread)
	return (dir + right * cos(angle) * mag + up * sin(angle) * mag).normalized()


func _ray(from: Vector3, dir: Vector3, distance: float, extra_exclude: Array[RID] = []) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * distance)
	query.collision_mask = _shot_mask()
	query.collide_with_areas = false
	var exclude: Array[RID] = []
	if is_instance_valid(owner_player):
		exclude.append(owner_player.get_rid())
	exclude.append_array(extra_exclude)
	query.exclude = exclude
	return space.intersect_ray(query)


func _shot_mask() -> int:
	var combat: Combat = Game.combat()
	if combat and combat.pvp_manager and combat.pvp_manager.is_active():
		return Layers.SHOT | Layers.PLAYER
	return Layers.SHOT


## fires one hitscan ray along `dir`, draws its tracer and resolves the hit.
## returns the physics result (empty when it hit nothing).
func _hitscan(dir: Vector3, damage: float, opts: Dictionary = {}) -> Dictionary:
	var from: Vector3 = _aim_origin()
	var result: Dictionary = _ray(from, dir, weapon_range)
	var end: Vector3 = from + dir * weapon_range
	if not result.is_empty():
		end = result.position
	if not opts.get("no_tracer", false):
		Vfx.tracer(_muzzle_pos(), end, opts.get("tracer_color", tracer_color), opts.get("tracer_time", 0.08), opts.get("tracer_width", 0.012))
	if not result.is_empty():
		_resolve_hit(result.collider, result.position, result.normal, dir, damage, opts)
	return result


## applies a hit to whatever was struck. returns the DamageInfo for enemy hits.
func _resolve_hit(collider: Object, pos: Vector3, normal: Vector3, dir: Vector3, damage: float, opts: Dictionary = {}) -> DamageInfo:
	if collider is StaticBody3D:
		var rooms: RoomController = Game.rooms()
		if rooms and (collider as StaticBody3D).has_meta("breakable"):
			rooms.damage_breakable(collider as StaticBody3D, 1)
		Vfx.sparks(pos, normal, opts.get("tracer_color", tracer_color), 5.0, 50.0)
		return null
	if not collider is CharacterBody3D:
		return null

	var combat: Combat = Game.combat()
	if not combat:
		return null
	var body: CharacterBody3D = collider as CharacterBody3D
	var o: Dictionary = {
		"position": pos,
		"direction": dir,
		"weapon": weapon_id,
		"kind": opts.get("kind", DamageInfo.KIND_BULLET),
		"weak": body.has_method("is_weak_point") and body.is_weak_point(pos),
		"weak_mult": opts.get("weak_mult", weak_mult),
		"mult": opts.get("mult", 1.0),
		"knockback": opts.get("knockback", 0.0),
		"can_crit": opts.get("can_crit", true),
		"can_proc": opts.get("can_proc", true),
	}
	var info: DamageInfo = combat.deal(body, damage, o)
	if info:
		Vfx.sparks(pos, -dir, Color(1.0, 0.85, 0.6), 4.0, 60.0)
	return info


func _muzzle_pos() -> Vector3:
	if muzzle and is_instance_valid(muzzle) and muzzle.is_inside_tree():
		return muzzle.global_position
	return _aim_origin() + _aim_dir() * 0.5


func _after_shot(recoil_scale: float = 1.0) -> void:
	var r: float = _stat(&"recoil") * recoil_scale
	if camera and is_instance_valid(camera):
		if camera.has_method("add_recoil"):
			camera.add_recoil(recoil_pitch * r, randf_range(-0.25, 0.25) * recoil_pitch * r)
		if camera.has_method("add_shake"):
			camera.add_shake(shake_on_fire * r)
	_kick = minf(_kick + view_kick * recoil_scale, 0.12)
	_show_flash()
	Game.sfx(fire_sound, fire_volume, 0.06)
	fired.emit()


func _skinned_color(fallback: Color) -> Color:
	if skin_id != &"default" and Skins.exists(skin_id):
		return Skins.accent(skin_id)
	return fallback


# --- viewmodel ----------------------------------------------------------------

func _build_viewmodel() -> void:
	viewmodel = Node3D.new()
	viewmodel.name = "Viewmodel"
	viewmodel.position = VIEW_REST
	viewmodel.scale = Vector3.ONE * VIEW_SCALE
	viewmodel.rotation_degrees = Vector3(0, -4, -2)
	add_child(viewmodel)

	if not model_path.is_empty() and ResourceLoader.exists(model_path):
		var scene: PackedScene = load(model_path) as PackedScene
		if scene:
			model = scene.instantiate() as Node3D
			model.position.y = -grip_lift
			viewmodel.add_child(model)
			_no_shadows(model)

	muzzle = model.find_child("anchor_muzzle", true, false) as Node3D if model else null
	if not muzzle:
		muzzle = Marker3D.new()
		muzzle.name = "Muzzle"
		muzzle.position = muzzle_fallback
		viewmodel.add_child(muzzle)

	_flash = MeshInstance3D.new()
	var quad: SphereMesh = SphereMesh.new()
	quad.radius = 0.05
	quad.height = 0.1
	quad.radial_segments = 8
	quad.rings = 4
	_flash.mesh = quad
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = tracer_color
	_flash.material_override = mat
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false
	muzzle.add_child(_flash)


func _no_shadows(root: Node) -> void:
	# a first-person model casting onto the world reads as a floating blob
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is GeometryInstance3D:
			(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for child: Node in n.get_children():
			stack.append(child)


func _show_flash() -> void:
	if not _flash:
		return
	(_flash.material_override as StandardMaterial3D).albedo_color = tracer_color
	_flash.scale = Vector3.ONE * randf_range(0.8, 1.5)
	_flash.visible = true
	_flash_timer = 0.045


func _animate_view(delta: float) -> void:
	if not viewmodel:
		return
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and _flash:
			_flash.visible = false

	var speed: float = 0.0
	var grounded: bool = true
	if is_instance_valid(owner_player):
		speed = Vector2(owner_player.velocity.x, owner_player.velocity.z).length()
		grounded = owner_player.is_on_floor()

		# sway: the gun lags behind quick turns
		var yaw: float = owner_player.rotation.y
		var head: Node3D = owner_player.get_node_or_null("Head") as Node3D
		var pitch: float = head.rotation.x if head else 0.0
		var d_yaw: float = wrapf(yaw - _last_yaw, -PI, PI)
		var d_pitch: float = pitch - _last_pitch
		_last_yaw = yaw
		_last_pitch = pitch
		_sway = _sway.lerp(Vector2(clampf(d_yaw * 0.6, -0.05, 0.05), clampf(-d_pitch * 0.6, -0.05, 0.05)), clampf(10.0 * delta, 0.0, 1.0))

	if grounded and speed > 1.0:
		_bob_phase += delta * (6.0 + speed * 0.45)
	var bob_amount: float = clampf(speed / 14.0, 0.0, 1.0) * (0.008 if grounded else 0.002)
	var bob: Vector3 = Vector3(cos(_bob_phase * 0.5) * bob_amount, sin(_bob_phase) * bob_amount, 0)

	_kick = lerpf(_kick, 0.0, clampf(14.0 * delta, 0.0, 1.0))
	var raise: float = 0.0
	if _equip_timer > 0.0:
		var total: float = EQUIP_TIME / maxf(0.2, _stat(&"swap_speed"))
		raise = ease(_equip_timer / maxf(total, 0.001), 2.0)

	viewmodel.position = VIEW_REST + bob + Vector3(_sway.x, _sway.y - raise * 0.28, _kick)
	viewmodel.rotation = Vector3(deg_to_rad(_kick * 70.0 - raise * 35.0) + _sway.y * 0.8, deg_to_rad(-4.0) + _sway.x * 1.2, deg_to_rad(-2.0) + _sway.x * 1.5)
