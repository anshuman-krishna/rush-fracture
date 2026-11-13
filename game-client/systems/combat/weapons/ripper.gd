class_name Ripper
extends BaseWeapon

# "ripper" — throws a saw disc that cuts through bodies and bounces off
# walls. in a tight room one disc can hit the same pack three times.

const SPEED: float = 42.0
const MAX_DISCS: int = 3

var bounces: int = 4
var _live: int = 0


func _configure() -> void:
	weapon_id = &"ripper"
	display_name = "ripper"
	model_path = "res://assets/models/grafted-brood-ripper.glb"
	grip_lift = 0.08
	base_damage = 38.0
	fire_interval = 0.72
	weapon_range = 90.0
	weak_mult = 1.3
	recoil_pitch = 1.1
	shake_on_fire = 1.8
	view_kick = 0.06
	tracer_color = Color(1.0, 0.85, 0.5)
	fire_sound = &"disc_fire"
	fire_volume = -4.0


func reset_state() -> void:
	super.reset_state()
	_live = 0


func _tick(_delta: float, held: bool, _pressed: bool, _released: bool) -> void:
	if not held or not _can_fire() or _live >= MAX_DISCS:
		return
	var pm: ProjectileManager = Game.projectiles()
	if not pm:
		return
	_start_cooldown()
	var dir: Vector3 = _aim_dir()
	var shot: ProjectileManager.Shot = pm.fire_player({
		"position": _aim_origin() + dir * 0.7,
		"velocity": dir * SPEED,
		"life": 3.4,
		"radius": 0.3,
		"color": tracer_color,
		"shape": "disc",
		"spin": 38.0,
		"bounces": bounces + int(flag_value(&"extra_bounces", 0)),
		"pierce": true,
		"source": owner_player,
		"on_hit": _on_hit,
		"on_expire": _on_expire,
	})
	if shot:
		_live += 1
	_after_shot()


## returns false so the disc keeps flying through the body it just cut.
func _on_hit(shot: ProjectileManager.Shot, collider: Object, pos: Vector3, normal: Vector3) -> bool:
	var dir: Vector3 = shot.velocity.normalized()
	var info: DamageInfo = _resolve_hit(collider, pos, normal, dir, base_damage, {"kind": DamageInfo.KIND_PROJECTILE})
	if info:
		Game.sfx_at(&"disc_hit", pos, -8.0, 0.15)
		if has_flag(&"serrated") and collider.has_method("apply_status"):
			collider.apply_status(&"burn", 3.0, base_damage * 0.35, owner_player)
	return false


func _on_expire(_shot: ProjectileManager.Shot, at: Vector3) -> void:
	_live = maxi(0, _live - 1)
	Vfx.sparks(at, Vector3.UP, tracer_color, 5.0, 120.0)


func hud_state() -> Dictionary:
	return {"meter": float(MAX_DISCS - _live) / float(MAX_DISCS), "meter_color": tracer_color, "label": "discs", "invert": true}
