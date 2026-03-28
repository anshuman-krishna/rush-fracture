extends CharacterBody3D

@export var move_speed := 2.5
@export var detection_range := 18.0
@export var attack_range := 2.5
@export var attack_damage := 25
@export var attack_cooldown := 2.5

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var target: CharacterBody3D
var attack_timer := 0.0
var is_dying := false

@onready var health: HealthComponent = $HealthComponent
@onready var mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	add_to_group("enemies")


func _physics_process(delta: float) -> void:
	if is_dying:
		return

	_apply_gravity(delta)
	attack_timer = max(0, attack_timer - delta)

	if not target:
		_find_target()
		move_and_slide()
		return

	var distance := global_position.distance_to(target.global_position)
	if distance > detection_range:
		move_and_slide()
		return

	if distance > attack_range:
		_chase(delta)
	else:
		_try_attack()

	_face_target()
	move_and_slide()


func _chase(delta: float) -> void:
	var direction := (target.global_position - global_position).normalized()
	direction.y = 0
	velocity.x = move_toward(velocity.x, direction.x * move_speed, 12.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed, 12.0 * delta)


func _try_attack() -> void:
	velocity.x = move_toward(velocity.x, 0, 8.0)
	velocity.z = move_toward(velocity.z, 0, 8.0)

	if attack_timer <= 0 and target:
		if target.has_method("take_damage"):
			target.take_damage(attack_damage)
		attack_timer = attack_cooldown


func _face_target() -> void:
	if not target:
		return
	var look_pos := target.global_position
	look_pos.y = global_position.y
	if global_position.distance_to(look_pos) > 0.1:
		look_at(look_pos)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta


func _find_target() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0] as CharacterBody3D


func _on_damaged(_amount: int, _current: int) -> void:
	_flash_hit()


func _on_died() -> void:
	is_dying = true
	_play_death()


func _flash_hit() -> void:
	if not mesh:
		return
	var mat := mesh.get_surface_override_material(0)
	if mat is StandardMaterial3D:
		var original_color: Color = mat.albedo_color
		mat.albedo_color = Color.WHITE
		var tween := create_tween()
		tween.tween_property(mat, "albedo_color", original_color, 0.1)


func _play_death() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3(1.5, 0.1, 1.5), 0.2)
	tween.tween_property(mesh, "transparency", 1.0, 0.25)
	tween.chain().tween_callback(queue_free)
