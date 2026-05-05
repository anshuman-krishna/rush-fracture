class_name PulseRifle
extends BaseWeapon

# balanced hitscan weapon. adapted from original weapon system.

var weapon_range: float = 100.0

var fire_timer: float = 0.0
var camera: Camera3D
var muzzle_flash: MeshInstance3D

# upgrade flags
var burst_mode: bool = false
var armor_piercing: bool = false
var _burst_count: int = 0


func _ready() -> void:
	base_damage = 25
	base_fire_rate = 0.12
	shake_on_fire = 1.5
	camera = get_viewport().get_camera_3d()

	_create_viewmodel()
	_create_muzzle_flash()


func _create_viewmodel() -> void:
	var body_color := Color(0.15, 0.15, 0.18)
	var accent_color := Color(0.6, 0.12, 0.08)
	var parts: Array[Dictionary] = [
		# main body
		{ "size": Vector3(0.06, 0.06, 0.4), "offset": Vector3.ZERO, "color": body_color },
		# barrel
		{ "size": Vector3(0.03, 0.03, 0.2), "offset": Vector3(0, 0.01, -0.28), "color": Color(0.1, 0.1, 0.12) },
		# top rail
		{ "size": Vector3(0.04, 0.015, 0.2), "offset": Vector3(0, 0.038, -0.05), "color": Color(0.12, 0.12, 0.14) },
		# grip
		{ "size": Vector3(0.04, 0.1, 0.04), "offset": Vector3(0, -0.07, 0.1), "color": body_color },
		# accent stripe
		{ "size": Vector3(0.065, 0.01, 0.08), "offset": Vector3(0, 0.035, -0.12), "color": accent_color, "emission": accent_color },
	]
	viewmodel = _build_viewmodel_mesh(parts)
	add_child(viewmodel)


func _process(delta: float) -> void:
	fire_timer = max(0, fire_timer - delta)


func try_fire(effective_damage: int, effective_fire_rate: float) -> bool:
	if fire_timer > 0:
		return false

	if burst_mode:
		_fire_burst(effective_damage, effective_fire_rate)
	else:
		_fire_single(effective_damage)
		fire_timer = effective_fire_rate

	_show_muzzle_flash()

	if camera and camera.has_method("add_shake"):
		camera.add_shake(shake_on_fire)

	return true


func _fire_single(effective_damage: int) -> void:
	var result: Dictionary = _raycast()
	var screen_center: Vector2 = get_viewport().get_visible_rect().size / 2

	var visual_from: Vector3 = _get_muzzle_position()
	var visual_to: Vector3 = visual_from + -global_transform.basis.z * weapon_range

	if camera:
		var ray_from: Vector3 = camera.project_ray_origin(screen_center)
		var ray_dir: Vector3 = camera.project_ray_normal(screen_center).normalized()
		visual_to = ray_from + ray_dir * weapon_range

	if not result.is_empty():
		visual_to = result.position

	_spawn_tracer(visual_from, visual_to, Color(1.0, 0.7, 0.2), 0.08)

	if not result.is_empty():
		_apply_hit(result, effective_damage)


func _fire_burst(effective_damage: int, effective_fire_rate: float) -> void:
	fire_timer = effective_fire_rate * 1.2
	var burst_damage: int = int(effective_damage * 0.7)

	_fire_single(burst_damage)

	var tween: Tween = create_tween()
	for i in 2:
		tween.tween_interval(0.04)
		tween.tween_callback(func():
			_fire_single(burst_damage)
			_show_muzzle_flash()
		)


func _raycast() -> Dictionary:
	if not camera:
		return {}
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var screen_center: Vector2 = get_viewport().get_visible_rect().size / 2
	var from: Vector3 = camera.project_ray_origin(screen_center)
	var to: Vector3 = from + camera.project_ray_normal(screen_center) * weapon_range

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = _get_collision_mask()
	query.collide_with_areas = false
	query.exclude = _get_owner_exclude()
	return space_state.intersect_ray(query)


func _apply_hit(result: Dictionary, effective_damage: int) -> void:
	var hit: Object = result.collider
	var hit_pos: Vector3 = result.position
	var dmg: int = effective_damage
	if armor_piercing:
		dmg = int(dmg * 1.4)
	if _handle_hit_with_breakable(hit, hit_pos, dmg):
		return
	_handle_hit(hit, hit_pos, dmg)


func _create_muzzle_flash() -> void:
	muzzle_flash = MeshInstance3D.new()

	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.03
	mesh.height = 0.06
	muzzle_flash.mesh = mesh

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.2)
	mat.emission_energy_multiplier = 5.0
	mat.albedo_color = Color(1.0, 0.8, 0.3)
	muzzle_flash.material_override = mat

	muzzle_flash.visible = false

	if muzzle:
		muzzle.add_child(muzzle_flash)
		muzzle_flash.position = Vector3.ZERO
	else:
		add_child(muzzle_flash)
		muzzle_flash.position = Vector3(0.0, 0.0, -0.38)

func _show_muzzle_flash() -> void:
	if not muzzle_flash:
		return
	muzzle_flash.visible = true
	var tween: Tween = create_tween()
	tween.tween_property(muzzle_flash, "visible", false, 0.05)


func get_weapon_name() -> String:
	return "pulse rifle"
