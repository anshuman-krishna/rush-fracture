extends CharacterBody3D

# teleporting enemy that blinks around the arena.
# appears behind the player, attacks, then warps away.
# disorienting and hard to track.

@export var move_speed: float = 4.0
@export var detection_range: float = 30.0
@export var attack_damage: int = 14
@export var attack_cooldown: float = 3.0
@export var warp_cooldown: float = 4.0
@export var warp_range: float = 8.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var target: CharacterBody3D
var attack_timer: float = 0.0
var warp_timer: float = 2.0
var is_dying: bool = false
var is_elite: bool = false
var _player_manager: PlayerManager
var _warping: bool = false
var _warp_phase_timer: float = 0.0

@onready var health: HealthComponent = $HealthComponent
@onready var mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	add_to_group("enemies")
	_player_manager = get_node_or_null("/root/Main/PlayerManager") as PlayerManager
	_build_visual()


func _physics_process(delta: float) -> void:
	if is_dying:
		return

	if not _is_local_authority():
		return

	_apply_gravity(delta)
	attack_timer = max(0, attack_timer - delta)
	warp_timer -= delta

	if _warping:
		_handle_warp(delta)
		move_and_slide()
		return

	if not target:
		_find_target()
		move_and_slide()
		return

	var distance: float = global_position.distance_to(target.global_position)
	if distance > detection_range:
		move_and_slide()
		return

	# warp behind player when cooldown ready
	if warp_timer <= 0 and distance > 4.0:
		_start_warp()
		move_and_slide()
		return

	# in melee range — attack
	if distance < 3.0 and attack_timer <= 0:
		_attack()
	elif distance > 3.0:
		_chase(delta)

	_face_target()
	move_and_slide()


func _start_warp() -> void:
	_warping = true
	_warp_phase_timer = 0.3
	_show_warp_out()


func _handle_warp(delta: float) -> void:
	_warp_phase_timer -= delta
	if _warp_phase_timer <= 0:
		_warping = false
		_teleport_behind_target()
		_show_warp_in()
		warp_timer = warp_cooldown
		if is_elite:
			warp_timer *= 0.6


func _teleport_behind_target() -> void:
	if not target:
		return

	# calculate position behind the player's facing direction
	var player_forward: Vector3 = -target.global_transform.basis.z.normalized()
	player_forward.y = 0
	var behind_pos: Vector3 = target.global_position - player_forward * warp_range

	# add slight randomness
	behind_pos.x += (randf() - 0.5) * 3.0
	behind_pos.z += (randf() - 0.5) * 3.0
	behind_pos.y = 1.0

	global_position = behind_pos


func _attack() -> void:
	attack_timer = attack_cooldown
	if not target:
		return

	var damage: int = attack_damage
	if is_elite:
		damage = int(damage * 1.4)

	if target.has_method("take_damage"):
		target.take_damage(damage)

	# warp away after attacking
	if warp_timer <= 1.0:
		warp_timer = 0.0


func _chase(delta: float) -> void:
	var direction: Vector3 = (target.global_position - global_position).normalized()
	direction.y = 0
	velocity.x = move_toward(velocity.x, direction.x * move_speed, 20.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed, 20.0 * delta)


func _show_warp_out() -> void:
	# fade out + scale down
	if not mesh:
		return
	var mat: Material = mesh.get_surface_override_material(0)
	if mat is StandardMaterial3D:
		mat.emission_energy_multiplier = 4.0

	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.25)

	_spawn_warp_particles(global_position)


func _show_warp_in() -> void:
	# scale back up with flash
	scale = Vector3(0.1, 0.1, 0.1)

	var target_scale: Vector3 = Vector3(1.0, 1.0, 1.0)
	if is_elite:
		target_scale = Vector3(1.5, 1.5, 1.5)

	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", target_scale, 0.15)

	if mesh:
		var mat: Material = mesh.get_surface_override_material(0)
		if mat is StandardMaterial3D:
			mat.emission_energy_multiplier = 5.0
			var fade_tween: Tween = create_tween()
			fade_tween.tween_property(mat, "emission_energy_multiplier", 0.6, 0.3)

	_spawn_warp_particles(global_position)


func _spawn_warp_particles(pos: Vector3) -> void:
	var indicator: MeshInstance3D = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 1.5
	disc.bottom_radius = 1.5
	disc.height = 0.08
	indicator.mesh = disc

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.0, 1.0, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.0, 0.9)
	mat.emission_energy_multiplier = 2.5
	indicator.material_override = mat

	indicator.global_position = Vector3(pos.x, 0.1, pos.z)
	get_tree().root.add_child(indicator)

	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(indicator, "scale", Vector3(2.0, 1.0, 2.0), 0.4)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.chain().tween_callback(indicator.queue_free)


func _face_target() -> void:
	if not target:
		return
	var look_pos: Vector3 = target.global_position
	look_pos.y = global_position.y
	if global_position.distance_to(look_pos) > 0.1:
		look_at(look_pos)


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


func _on_damaged(_amount: int, _current: int) -> void:
	_flash_hit()


func _on_died() -> void:
	is_dying = true
	_play_death()


func _build_visual() -> void:
	# warp blades — melee daggers on both sides
	var blade_l: MeshInstance3D = _make_box(Vector3(0.04, 0.06, 0.35), Vector3(-0.4, 0.7, -0.2), Color(0.7, 0.2, 1.0), Color(0.6, 0.0, 0.9))
	var blade_r: MeshInstance3D = _make_box(Vector3(0.04, 0.06, 0.35), Vector3(0.4, 0.7, -0.2), Color(0.7, 0.2, 1.0), Color(0.6, 0.0, 0.9))
	add_child(blade_l)
	add_child(blade_r)
	# floating orbs around body — warp energy
	for i in 3:
		var angle: float = (float(i) / 3.0) * TAU
		var orb: MeshInstance3D = _make_box(
			Vector3(0.1, 0.1, 0.1),
			Vector3(cos(angle) * 0.55, 0.9, sin(angle) * 0.55),
			Color(0.5, 0.1, 0.8), Color(0.6, 0.0, 1.0)
		)
		add_child(orb)
	# crown spikes
	var crown: MeshInstance3D = _make_box(Vector3(0.3, 0.15, 0.3), Vector3(0, 1.15, 0), Color(0.4, 0.08, 0.6), Color(0.5, 0.0, 0.8))
	add_child(crown)


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
