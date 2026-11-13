class_name ArcCaster
extends BaseWeapon

# "synapse coil" — lightning that picks its own targets. point it roughly at
# a crowd and it jumps from body to body, slowing each one. runs on a battery
# that drains while firing and refills when you stop.

const TICK: float = 0.09
const CONE: float = 0.4
const JUMP_RANGE: float = 7.5
const JUMP_FALLOFF: float = 0.75
const DRAIN_PER_SECOND: float = 17.0
const RECHARGE_PER_SECOND: float = 32.0
const RECHARGE_DELAY: float = 0.6

var battery: float = 100.0
var max_battery: float = 100.0
var base_jumps: int = 3

var _tick_timer: float = 0.0
var _idle: float = 0.0
var _depleted: bool = false


func _configure() -> void:
	weapon_id = &"arc_caster"
	display_name = "synapse coil"
	model_path = "res://assets/models/grafted-brood-arc_caster.glb"
	grip_lift = 0.08
	base_damage = 13.0
	fire_interval = TICK
	weapon_range = 18.0
	weak_mult = 1.0
	recoil_pitch = 0.05
	shake_on_fire = 0.5
	view_kick = 0.006
	tracer_color = Color(0.55, 0.75, 1.0)
	fire_sound = &"arc_fire"
	fire_volume = -9.0


func reset_state() -> void:
	super.reset_state()
	battery = max_battery
	_depleted = false


func _tick(delta: float, held: bool, _pressed: bool, _released: bool) -> void:
	if not held or _depleted:
		_recharge(delta)
		return
	_idle = 0.0
	battery -= DRAIN_PER_SECOND * _stat(&"heat_gain") * delta
	if battery <= 0.0:
		battery = 0.0
		_depleted = true
		Game.sfx(&"overheat", -6.0)
		return

	_tick_timer -= delta
	if _tick_timer > 0.0:
		return
	_tick_timer = TICK / maxf(0.1, _stat(&"fire_rate"))
	_discharge()


func _tick_holstered(delta: float) -> void:
	_recharge(delta)


func _recharge(delta: float) -> void:
	_idle += delta
	if _idle < RECHARGE_DELAY:
		return
	battery = minf(max_battery, battery + RECHARGE_PER_SECOND * delta)
	if _depleted and battery >= max_battery * 0.35:
		_depleted = false


func _discharge() -> void:
	var combat: Combat = Game.combat()
	if not combat:
		return
	var origin: Vector3 = _aim_origin()
	var aim: Vector3 = _aim_dir()
	var start: Vector3 = _muzzle_pos()
	var first: Node3D = _first_target(origin, aim)

	if not first:
		# nothing in reach: crackle into the air
		Vfx.lightning(start, start + aim * 3.0 + Vector3(randf_range(-0.6, 0.6), randf_range(-0.4, 0.4), 0), tracer_color, 0.07, 0.3, 0.012)
		return

	var jumps: int = base_jumps + int(flag_value(&"extra_jumps", 0))
	var hit: Array = []
	var from: Vector3 = start
	var current: Node3D = first
	var damage: float = base_damage
	for n: int in jumps:
		var to: Vector3 = current.aim_point() if current.has_method("aim_point") else current.global_position
		Vfx.lightning(from, to, tracer_color, 0.09, 0.3, 0.016 if n == 0 else 0.011)
		combat.deal(current, damage, {
			"position": to, "kind": DamageInfo.KIND_BEAM, "weapon": weapon_id,
			"can_crit": n == 0, "quiet": n > 0,
		})
		if is_instance_valid(current) and current.has_method("apply_status"):
			current.apply_status(&"slow", 0.6, 0.3, owner_player)
		hit.append(current)
		from = to
		damage *= JUMP_FALLOFF
		var next: Node3D = Combat.nearest_enemy(get_tree(), to, JUMP_RANGE, hit)
		if not next:
			break
		current = next

	Vfx.light(start, tracer_color, 1.5, 0.08, 5.0)
	Game.sfx(fire_sound, fire_volume, 0.1)
	if camera and camera.has_method("add_shake"):
		camera.add_shake(shake_on_fire)
	_kick = minf(_kick + view_kick, 0.02)
	fired.emit()


## the enemy closest to the crosshair inside the cone, with a clear line to it.
func _first_target(origin: Vector3, aim: Vector3) -> Node3D:
	var best: Node3D = null
	var best_score: float = INF
	for e: Node3D in Combat.living_enemies(get_tree()):
		var p: Vector3 = e.aim_point() if e.has_method("aim_point") else e.global_position
		var to: Vector3 = p - origin
		var dist: float = to.length()
		if dist > weapon_range or dist < 0.2:
			continue
		var angle: float = aim.angle_to(to / dist)
		if angle > CONE:
			continue
		var score: float = angle * 30.0 + dist
		if score >= best_score:
			continue
		var block: Dictionary = _ray(origin, to / dist, dist - 0.3)
		if not block.is_empty() and block.collider != e and not block.collider is CharacterBody3D:
			continue
		best_score = score
		best = e
	return best


func hud_state() -> Dictionary:
	return {
		"meter": battery / max_battery,
		"meter_color": Color(1.0, 0.3, 0.2) if _depleted else tracer_color,
		"warn": _depleted,
		"label": "depleted" if _depleted else "charge",
		"invert": true,
	}
