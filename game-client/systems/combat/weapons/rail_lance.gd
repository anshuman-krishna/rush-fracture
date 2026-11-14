class_name RailLance
extends BaseWeapon

# "marrow lance" — hold to charge, release to put one line through everything
# in front of you. slow, loud, and the only thing that one-shots at range.

const CHARGE_TIME: float = 0.9
const MIN_CHARGE: float = 0.2
const MIN_DAMAGE: float = 45.0
const MAX_DAMAGE: float = 215.0
const MAX_PIERCE: int = 8
const ZOOM_FOV: float = -14.0

var charge: float = 0.0
var _charging: bool = false
var _hum_timer: float = 0.0


func _configure() -> void:
	weapon_id = &"rail_lance"
	display_name = "marrow lance"
	model_path = "res://assets/models/grafted-brood-rail_lance.glb"
	grip_lift = 0.1
	base_damage = MAX_DAMAGE
	fire_interval = 0.55
	weapon_range = 150.0
	weak_mult = 2.2
	recoil_pitch = 3.0
	shake_on_fire = 5.0
	view_kick = 0.11
	tracer_color = Color(0.55, 0.9, 1.0)
	fire_sound = &"rail_fire"
	fire_volume = -1.0


func reset_state() -> void:
	super.reset_state()
	_cancel_charge()


func _on_holster() -> void:
	_cancel_charge()


func _tick(delta: float, held: bool, _pressed: bool, released: bool) -> void:
	if _charging:
		if held:
			var haste: float = 1.4 if has_flag(&"quick_charge") else 1.0
			charge = minf(1.0, charge + delta / CHARGE_TIME * haste * maxf(0.1, _stat(&"fire_rate")))
			_set_zoom(charge)
			_hum_timer -= delta
			if _hum_timer <= 0.0:
				_hum_timer = lerpf(0.22, 0.07, charge)
				Game.sfx(&"rail_charge", -16.0 + charge * 6.0, 0.02)
		elif released or not held:
			if charge >= MIN_CHARGE:
				_fire()
			_cancel_charge()
		return

	if held and _can_fire():
		_charging = true
		charge = 0.0
		_hum_timer = 0.0


func _fire() -> void:
	var power: float = pow(charge, 1.4)
	var damage: float = lerpf(MIN_DAMAGE, MAX_DAMAGE, power)
	var dir: Vector3 = _aim_dir()
	var from: Vector3 = _aim_origin()
	var end: Vector3 = from + dir * weapon_range
	var excluded: Array[RID] = []
	var overpen: bool = has_flag(&"overpenetrate")
	var combat: Combat = Game.combat()

	for n: int in MAX_PIERCE:
		var result: Dictionary = _ray(from, dir, weapon_range, excluded)
		if result.is_empty():
			break
		if not result.collider is CharacterBody3D:
			end = result.position
			_resolve_hit(result.collider, result.position, result.normal, dir, damage)
			break
		var body: CharacterBody3D = result.collider as CharacterBody3D
		# each body it passes through costs it a little
		_resolve_hit(body, result.position, result.normal, dir, damage * pow(0.88, n), {"knockback": 6.0 * power})
		if charge >= 0.95 and has_flag(&"pinning") and body.has_method("stun"):
			body.stun(1.5)
		if overpen and combat and charge >= 0.95:
			var radius: float = 2.6 * _stat(&"blast_radius")
			Vfx.blast(result.position, radius, tracer_color, false)
			combat.blast(result.position, radius, damage * 0.25, {"weapon": weapon_id})
		excluded.append(body.get_rid())

	var width: float = lerpf(0.015, 0.06, power)
	Vfx.tracer(_muzzle_pos(), end, tracer_color, 0.35, width, width * 0.3)
	Vfx.tracer(_muzzle_pos(), end, Color(1, 1, 1), 0.12, width * 0.4)
	Vfx.light(_muzzle_pos(), tracer_color, 5.0, 0.2, 10.0)
	_start_cooldown()
	_after_shot(0.4 + power * 0.6)


func _cancel_charge() -> void:
	_charging = false
	charge = 0.0
	_set_zoom(0.0)


func _set_zoom(amount: float) -> void:
	if camera and is_instance_valid(camera) and "fov_offset" in camera:
		camera.fov_offset = ZOOM_FOV * amount


func hud_state() -> Dictionary:
	if not _charging:
		return {}
	return {
		"meter": charge,
		"meter_color": Color(1, 1, 1) if charge >= 1.0 else tracer_color,
		"label": "charged" if charge >= 1.0 else "charging",
	}
