class_name GameFeel
extends Node

# manages juice effects: hit pause, kill slow-mo, boss moments.
# all effects are brief and respect gameplay flow.
# priority system: boss effects override combat effects.

var _time_scale_tween: Tween
var _is_restoring: bool = false
var _effect_priority: int = 0  # higher priority effects override lower ones

const PRIORITY_HIT: int = 1
const PRIORITY_KILL: int = 2
const PRIORITY_BOSS: int = 10


func hit_pause(duration: float = 0.03) -> void:
	if _effect_priority >= PRIORITY_BOSS:
		return
	_effect_priority = PRIORITY_HIT
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	if _effect_priority <= PRIORITY_HIT and not _is_restoring:
		Engine.time_scale = 1.0
		_effect_priority = 0


func kill_freeze(duration: float = 0.04) -> void:
	if _effect_priority >= PRIORITY_BOSS:
		return
	_effect_priority = PRIORITY_KILL
	Engine.time_scale = 0.02
	await get_tree().create_timer(duration, true, false, true).timeout
	if _effect_priority <= PRIORITY_KILL and not _is_restoring:
		Engine.time_scale = 1.0
		_effect_priority = 0


func boss_phase_slowmo(duration: float = 0.6) -> void:
	_effect_priority = PRIORITY_BOSS
	_is_restoring = true
	if _time_scale_tween and _time_scale_tween.is_valid():
		_time_scale_tween.kill()

	Engine.time_scale = 0.15
	_time_scale_tween = create_tween().set_ignore_time_scale(true)
	_time_scale_tween.tween_interval(duration)
	_time_scale_tween.tween_property(Engine, "time_scale", 1.0, 0.3).set_ease(Tween.EASE_IN)
	_time_scale_tween.tween_callback(func():
		_is_restoring = false
		_effect_priority = 0
	)


func boss_death_slowmo() -> void:
	_effect_priority = PRIORITY_BOSS
	_is_restoring = true
	if _time_scale_tween and _time_scale_tween.is_valid():
		_time_scale_tween.kill()

	Engine.time_scale = 0.1
	_time_scale_tween = create_tween().set_ignore_time_scale(true)
	_time_scale_tween.tween_interval(0.8)
	_time_scale_tween.tween_property(Engine, "time_scale", 1.0, 0.4).set_ease(Tween.EASE_IN)
	_time_scale_tween.tween_callback(func():
		_is_restoring = false
		_effect_priority = 0
	)


func camera_punch(camera: Camera3D, intensity: float) -> void:
	if camera and camera.has_method("add_shake"):
		camera.add_shake(intensity)


func reset() -> void:
	_is_restoring = false
	_effect_priority = 0
	Engine.time_scale = 1.0
	if _time_scale_tween and _time_scale_tween.is_valid():
		_time_scale_tween.kill()
		_time_scale_tween = null
