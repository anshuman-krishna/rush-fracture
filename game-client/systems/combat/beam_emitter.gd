class_name BeamEmitter
extends Node3D

# continuous damage beam with heat management.

signal enemy_killed
signal enemy_hit(position: Vector3)

var base_damage := 6
var base_fire_rate := 0.05
var shake_on_fire := 0.4
var range := 60.0

var fire_timer := 0.0
var camera: Camera3D
var beam_mesh: MeshInstance3D

# heat system
var heat := 0.0
var max_heat := 100.0
var heat_per_tick := 2.5
var cool_rate := 30.0
var overheat_cool_rate := 20.0
var overheated := false
var overheat_threshold := 100.0

# upgrade flags
var chain_beam := false
var chain_range := 6.0
var chain_damage_ratio := 0.4
var extended_capacity := false


func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	_create_beam_visual()
	if extended_capacity:
		max_heat = 150.0
		overheat_threshold = 150.0


func _process(delta: float) -> void:
	fire_timer = max(0, fire_timer - delta)

	if overheated:
		heat = max(0, heat - overheat_cool_rate * delta)
		if heat <= 0:
			overheated = false
	elif not Input.is_action_pressed("shoot"):
		heat = max(0, heat - cool_rate * delta)

	_update_beam_visual()


func try_fire(effective_damage: int, effective_fire_rate: float) -> bool:
	if overheated or fire_timer > 0:
		return false

	fire_timer = effective_fire_rate
	heat += heat_per_tick

	if heat >= overheat_threshold:
		heat = max_heat
		overheated = true
		_hide_beam()
		return false

	_fire_beam(effective_damage)
	return true


func _fire_beam(effective_damage: int) -> void:
	if not camera:
		return

	var space_state := get_world_3d().direct_space_state
	var screen_center := get_viewport().get_visible_rect().size / 2
	var from := camera.project_ray_origin(screen_center)
	var forward := camera.project_ray_normal(screen_center)
	var to := from + forward * range

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2
	query.collide_with_areas = false

	var result := space_state.intersect_ray(query)
	if result.is_empty():
		_show_beam(from, to)
		return

	var hit := result.collider
	var hit_pos: Vector3 = result.position
	_show_beam(from, hit_pos)

	if hit is CharacterBody3D:
		var health := hit.get_node_or_null("HealthComponent") as HealthComponent
		if health:
			var was_alive := health.is_alive()
			health.take_damage(effective_damage)
			enemy_hit.emit(hit_pos)
			if was_alive and not health.is_alive():
				enemy_killed.emit()

			if chain_beam:
				_apply_chain(hit_pos, hit, effective_damage)


func _apply_chain(origin: Vector3, exclude: Node, effective_damage: int) -> void:
	var chain_dmg := int(effective_damage * chain_damage_ratio)
	if chain_dmg <= 0:
		return

	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy == exclude or not enemy is Node3D:
			continue
		if enemy.global_position.distance_to(origin) > chain_range:
			continue
		var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
		if health and health.is_alive():
			var was_alive := health.is_alive()
			health.take_damage(chain_dmg)
			if was_alive and not health.is_alive():
				enemy_killed.emit()
			break


func _create_beam_visual() -> void:
	beam_mesh = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.015
	mesh.bottom_radius = 0.015
	mesh.height = 1.0
	beam_mesh.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 1.0)
	mat.emission_energy_multiplier = 4.0
	mat.albedo_color = Color(0.3, 0.9, 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.7
	beam_mesh.material_override = mat
	beam_mesh.visible = false
	add_child(beam_mesh)


func _show_beam(from: Vector3, to: Vector3) -> void:
	if not beam_mesh:
		return
	var midpoint := (from + to) / 2.0
	var distance := from.distance_to(to)
	beam_mesh.global_position = midpoint

	var direction := (to - from).normalized()
	if direction.length() > 0.001:
		beam_mesh.look_at(beam_mesh.global_position + direction)
		beam_mesh.rotate_object_local(Vector3.RIGHT, PI / 2.0)

	var mesh := beam_mesh.mesh as CylinderMesh
	mesh.height = distance
	beam_mesh.visible = true


func _hide_beam() -> void:
	if beam_mesh:
		beam_mesh.visible = false


func _update_beam_visual() -> void:
	if not Input.is_action_pressed("shoot") or overheated:
		_hide_beam()


func get_heat_ratio() -> float:
	return heat / max_heat


func is_overheated() -> bool:
	return overheated


func get_weapon_name() -> String:
	return "beam emitter"
