extends Camera3D

@export var base_fov: float = 90.0
@export var max_fov: float = 110.0
@export var fov_lerp_speed: float = 8.0
@export var shake_decay: float = 8.0

var target_fov: float = 90.0
var shake_intensity: float = 0.0
var shake_offset: Vector3 = Vector3.ZERO
var recoil_offset: float = 0.0
var recoil_recovery_speed: float = 12.0


func _process(delta: float) -> void:
	_update_fov(delta)
	_update_shake(delta)
	_update_recoil(delta)


func add_shake(intensity: float) -> void:
	shake_intensity = max(shake_intensity, intensity)


func add_recoil(amount: float) -> void:
	recoil_offset += amount


func _update_fov(delta: float) -> void:
	var player: CharacterBody3D = get_parent().get_parent() as CharacterBody3D
	if not player:
		return

	var speed: float = player.velocity.length()
	var speed_ratio: float = clamp(speed / 20.0, 0.0, 1.0)
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


func _update_recoil(delta: float) -> void:
	if abs(recoil_offset) > 0.001:
		rotation.x = recoil_offset * 0.01
		recoil_offset = lerp(recoil_offset, 0.0, recoil_recovery_speed * delta)
	else:
		recoil_offset = 0.0
