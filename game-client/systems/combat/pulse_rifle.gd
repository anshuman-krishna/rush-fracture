class_name PulseRifle
extends Node3D

# balanced hitscan weapon. adapted from original weapon system.

signal enemy_killed
signal enemy_hit(position: Vector3)

var base_damage := 25
var base_fire_rate := 0.12
var shake_on_fire := 1.5
var range := 100.0

var fire_timer := 0.0
var camera: Camera3D
var muzzle_flash: MeshInstance3D

# upgrade flags
var burst_mode := false
var armor_piercing := false
var _burst_count := 0


func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	_create_muzzle_flash()


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
	var result := _raycast()
	if result.is_empty():
		return
	_apply_hit(result, effective_damage)


func _fire_burst(effective_damage: int, effective_fire_rate: float) -> void:
	fire_timer = effective_fire_rate * 1.2
	var burst_damage := int(effective_damage * 0.7)

	_fire_single(burst_damage)

	var tween := create_tween()
	for i in 2:
		tween.tween_interval(0.04)
		tween.tween_callback(func():
			_fire_single(burst_damage)
			_show_muzzle_flash()
		)


func _raycast() -> Dictionary:
	if not camera:
		return {}
	var space_state := get_world_3d().direct_space_state
	var screen_center := get_viewport().get_visible_rect().size / 2
	var from := camera.project_ray_origin(screen_center)
	var to := from + camera.project_ray_normal(screen_center) * range

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2
	query.collide_with_areas = false
	return space_state.intersect_ray(query)


func _apply_hit(result: Dictionary, effective_damage: int) -> void:
	var hit := result.collider
	var hit_pos: Vector3 = result.position
	if hit is CharacterBody3D:
		var health := hit.get_node_or_null("HealthComponent") as HealthComponent
		if health:
			var dmg := effective_damage
			if armor_piercing:
				dmg = int(dmg * 1.4)
			var was_alive := health.is_alive()
			health.take_damage(dmg)
			enemy_hit.emit(hit_pos)
			if was_alive and not health.is_alive():
				enemy_killed.emit()


func _create_muzzle_flash() -> void:
	muzzle_flash = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.03
	mesh.height = 0.06
	muzzle_flash.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.2)
	mat.emission_energy_multiplier = 5.0
	mat.albedo_color = Color(1.0, 0.8, 0.3)
	muzzle_flash.material_override = mat
	muzzle_flash.visible = false
	muzzle_flash.position = Vector3(0.15, -0.08, -0.4)
	add_child(muzzle_flash)


func _show_muzzle_flash() -> void:
	if not muzzle_flash:
		return
	muzzle_flash.visible = true
	var tween := create_tween()
	tween.tween_property(muzzle_flash, "visible", false, 0.05)


func get_weapon_name() -> String:
	return "pulse rifle"
