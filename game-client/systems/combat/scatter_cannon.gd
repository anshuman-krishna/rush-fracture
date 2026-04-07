class_name ScatterCannon
extends BaseWeapon

# close-range spread weapon. multiple raycasts per shot.

var weapon_range: float = 40.0
var pellet_count: int = 7
var spread_angle: float = 0.08

var fire_timer: float = 0.0
var camera: Camera3D
var muzzle_flash: MeshInstance3D

# upgrade flags
var tight_spread: bool = false
var double_blast: bool = false
var _double_blast_pending: bool = false


func _ready() -> void:
	base_damage = 8
	base_fire_rate = 0.45
	shake_on_fire = 3.0
	camera = get_viewport().get_camera_3d()
	_create_muzzle_flash()
	_create_viewmodel()


func _create_viewmodel() -> void:
	var body_color := Color(0.12, 0.12, 0.14)
	var accent_color := Color(1.0, 0.4, 0.05)
	var parts: Array[Dictionary] = [
		# main body — chunky
		{ "size": Vector3(0.08, 0.08, 0.32), "offset": Vector3.ZERO, "color": body_color },
		# wide barrel
		{ "size": Vector3(0.07, 0.07, 0.12), "offset": Vector3(0, 0, -0.2), "color": Color(0.08, 0.08, 0.1) },
		# barrel flare
		{ "size": Vector3(0.09, 0.09, 0.03), "offset": Vector3(0, 0, -0.27), "color": Color(0.1, 0.1, 0.1) },
		# grip
		{ "size": Vector3(0.05, 0.11, 0.05), "offset": Vector3(0, -0.08, 0.08), "color": body_color },
		# pump handle
		{ "size": Vector3(0.04, 0.04, 0.12), "offset": Vector3(0, -0.04, -0.1), "color": Color(0.2, 0.18, 0.14) },
		# accent
		{ "size": Vector3(0.085, 0.01, 0.06), "offset": Vector3(0, 0.045, -0.04), "color": accent_color, "emission": accent_color },
	]
	viewmodel = _build_viewmodel_mesh(parts)
	add_child(viewmodel)


func _process(delta: float) -> void:
	fire_timer = max(0, fire_timer - delta)


func try_fire(effective_damage: int, effective_fire_rate: float) -> bool:
	if fire_timer > 0:
		return false

	_fire_spread(effective_damage)
	fire_timer = effective_fire_rate

	if double_blast and not _double_blast_pending:
		_double_blast_pending = true
		var tween: Tween = create_tween()
		tween.tween_interval(0.08)
		tween.tween_callback(func():
			_fire_spread(int(effective_damage * 0.6))
			_show_muzzle_flash()
			_double_blast_pending = false
		)

	_show_muzzle_flash()

	if camera and camera.has_method("add_shake"):
		camera.add_shake(shake_on_fire)

	return true


func _fire_spread(effective_damage: int) -> void:
	if not camera:
		return

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var screen_center: Vector2 = get_viewport().get_visible_rect().size / 2
	var from: Vector3 = camera.project_ray_origin(screen_center)
	var forward: Vector3 = camera.project_ray_normal(screen_center)
	var current_spread: float = spread_angle * (0.5 if tight_spread else 1.0)

	for i in pellet_count:
		var offset: Vector3 = Vector3(
			randf_range(-current_spread, current_spread),
			randf_range(-current_spread, current_spread),
			0
		)
		var direction: Vector3 = (forward + offset).normalized()
		var to: Vector3 = from + direction * weapon_range

		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = _get_collision_mask()
		query.collide_with_areas = false
		query.exclude = _get_owner_exclude()

		var result: Dictionary = space_state.intersect_ray(query)
		if result.is_empty():
			continue

		_handle_hit(result.collider, result.position, effective_damage)


func _create_muzzle_flash() -> void:
	muzzle_flash = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	muzzle_flash.mesh = mesh

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.1)
	mat.emission_energy_multiplier = 6.0
	mat.albedo_color = Color(1.0, 0.5, 0.2)
	muzzle_flash.material_override = mat
	muzzle_flash.visible = false
	muzzle_flash.position = Vector3(0.12, -0.1, -0.35)
	add_child(muzzle_flash)


func _show_muzzle_flash() -> void:
	if not muzzle_flash:
		return
	muzzle_flash.visible = true
	var tween: Tween = create_tween()
	tween.tween_property(muzzle_flash, "visible", false, 0.07)


func get_weapon_name() -> String:
	return "scatter cannon"
