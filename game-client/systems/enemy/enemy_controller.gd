extends CharacterBody3D

@export var move_speed: float = 5.0
@export var detection_range: float = 60.0
@export var attack_range: float = 2.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.5

const ARENA_RADIUS: float = 33.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var target: CharacterBody3D
var attack_timer: float = 0.0
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


func _physics_process(delta: float) -> void:
	# kill zone — enemy fell off the map
	if global_position.y < -20.0:
		if not is_dying and health and health.is_alive():
			health._apply_damage(health.max_health * 10)
		return

	if is_dying:
		return

	# only host runs enemy ai in multiplayer
	if not _is_local_authority():
		return

	_apply_gravity(delta)
	_update_attack_timer(delta)

	if not target or not is_instance_valid(target):
		target = null
		_find_target()
		move_and_slide()
		return

	var distance: float = global_position.distance_to(target.global_position)

	if distance > detection_range:
		move_and_slide()
		return

	if distance > attack_range:
		_chase(delta)
	else:
		_try_attack()

	_clamp_to_arena()
	move_and_slide()


func _chase(delta: float) -> void:
	var direction: Vector3 = (target.global_position - global_position).normalized()
	direction.y = 0

	velocity.x = move_toward(velocity.x, direction.x * move_speed, 20.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed, 20.0 * delta)

	# face movement direction
	if direction.length() > 0.1:
		var look_target: Vector3 = global_position + direction
		look_target.y = global_position.y
		look_at(look_target)


func _try_attack() -> void:
	velocity.x = move_toward(velocity.x, 0, 10.0)
	velocity.z = move_toward(velocity.z, 0, 10.0)

	if attack_timer <= 0 and target:
		if target.has_method("take_damage"):
			target.take_damage(attack_damage)
		attack_timer = attack_cooldown


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta


func _update_attack_timer(delta: float) -> void:
	attack_timer = max(0, attack_timer - delta)


func _find_target() -> void:
	if _player_manager:
		target = _player_manager.get_nearest_player(global_position)
	else:
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0] as CharacterBody3D


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


func _build_visual() -> void:
	# chaser: lean body with clawed arms — melee indicator
	var arm_l: MeshInstance3D = _make_box(Vector3(0.12, 0.5, 0.12), Vector3(-0.35, 0.6, 0), Color(0.7, 0.1, 0.05))
	var arm_r: MeshInstance3D = _make_box(Vector3(0.12, 0.5, 0.12), Vector3(0.35, 0.6, 0), Color(0.7, 0.1, 0.05))
	add_child(arm_l)
	add_child(arm_r)
	# claws
	var claw_l: MeshInstance3D = _make_box(Vector3(0.08, 0.2, 0.06), Vector3(-0.35, 0.3, -0.08), Color(1.0, 0.3, 0.1), Color(1.0, 0.2, 0.0))
	var claw_r: MeshInstance3D = _make_box(Vector3(0.08, 0.2, 0.06), Vector3(0.35, 0.3, -0.08), Color(1.0, 0.3, 0.1), Color(1.0, 0.2, 0.0))
	add_child(claw_l)
	add_child(claw_r)
	# eye visor
	var visor: MeshInstance3D = _make_box(Vector3(0.3, 0.06, 0.08), Vector3(0, 1.2, -0.25), Color(1.0, 0.15, 0.0), Color(1.0, 0.1, 0.0))
	add_child(visor)


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
	if mat is StandardMaterial3D:
		var original_color: Color = mat.albedo_color
		mat.albedo_color = Color.WHITE
		var tween: Tween = create_tween()
		tween.tween_property(mat, "albedo_color", original_color, 0.1)


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
