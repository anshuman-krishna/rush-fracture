class_name PulseRifle
extends BaseWeapon

# "grafted carbine" — accurate automatic hitscan. the reliable one: fine at
# any range, and the best at punishing weak points.

const MAX_BLOOM: float = 0.022

var _bloom: float = 0.0
var _burst_left: int = 0
var _burst_timer: float = 0.0


func _configure() -> void:
	weapon_id = &"pulse_rifle"
	display_name = "grafted carbine"
	model_path = "res://assets/models/grafted-brood-pulse_rifle.glb"
	muzzle_fallback = Vector3(0, 0.115, -0.389)
	grip_lift = 0.087
	base_damage = 22.0
	fire_interval = 0.115
	weapon_range = 110.0
	weak_mult = 1.8
	recoil_pitch = 0.42
	shake_on_fire = 0.8
	tracer_color = Color(1.0, 0.72, 0.25)
	fire_sound = &"pulse_fire"


func reset_state() -> void:
	super.reset_state()
	_bloom = 0.0
	_burst_left = 0


func _tick(delta: float, held: bool, _pressed: bool, _released: bool) -> void:
	_bloom = maxf(0.0, _bloom - delta * 0.06)

	if _burst_left > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_burst_left -= 1
			_burst_timer = 0.045
			_shoot(_damage() * 0.78)
		return

	if not held or not _can_fire():
		return

	if has_flag(&"burst"):
		_start_cooldown(1.55)
		_burst_left = 2
		_burst_timer = 0.045
		_shoot(_damage() * 0.78)
	else:
		_start_cooldown(1.3 if has_flag(&"marksman") else 1.0)
		_shoot(_damage())


func _damage() -> float:
	var d: float = base_damage
	if has_flag(&"marksman"):
		d *= 1.5
	if has_flag(&"piercing"):
		d *= 1.25
	return d


func _shoot(damage: float) -> void:
	var dir: Vector3 = _spread_dir(_bloom)
	var result: Dictionary = _hitscan(dir, damage)
	_bloom = minf(_bloom + 0.0035, MAX_BLOOM)
	_after_shot()

	if result.is_empty() or not result.collider is CharacterBody3D:
		return
	var first: CharacterBody3D = result.collider as CharacterBody3D

	if has_flag(&"piercing"):
		# the round carries on through the first body
		var from: Vector3 = result.position + dir * 0.05
		var second: Dictionary = _ray(from, dir, weapon_range, [first.get_rid()])
		if not second.is_empty():
			Vfx.tracer(result.position, second.position, tracer_color, 0.08, 0.008)
			_resolve_hit(second.collider, second.position, second.normal, dir, damage * 0.7)

	if has_flag(&"ricochet"):
		var next: Node3D = Combat.nearest_enemy(get_tree(), result.position, 9.0, [first])
		if next:
			var target_pos: Vector3 = next.aim_point() if next.has_method("aim_point") else next.global_position
			Vfx.tracer(result.position, target_pos, tracer_color, 0.1, 0.008)
			var combat: Combat = Game.combat()
			if combat:
				combat.deal(next, damage * 0.6, {"position": target_pos, "weapon": weapon_id, "can_proc": false})


func hud_state() -> Dictionary:
	return {}
