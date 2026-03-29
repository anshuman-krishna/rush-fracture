class_name GameFeel
extends Node

# manages juice effects: hit pause, kill slow-mo, boss moments.
# all effects are brief and respect gameplay flow.

var _time_scale_tween: Tween
var _is_restoring: bool = false


func hit_pause(duration: float = 0.03) -> void:
	# micro-freeze on hit for impact
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	if not _is_restoring:
		Engine.time_scale = 1.0


func kill_freeze(duration: float = 0.04) -> void:
	# slightly longer pause on kill
	Engine.time_scale = 0.02
	await get_tree().create_timer(duration, true, false, true).timeout
	if not _is_restoring:
		Engine.time_scale = 1.0


func boss_phase_slowmo(duration: float = 0.6) -> void:
	# dramatic slow-motion for boss phase transitions
	_is_restoring = true
	if _time_scale_tween:
		_time_scale_tween.kill()

	Engine.time_scale = 0.15
	_time_scale_tween = create_tween()
	_time_scale_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_time_scale_tween.tween_interval(duration)
	_time_scale_tween.tween_property(Engine, "time_scale", 1.0, 0.3)
	_time_scale_tween.tween_callback(func(): _is_restoring = false)


func boss_death_slowmo() -> void:
	_is_restoring = true
	if _time_scale_tween:
		_time_scale_tween.kill()

	Engine.time_scale = 0.1
	_time_scale_tween = create_tween()
	_time_scale_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_time_scale_tween.tween_interval(0.8)
	_time_scale_tween.tween_property(Engine, "time_scale", 1.0, 0.4)
	_time_scale_tween.tween_callback(func(): _is_restoring = false)


func camera_punch(camera: Camera3D, intensity: float) -> void:
	if camera and camera.has_method("add_shake"):
		camera.add_shake(intensity)


func reset() -> void:
	_is_restoring = false
	Engine.time_scale = 1.0
	if _time_scale_tween:
		_time_scale_tween.kill()
		_time_scale_tween = null
