class_name BaseWeapon
extends Node3D

# base class for all weapons. defines the shared interface
# that weapon_manager relies on for type-safe access.

signal enemy_killed
signal enemy_hit(position: Vector3)
signal player_hit(target: CharacterBody3D, damage: int)

var base_damage: int = 0
var base_fire_rate: float = 0.0
var shake_on_fire: float = 0.0

var muzzle: Marker3D # Tip of the gun, where the laser originates

# pvp combat reference — set by game_manager when pvp is active
var pvp_manager: Node = null

# viewmodel — visible weapon mesh on screen
var viewmodel: Node3D


func _create_viewmodel() -> void:
	# override in subclasses for custom shapes
	pass


func _build_viewmodel_mesh(parts: Array[Dictionary]) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Viewmodel"
	root.position = Vector3(0.35, -0.25, -0.5)
	root.rotation_degrees = Vector3(0, -5, -3)

	for part in parts:
		var mesh_inst: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = part.size
		mesh_inst.mesh = box
		mesh_inst.position = part.offset

		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = part.color
		if part.has("emission"):
			mat.emission_enabled = true
			mat.emission = part.emission
			mat.emission_energy_multiplier = 1.5
		mesh_inst.material_override = mat

		root.add_child(mesh_inst)

	# Point de sortie du laser / balle
	muzzle = Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, 0.02, -0.35)
	root.add_child(muzzle)

	return root


func try_fire(_effective_damage: int, _effective_fire_rate: float) -> bool:
	return false


func get_weapon_name() -> String:
	return ""


func _get_collision_mask() -> int:
	# layer 1 = terrain/walls, layer 2 = enemies
	# always include layer 1 so we can hit breakable walls
	if pvp_manager and pvp_manager.is_active():
		return 3  # terrain + enemies + players
	return 3  # terrain + enemies


func _handle_hit(collider: Object, hit_pos: Vector3, damage: int) -> void:
	if not collider is CharacterBody3D:
		return

	var body: CharacterBody3D = collider as CharacterBody3D

	# pvp: check if target is another player
	if pvp_manager and pvp_manager.is_active() and body.is_in_group("player"):
		var owner_player: CharacterBody3D = _get_owner_player()
		if owner_player and owner_player != body:
			pvp_manager.try_pvp_damage(owner_player, body, damage)
			player_hit.emit(body, damage)
		return

	# pve: standard enemy damage
	var health: HealthComponent = body.get_node_or_null("HealthComponent") as HealthComponent
	if health:
		var was_alive: bool = health.is_alive()
		health.take_damage(damage)
		enemy_hit.emit(hit_pos)
		if was_alive and not health.is_alive():
			enemy_killed.emit()


func _get_owner_player() -> CharacterBody3D:
	# weapon → head → player
	var player: CharacterBody3D = get_parent().get_parent() as CharacterBody3D
	return player


func _get_owner_exclude() -> Array[RID]:
	var player: CharacterBody3D = _get_owner_player()
	if player:
		return [player.get_rid()]
	return []


func _spawn_tracer(from_pos: Vector3, to_pos: Vector3, color: Color = Color(1.0, 0.7, 0.2), duration: float = 0.1, width: float = 0.012) -> void:
	var dist: float = from_pos.distance_to(to_pos)
	if dist < 0.1:
		return

	var tracer: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = width
	cyl.bottom_radius = width
	cyl.height = dist
	cyl.radial_segments = 4
	tracer.mesh = cyl

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	mat.albedo_color = Color(color.r, color.g, color.b, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tracer.material_override = mat

	get_tree().root.add_child(tracer)

	var midpoint: Vector3 = (from_pos + to_pos) / 2.0
	tracer.global_position = midpoint

	var dir: Vector3 = (to_pos - from_pos).normalized()
	if dir.length() > 0.001:
		tracer.look_at(tracer.global_position + dir)
		tracer.rotate_object_local(Vector3.RIGHT, PI / 2.0)

	var tween: Tween = tracer.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, duration)
	tween.parallel().tween_property(mat, "emission_energy_multiplier", 0.0, duration)
	tween.chain().tween_callback(tracer.queue_free)


func _handle_hit_with_breakable(collider: Object, hit_pos: Vector3, damage: int) -> bool:
	# returns true if hit was a breakable wall
	if collider is StaticBody3D:
		var wall: StaticBody3D = collider as StaticBody3D
		if wall.has_meta("breakable"):
			var rc: Node = get_node_or_null("/root/Main/RoomController")
			if rc and rc.has_method("damage_breakable_wall"):
				rc.damage_breakable_wall(wall)
			return true
	return false

func _get_muzzle_position() -> Vector3:
	if muzzle and is_instance_valid(muzzle):
		return muzzle.global_position

	if viewmodel and is_instance_valid(viewmodel):
		return viewmodel.global_position

	return global_position
