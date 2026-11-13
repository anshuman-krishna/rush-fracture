class_name HazardZone
extends Area3D

# a patch of floor that hurts while you stand in it. it ticks on a timer
# rather than only on entry, so camping in it keeps costing you (the old
# hazards only fired once when you walked in).
#
# every peer builds its own copy; each copy only ever damages the player that
# peer owns.

const TICK: float = 0.45

var radius: float = 2.0
var damage: int = 6
var color: Color = Color(0.6, 1.0, 0.2)
## seconds until it fades out. 0 = permanent for the room.
var lifetime: float = 0.0
## pulses on and off when > 0: dangerous for `pulse_on`, safe for `pulse_off`
var pulse_on: float = 0.0
var pulse_off: float = 0.0
var slows: bool = false

var _tick: float = 0.0
var _age: float = 0.0
var _pulse_clock: float = 0.0
var _active: bool = true
var _disc: MeshInstance3D
var _rim: MeshInstance3D
var _light: OmniLight3D


static func create(p_radius: float, p_damage: int, p_color: Color, p_lifetime: float = 0.0) -> HazardZone:
	var z: HazardZone = HazardZone.new()
	z.radius = p_radius
	z.damage = p_damage
	z.color = p_color
	z.lifetime = p_lifetime
	return z


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitorable = false

	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = radius
	shape.height = 1.2
	col.shape = shape
	col.position.y = 0.6
	add_child(col)

	_disc = Vfx.make_flat(0.0, Color(color.r, color.g, color.b, 0.28))
	_disc.scale = Vector3(radius, 1.0, radius)
	_disc.position.y = Vfx.GROUND_Y
	add_child(_disc)
	_rim = Vfx.make_flat(0.9, Color(color.r, color.g, color.b, 0.9))
	_rim.scale = Vector3(radius, 1.0, radius)
	_rim.position.y = Vfx.GROUND_Y + 0.01
	add_child(_rim)

	_light = OmniLight3D.new()
	_light.light_color = color
	_light.light_energy = 1.2
	_light.omni_range = radius * 1.8
	_light.shadow_enabled = false
	_light.position.y = 0.8
	add_child(_light)

	_tick = randf() * TICK
	if pulse_on > 0.0:
		_pulse_clock = randf() * (pulse_on + pulse_off)


func _physics_process(delta: float) -> void:
	_age += delta
	if lifetime > 0.0:
		var left: float = lifetime - _age
		if left <= 0.0:
			queue_free()
			return
		if left < 0.8:
			_set_alpha(left / 0.8)

	if pulse_on > 0.0:
		_pulse_clock += delta
		var cycle: float = pulse_on + pulse_off
		var t: float = fmod(_pulse_clock, cycle)
		var now_active: bool = t < pulse_on
		if now_active != _active:
			_active = now_active
			_set_alpha(1.0 if _active else 0.25)
			if _active:
				Vfx.sparks(global_position + Vector3(0, 0.3, 0), Vector3.UP, color, 9.0, 40.0)
		elif not _active and cycle - t < 0.5:
			# about to switch on: flicker as a warning
			_set_alpha(0.25 + 0.5 * absf(sin(_pulse_clock * 30.0)))

	if not _active:
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	for body: Node3D in get_overlapping_bodies():
		if not body.is_in_group("player") or not body.has_method("take_damage"):
			continue
		if Game.is_online() and not body.is_multiplayer_authority():
			continue
		# standing on something above the pool (a platform) keeps you out of it
		if body.global_position.y - 0.9 > global_position.y + 0.9:
			continue
		var info: DamageInfo = DamageInfo.make(damage, DamageInfo.KIND_HAZARD)
		info.position = body.global_position
		body.take_damage(damage, info)
		if slows and "stats" in body:
			body.stats.set_mul(&"move_speed", &"hazard_slow", 0.7)
			var stats: StatBlock = body.stats
			get_tree().create_timer(0.6).timeout.connect(func() -> void: stats.set_mul(&"move_speed", &"hazard_slow", 1.0))


func _set_alpha(a: float) -> void:
	if _disc:
		_disc.set_instance_shader_parameter("tint", Color(color.r, color.g, color.b, 0.28 * a))
	if _rim:
		_rim.set_instance_shader_parameter("tint", Color(color.r, color.g, color.b, 0.9 * a))
	if _light:
		_light.light_energy = 1.2 * a
