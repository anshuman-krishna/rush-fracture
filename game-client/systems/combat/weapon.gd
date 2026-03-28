extends Node3D

signal enemy_killed
signal enemy_hit(position: Vector3)

@export var damage := 25
@export var fire_rate := 0.12
@export var range := 100.0
@export var shake_on_fire := 1.5

var fire_timer := 0.0
var camera: Camera3D
var muzzle_flash: MeshInstance3D


func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	_create_muzzle_flash()


func _process(delta: float) -> void:
	fire_timer = max(0, fire_timer - delta)

	if Input.is_action_pressed("shoot") and fire_timer <= 0:
		_fire()


func _fire() -> void:
	fire_timer = fire_rate
	_show_muzzle_flash()

	if camera and camera.has_method("add_shake"):
		camera.add_shake(shake_on_fire)

	var space_state := get_world_3d().direct_space_state
	var screen_center := get_viewport().get_visible_rect().size / 2
	var from := camera.project_ray_origin(screen_center)
	var to := from + camera.project_ray_normal(screen_center) * range

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2
	query.collide_with_areas = false

	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return

	var hit := result.collider
	var hit_pos: Vector3 = result.position
	if hit is CharacterBody3D:
		var health_node := hit.get_node_or_null("HealthComponent") as HealthComponent
		if health_node:
			var was_alive := health_node.is_alive()
			health_node.take_damage(damage)
			enemy_hit.emit(hit_pos)
			if was_alive and not health_node.is_alive():
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
