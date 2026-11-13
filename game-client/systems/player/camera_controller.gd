extends Camera3D

# first-person camera feel: speed-driven fov, strafe and slide roll, landing
# dip, recoil, and shake. all of it is offset on top of the head node, so
# aim (the head's rotation) is never touched by any effect here.

@export var base_fov: float = 90.0
@export var max_fov_gain: float = 18.0
@export var fov_lerp_speed: float = 8.0
@export var shake_decay: float = 9.0
@export var max_shake: float = 16.0

## multiplies every shake (settings; 0 turns shake off)
var shake_scale: float = 1.0
## extra fov added by gameplay effects (charging a shot zooms in, etc.)
var fov_offset: float = 0.0

var shake_intensity: float = 0.0
var _recoil_pitch: float = 0.0
var _recoil_yaw: float = 0.0
var _dash_fov_boost: float = 0.0
var _roll: float = 0.0
var _dip: float = 0.0
var _dip_velocity: float = 0.0
var _head_y: float = 0.7
var _player: CharacterBody3D
var _head: Node3D


func _ready() -> void:
	_head = get_parent() as Node3D
	if _head:
		_player = _head.get_parent() as CharacterBody3D
		_head_y = _head.position.y
	if _player and _player.has_signal("landed"):
		_player.landed.connect(_on_landed)
	fov = base_fov


func apply_settings(settings: GameSettings) -> void:
	base_fov = settings.fov
	shake_scale = settings.screen_shake


func add_shake(intensity: float) -> void:
	shake_intensity = minf(maxf(shake_intensity, intensity * shake_scale), max_shake)


## kicks the view up (and a little sideways). it settles back on its own.
func add_recoil(pitch_amount: float, yaw_amount: float = 0.0) -> void:
	_recoil_pitch = minf(_recoil_pitch + pitch_amount, 6.0)
	_recoil_yaw = clampf(_recoil_yaw + yaw_amount, -3.0, 3.0)


func dash_kick() -> void:
	_dash_fov_boost = 12.0
	add_shake(2.5)


func _process(delta: float) -> void:
	if not current or not is_instance_valid(_player):
		return

	var hvel: Vector3 = Vector3(_player.velocity.x, 0, _player.velocity.z)
	var speed: float = hvel.length()

	# fov widens with speed; reads the stat so effects can narrow or widen it
	var bias: float = _player.stats.value(&"fov_bias") if "stats" in _player else 0.0
	var speed_ratio: float = clampf((speed - 8.0) / 22.0, 0.0, 1.0)
	_dash_fov_boost = lerpf(_dash_fov_boost, 0.0, clampf(9.0 * delta, 0.0, 1.0))
	var target_fov: float = clampf(base_fov + max_fov_gain * speed_ratio + _dash_fov_boost + fov_offset + bias, 40.0, 140.0)
	fov = lerpf(fov, target_fov, clampf(fov_lerp_speed * delta, 0.0, 1.0))

	# roll into strafes, and harder into slides
	var side: float = hvel.dot(_player.global_transform.basis.x) / 16.0
	var target_roll: float = -clampf(side, -1.0, 1.0) * deg_to_rad(2.2)
	var sliding: bool = _player.get("is_sliding") == true
	if sliding:
		target_roll += deg_to_rad(-3.5)
	_roll = lerpf(_roll, target_roll, clampf(8.0 * delta, 0.0, 1.0))

	# head height follows the slide crouch
	if _head:
		var target_y: float = 0.05 if sliding else _head_y
		_head.position.y = lerpf(_head.position.y, target_y, clampf(14.0 * delta, 0.0, 1.0))

	# landing dip: a damped spring
	_dip_velocity += (-_dip * 120.0 - _dip_velocity * 14.0) * delta
	_dip += _dip_velocity * delta

	_recoil_pitch = lerpf(_recoil_pitch, 0.0, clampf(11.0 * delta, 0.0, 1.0))
	_recoil_yaw = lerpf(_recoil_yaw, 0.0, clampf(11.0 * delta, 0.0, 1.0))

	var shake: Vector3 = Vector3.ZERO
	if shake_intensity > 0.01:
		shake = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0) * shake_intensity * 0.01
		shake_intensity = lerpf(shake_intensity, 0.0, clampf(shake_decay * delta, 0.0, 1.0))
	else:
		shake_intensity = 0.0

	position = Vector3(shake.x, shake.y + _dip, 0)
	rotation = Vector3(deg_to_rad(_recoil_pitch) + shake.y * 0.4, deg_to_rad(_recoil_yaw) + shake.x * 0.4, _roll)


func _on_landed(fall_speed: float) -> void:
	if fall_speed < 6.0:
		return
	_dip_velocity -= clampf(fall_speed * 0.12, 0.4, 3.2)
