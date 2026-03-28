class_name ScatterCannon
extends Node3D

# close-range spread weapon. multiple raycasts per shot.

signal enemy_killed
signal enemy_hit(position: Vector3)

var base_damage := 8
var base_fire_rate := 0.45
var shake_on_fire := 3.0
var range := 40.0
var pellet_count := 7
var spread_angle := 0.08

var fire_timer := 0.0
var camera: Camera3D
var muzzle_flash: MeshInstance3D

# upgrade flags
var tight_spread := false
var double_blast := false
var _double_blast_pending := false


func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	_create_muzzle_flash()


func _process(delta: float) -> void:
	fire_timer = max(0, fire_timer - delta)


func try_fire(effective_damage: int, effective_fire_rate: float) -> bool:
	if fire_timer > 0:
		return false

	_fire_spread(effective_damage)
	fire_timer = effective_fire_rate

	if double_blast and not _double_blast_pending:
		_double_blast_pending = true
		var tween := create_tween()
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

	var space_state := get_world_3d().direct_space_state
	var screen_center := get_viewport().get_visible_rect().size / 2
	var from := camera.project_ray_origin(screen_center)
	var forward := camera.project_ray_normal(screen_center)
	var current_spread := spread_angle * (0.5 if tight_spread else 1.0)

	for i in pellet_count:
		var offset := Vector3(
			randf_range(-current_spread, current_spread),
			randf_range(-current_spread, current_spread),
			0
		)
		var direction := (forward + offset).normalized()
		var to := from + direction * range

		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = 2
		query.collide_with_areas = false

		var result := space_state.intersect_ray(query)
		if result.is_empty():
			continue

		var hit := result.collider
		var hit_pos: Vector3 = result.position
		if hit is CharacterBody3D:
			var health := hit.get_node_or_null("HealthComponent") as HealthComponent
			if health:
				var was_alive := health.is_alive()
				health.take_damage(effective_damage)
				enemy_hit.emit(hit_pos)
				if was_alive and not health.is_alive():
					enemy_killed.emit()


func _create_muzzle_flash() -> void:
	muzzle_flash = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	muzzle_flash.mesh = mesh

	var mat := StandardMaterial3D.new()
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
	var tween := create_tween()
	tween.tween_property(muzzle_flash, "visible", false, 0.07)


func get_weapon_name() -> String:
	return "scatter cannon"
