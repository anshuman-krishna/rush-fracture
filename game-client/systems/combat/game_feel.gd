class_name GameFeel
extends Node

# owns Engine.time_scale. every slow-motion effect in the game (hit pause,
# kill freeze, upgrade time slows, boss moments, death) asks for a scale here
# instead of writing the engine value itself; the highest-priority live
# request wins and the scale always returns to 1.0 when the last one expires.
# before this, each effect set and reset the value on its own timer and they
# cancelled or outlasted one another.

const PRIORITY_HIT: int = 1
const PRIORITY_KILL: int = 2
const PRIORITY_EFFECT: int = 5
const PRIORITY_DEATH: int = 8
const PRIORITY_BOSS: int = 10

## 0 disables hit-stop entirely, 1 is full strength (settings)
var freeze_strength: float = 1.0

var _requests: Dictionary = {}
var _current: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if _requests.is_empty():
		if _current != 1.0:
			_apply(1.0)
		return

	# delta arrives already multiplied by the time scale; undo that so every
	# request lasts its stated duration in real (unscaled) time
	var real_delta: float = delta / maxf(Engine.time_scale, 0.01)
	var best_priority: int = -1
	var best_scale: float = 1.0
	for key: Variant in _requests.keys():
		var r: Dictionary = _requests[key]
		r.remaining -= real_delta
		if r.remaining <= 0.0:
			_requests.erase(key)
			continue
		var s: float = r.scale
		if r.fade > 0.0 and r.remaining < r.fade:
			s = lerpf(1.0, r.scale, r.remaining / r.fade)
		if r.priority > best_priority or (r.priority == best_priority and s < best_scale):
			best_priority = r.priority
			best_scale = s
	_apply(best_scale if best_priority >= 0 else 1.0)


## asks for a time scale for `duration` real seconds. a later request with the
## same key replaces the earlier one. `fade` eases back to 1.0 over the last
## `fade` seconds.
func request(key: StringName, scale: float, duration: float, priority: int = PRIORITY_EFFECT, fade: float = 0.0) -> void:
	if duration <= 0.0:
		return
	_requests[key] = {"scale": clampf(scale, 0.01, 1.0), "remaining": duration, "priority": priority, "fade": fade}


func cancel(key: StringName) -> void:
	_requests.erase(key)


func hit_pause(duration: float = 0.03) -> void:
	if freeze_strength <= 0.0:
		return
	request(&"hit", lerpf(1.0, 0.05, freeze_strength), duration, PRIORITY_HIT)


func kill_freeze(duration: float = 0.045) -> void:
	if freeze_strength <= 0.0:
		return
	request(&"kill", lerpf(1.0, 0.04, freeze_strength), duration, PRIORITY_KILL)


func boss_phase_slowmo(duration: float = 0.6) -> void:
	request(&"boss", 0.15, duration + 0.3, PRIORITY_BOSS, 0.3)


func boss_death_slowmo() -> void:
	request(&"boss", 0.1, 1.2, PRIORITY_BOSS, 0.4)


func player_death_slowmo() -> void:
	request(&"death", 0.3, 0.5, PRIORITY_DEATH, 0.1)


func camera_punch(_camera: Camera3D, intensity: float) -> void:
	Game.shake(intensity)


func is_slowed() -> bool:
	return _current < 0.999


func reset() -> void:
	_requests.clear()
	_apply(1.0)


func _apply(scale: float) -> void:
	if is_equal_approx(scale, _current) and is_equal_approx(Engine.time_scale, scale):
		return
	_current = scale
	Engine.time_scale = scale
