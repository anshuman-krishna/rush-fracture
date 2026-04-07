extends CharacterBody3D

# support enemy that buffs nearby allies. stays behind other enemies.
# periodically heals or speeds up nearby enemies. priority target.

@export var move_speed: float = 3.5
@export var detection_range: float = 30.0
@export var preferred_range: float = 16.0
@export var attack_damage: int = 5
@export var attack_cooldown: float = 2.5
@export var buff_radius: float = 8.0
@export var buff_cooldown: float = 4.0
@export var heal_amount: int = 15

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var target: CharacterBody3D
var attack_timer: float = 0.0
var buff_timer: float = 2.0
var is_dying: bool = false
var is_elite: bool = false
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
	if is_dying:
		return

	if not _is_local_authority():
		return

	_apply_gravity(delta)
	attack_timer = max(0, attack_timer - delta)
	buff_timer -= delta

	if not target:
		_find_target()
		move_and_slide()
		return

	var distance: float = global_position.distance_to(target.global_position)
	if distance > detection_range:
		move_and_slide()
		return

	_maintain_distance(delta, distance)
	_face_target()

	# weak ranged attack
	if distance < detection_range and attack_timer <= 0:
		_fire_at_target()

	# buff allies periodically
	if buff_timer <= 0:
		_buff_allies()
		buff_timer = buff_cooldown
		if is_elite:
			buff_timer *= 0.7

	move_and_slide()


func _maintain_distance(delta: float, distance: float) -> void:
	# stay behind other enemies — keep far from player
	var direction: Vector3 = (target.global_position - global_position).normalized()
	direction.y = 0

	if distance < preferred_range * 0.5:
		# too close — flee
		velocity.x = move_toward(velocity.x, -direction.x * move_speed * 1.3, 15.0 * delta)
		velocity.z = move_toward(velocity.z, -direction.z * move_speed * 1.3, 15.0 * delta)
	elif distance > preferred_range * 1.4:
		# too far — approach to stay in buff range of allies
		velocity.x = move_toward(velocity.x, direction.x * move_speed, 10.0 * delta)
		velocity.z = move_toward(velocity.z, direction.z * move_speed, 10.0 * delta)
	else:
		# orbit at safe distance
		var strafe: Vector3 = direction.cross(Vector3.UP)
		velocity.x = move_toward(velocity.x, strafe.x * move_speed * 0.5, 8.0 * delta)
		velocity.z = move_toward(velocity.z, strafe.z * move_speed * 0.5, 8.0 * delta)


func _fire_at_target() -> void:
	attack_timer = attack_cooldown
	if target and target.has_method("take_damage"):
		target.take_damage(attack_damage)


func _buff_allies() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var buffed_count: int = 0

	for enemy in enemies:
		if enemy == self or not enemy is Node3D:
			continue
		if enemy.global_position.distance_to(global_position) > buff_radius:
			continue

		# heal allies
		var h: HealthComponent = enemy.get_node_or_null("HealthComponent") as HealthComponent
		if h and h.is_alive() and h.current_health < h.max_health:
			var amount: int = heal_amount
			if is_elite:
				amount = int(amount * 1.5)
			h.current_health = mini(h.current_health + amount, h.max_health)
			buffed_count += 1

		# speed boost for 3 seconds
		if "move_speed" in enemy and not enemy.get_meta("support_buffed", false):
			var base_speed: float = enemy.move_speed
			enemy.move_speed *= 1.25
			enemy.set_meta("support_buffed", true)
			# revert after duration
			get_tree().create_timer(3.0).timeout.connect(func():
				if is_instance_valid(enemy) and "move_speed" in enemy:
					enemy.move_speed = base_speed
					enemy.set_meta("support_buffed", false)
			)

	if buffed_count > 0:
		_show_buff_visual()


func _show_buff_visual() -> void:
	# pulse ring showing buff area
	var ring: MeshInstance3D = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = buff_radius
	disc.bottom_radius = buff_radius
	disc.height = 0.08
	ring.mesh = disc

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.9, 0.3, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.8, 0.2)
	mat.emission_energy_multiplier = 1.5
	ring.material_override = mat

	ring.global_position = Vector3(global_position.x, 0.1, global_position.z)
	get_tree().root.add_child(ring)

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tween.tween_callback(ring.queue_free)


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
	# healing staff — tall green rod with orb on top
	var staff: MeshInstance3D = _make_box(Vector3(0.05, 0.9, 0.05), Vector3(0.3, 0.9, 0), Color(0.1, 0.45, 0.15))
	add_child(staff)
	var staff_orb: MeshInstance3D = _make_box(Vector3(0.12, 0.12, 0.12), Vector3(0.3, 1.45, 0), Color(0.2, 1.0, 0.3), Color(0.15, 0.9, 0.25))
	add_child(staff_orb)
	# staff cross piece
	var cross: MeshInstance3D = _make_box(Vector3(0.2, 0.04, 0.04), Vector3(0.3, 1.3, 0), Color(0.12, 0.5, 0.18), Color(0.1, 0.7, 0.15))
	add_child(cross)
	# robes/skirt at bottom
	var robe: MeshInstance3D = _make_box(Vector3(0.45, 0.35, 0.45), Vector3(0, 0.2, 0), Color(0.1, 0.4, 0.15))
	add_child(robe)
	# green visor
	var visor: MeshInstance3D = _make_box(Vector3(0.22, 0.04, 0.06), Vector3(0, 1.1, -0.22), Color(0.2, 0.9, 0.3), Color(0.15, 0.8, 0.2))
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
