extends Camera3D

@export var base_fov := 90.0
@export var max_fov := 110.0
@export var fov_lerp_speed := 8.0
@export var shake_decay := 8.0

var target_fov := 90.0
var shake_intensity := 0.0
var shake_offset := Vector3.ZERO


func _process(delta: float) -> void:
	_update_fov(delta)
	_update_shake(delta)


func add_shake(intensity: float) -> void:
	shake_intensity = max(shake_intensity, intensity)


func _update_fov(delta: float) -> void:
	var player := get_parent().get_parent() as CharacterBody3D
	if not player:
		return

	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var speed_ratio := clamp(speed / 20.0, 0.0, 1.0)
	target_fov = lerp(base_fov, max_fov, speed_ratio)
	fov = lerp(fov, target_fov, fov_lerp_speed * delta)


func _update_shake(delta: float) -> void:
	if shake_intensity > 0.01:
		shake_offset = Vector3(
			randf_range(-1.0, 1.0) * shake_intensity,
			randf_range(-1.0, 1.0) * shake_intensity,
			0
		)
		position = shake_offset * 0.01
		shake_intensity = lerp(shake_intensity, 0.0, shake_decay * delta)
	else:
		shake_intensity = 0.0
		position = Vector3.ZERO
