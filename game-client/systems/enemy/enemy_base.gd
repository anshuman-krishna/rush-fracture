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

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var target: CharacterBody3D
var is_dying: bool = false
var _player_manager: PlayerManager

@onready var health: HealthComponent = $HealthComponent
@onready var mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	add_to_group("enemies")
	_player_manager = get_node_or_null("/root/Main/PlayerManager") as PlayerManager
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


## override in a subclass to build its unique procedural mesh.
func _build_visual() -> void:
	pass


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
	if not mesh:
		return

	var mat: Material = mesh.get_surface_override_material(0)
	if not mat:
		mat = mesh.get_active_material(0)
	if not mat is StandardMaterial3D:
		return

	# duplicate so this flash never touches a material shared with anything else
	var unique_mat: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
	mesh.set_surface_override_material(0, unique_mat)

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
	tween.tween_property(mesh, "transparency", 1.0, 0.2)
	tween.chain().tween_callback(queue_free)


func _is_local_authority() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return is_multiplayer_authority()
