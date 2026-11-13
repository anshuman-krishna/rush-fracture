class_name ScatterCannon
extends BaseWeapon

# "sporecaster" — a wall of pellets. deletes whatever is in your face and
# barely scratches anything across the room.

const FALLOFF_START: float = 10.0
const FALLOFF_END: float = 30.0
const FALLOFF_MIN: float = 0.3

var pellet_count: int = 7
var spread: float = 0.075
var _second_blast: float = -1.0
var _second_damage: float = 0.0


func _configure() -> void:
	weapon_id = &"scatter_cannon"
	display_name = "sporecaster"
	model_path = "res://assets/models/grafted-brood-scatter_cannon.glb"
	muzzle_fallback = Vector3(0, 0.12, -0.321)
	grip_lift = 0.095
	base_damage = 9.0
	fire_interval = 0.5
	weapon_range = 42.0
	weak_mult = 1.3
	recoil_pitch = 1.5
	shake_on_fire = 2.6
	view_kick = 0.07
	tracer_color = Color(1.0, 0.45, 0.1)
	fire_sound = &"scatter_fire"
	fire_volume = -3.0


func reset_state() -> void:
	super.reset_state()
	_second_blast = -1.0


func _tick(delta: float, held: bool, _pressed: bool, _released: bool) -> void:
	if _second_blast >= 0.0:
		_second_blast -= delta
		if _second_blast < 0.0:
			_blast(_second_damage)
			_after_shot(0.7)

	if not held or not _can_fire():
		return
	_start_cooldown()
	_blast(base_damage)
	_after_shot()
	if has_flag(&"double_blast"):
		_second_blast = 0.09
		_second_damage = base_damage * 0.6


func _blast(damage: float) -> void:
	var count: int = pellet_count + (3 if has_flag(&"wide") else 0)
	var cone: float = spread
	if has_flag(&"tight"):
		cone *= 0.5
	if has_flag(&"wide"):
		cone *= 1.3
	var from: Vector3 = _aim_origin()
	var ignite: bool = has_flag(&"incendiary")

	for i: int in count:
		var dir: Vector3 = _spread_dir(cone)
		var result: Dictionary = _ray(from, dir, weapon_range)
		var end: Vector3 = from + dir * weapon_range
		if result.is_empty():
			Vfx.tracer(_muzzle_pos(), end, tracer_color, 0.06, 0.007)
			continue
		end = result.position
		Vfx.tracer(_muzzle_pos(), end, tracer_color, 0.06, 0.007)
		var dist: float = from.distance_to(end)
		var falloff: float = lerpf(1.0, FALLOFF_MIN, clampf((dist - FALLOFF_START) / (FALLOFF_END - FALLOFF_START), 0.0, 1.0))
		var info: DamageInfo = _resolve_hit(result.collider, end, result.normal, dir, damage * falloff,
			{"knockback": 2.5 if dist < 8.0 else 0.0})
		if info and ignite and result.collider.has_method("apply_status"):
			result.collider.apply_status(&"burn", 3.0, damage * 0.5, owner_player)
