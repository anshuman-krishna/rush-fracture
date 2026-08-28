class_name EnemyBase
extends CharacterBody3D

# shared base for all standard (non-boss) enemy controllers. every enemy type
# used to duplicate this boilerplate independently — gravity, target
# acquisition, damage-flash/death visuals, authority checks, arena
# containment, fall-death — with the copies slowly drifting apart (some had
# arena clamping, some didn't; some had a fall-death safety net, most didn't).
# subclasses now implement only their own movement/attack/ability logic and
# call these shared helpers.

const ARENA_RADIUS: float = 33.0
const FALL_DEATH_Y: float = -20.0

const STEER_PROBE_DISTANCE: float = 1.5
# small enough to clear either origin convention used across enemy scenes
# (some sit at floor level, some at capsule-center) while still landing
# inside any obstacle's vertical span (shortest pillar is 1.5m tall).
const STEER_PROBE_HEIGHT: float = 0.5
# probe angles in radians, straight ahead first then widening left/right —
# 0, ±25, ±50, ±75 degrees
const STEER_ANGLES: PackedFloat32Array = [0.0, 0.436, -0.436, 0.873, -0.873, 1.309, -1.309]

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var target: CharacterBody3D
var is_dying: bool = false
var _player_manager: PlayerManager

# primary mesh for effects that need one specific part (e.g. sniper's muzzle
# flash) — set by a subclass's _build_visual() if it needs this; hit-flash
# and death-fade below don't depend on it, they act on every mesh part found.
var mesh: MeshInstance3D

@onready var health: HealthComponent = $HealthComponent


func _ready() -> void:
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	add_to_group("enemies")
	_player_manager = get_node_or_null("/root/Main/PlayerManager") as PlayerManager
	# enemies not yet swapped to an imported model (shooter, dasher, exploder,
	# support, displacer) still carry this placeholder in their .tscn and
	# reference `mesh` directly for their own emission-color effects; a
	# subclass's _build_visual() below can still override this (see sniper).
	mesh = get_node_or_null("MeshInstance3D") as MeshInstance3D
	_build_visual()


## call at the very top of every subclass's _physics_process(). returns true
## if the enemy fell out of the world and was killed — the caller should
## return immediately without doing anything else this frame.
func _check_fall_death() -> bool:
	if global_position.y < FALL_DEATH_Y:
		if not is_dying and health and health.is_alive():
			health._apply_damage(health.max_health * 10)
		return true
	return false


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta


func _find_target() -> void:
	if _player_manager:
		target = _player_manager.get_nearest_player(global_position)
	else:
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0] as CharacterBody3D


## probes the desired direction and, if something's in the way, a widening
## fan of angles left/right of it — returns the first clear direction found.
## melee enemies used to walk straight at the target and permanently get
## stuck against room obstacles (a pillar was enough to fully neutralize
## them); this is a lightweight steer-around fallback, not real pathfinding
## (no NavigationAgent3D/navmesh — see REMAINING.md for why that's a bigger,
## harder-to-verify change).
func _steer_around_obstacles(desired_direction: Vector3) -> Vector3:
	var flat_dir: Vector3 = desired_direction
	flat_dir.y = 0
	if flat_dir.length() < 0.01:
		return flat_dir
	flat_dir = flat_dir.normalized()

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = global_position + Vector3(0, STEER_PROBE_HEIGHT, 0)

	for angle: float in STEER_ANGLES:
		var probe_dir: Vector3 = flat_dir.rotated(Vector3.UP, angle)
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			from, from + probe_dir * STEER_PROBE_DISTANCE
		)
		query.collision_mask = 1  # obstacles/terrain only, not other entities
		query.exclude = [get_rid()]
		var result: Dictionary = space_state.intersect_ray(query)
		if result.is_empty():
			return probe_dir

	# every probe angle blocked (fully boxed in) — fall back to the direct
	# line; move_and_slide will still slide along whatever it hits.
	return flat_dir


## keeps the enemy inside the arena disc. call before the final
## move_and_slide() in a subclass's _physics_process().
func _clamp_to_arena() -> void:
	var flat_pos: Vector2 = Vector2(global_position.x, global_position.z)
	if flat_pos.length() > ARENA_RADIUS:
		flat_pos = flat_pos.normalized() * ARENA_RADIUS
		global_position.x = flat_pos.x
		global_position.z = flat_pos.y


func _on_damaged(_amount: int, _current: int) -> void:
	_flash_hit()


func _on_died() -> void:
	is_dying = true
	_play_death()


## override in a subclass to build its unique procedural mesh or load a model.
func _build_visual() -> void:
	pass


## loads an imported model (e.g. a .glb) and adds it as a child. returns the
## instantiated root so a subclass can pull named parts out of it via
## _find_mesh() — glTF import preserves each part's original mesh name as its
## Godot node name.
func _load_visual_model(path: String) -> Node3D:
	var scene: PackedScene = load(path) as PackedScene
	if not scene:
		return null
	var instance: Node3D = scene.instantiate() as Node3D
	add_child(instance)
	return instance


func _find_mesh(root: Node, mesh_name: String) -> MeshInstance3D:
	if not root:
		return null
	return root.find_child(mesh_name, true, false) as MeshInstance3D


## makes a mesh's material a per-instance override so mutating it later
## (e.g. a muzzle-flash pulse) never bleeds into the shared imported
## resource every other instance of this model reuses.
func _make_material_unique(mi: MeshInstance3D) -> void:
	if not mi:
		return
	var mat: Material = mi.get_active_material(0)
	if mat:
		mi.set_surface_override_material(0, mat.duplicate())


func _all_meshes() -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	_collect_meshes(self, found)
	return found


func _collect_meshes(node: Node, found: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			found.append(child)
		_collect_meshes(child, found)


func _make_box(size: Vector3, offset: Vector3, color: Color, emission: Color = Color.BLACK) -> MeshInstance3D:
	var m: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	m.mesh = box
	m.position = offset
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	if emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = 1.5
	m.material_override = mat
	return m


func _flash_hit() -> void:
	# flashes every mesh part, not just one — a single-box enemy only has one
	# part anyway, but a multi-part model (e.g. an imported .glb) needs the
	# whole body to read as "hit," not one random piece of it.
	for mi: MeshInstance3D in _all_meshes():
		var mat: Material = mi.get_surface_override_material(0)
		if not mat:
			mat = mi.get_active_material(0)
		if not mat is StandardMaterial3D:
			continue

		# duplicate so this flash never touches a material shared with anything else
		var unique_mat: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
		mi.set_surface_override_material(0, unique_mat)

		var original_color: Color = unique_mat.albedo_color
		unique_mat.albedo_color = Color.WHITE

		var tween: Tween = create_tween()
		tween.tween_property(unique_mat, "albedo_color", original_color, 0.1)


## default death animation. override in a subclass for different tuning
## (see tank_controller.gd for an example).
func _play_death() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3(1.3, 0.1, 1.3), 0.15)
	for mi: MeshInstance3D in _all_meshes():
		tween.tween_property(mi, "transparency", 1.0, 0.2)
	tween.chain().tween_callback(queue_free)


func _is_local_authority() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return is_multiplayer_authority()
