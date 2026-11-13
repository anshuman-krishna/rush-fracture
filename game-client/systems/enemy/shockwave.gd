class_name Shockwave
extends Node3D

# a ring of force that travels outward along the floor. it hurts players it
# sweeps over unless they are off the ground when it passes: the game's
# standing answer to "how do i dodge that" is "jump".
#
# every peer runs its own copy and only ever damages the player it owns.

const BAND: float = 0.9
const CLEAR_HEIGHT: float = 0.55

var max_radius: float = 20.0
var speed: float = 14.0
var damage: int = 15
var color: Color = Color(1.0, 0.35, 0.1)
var start_radius: float = 1.0
## when false the wave is a wall: jumping does not help
var jumpable: bool = true

var _radius: float = 1.0
var _hit: Dictionary = {}
var _outer: MeshInstance3D
var _inner: MeshInstance3D


static func spawn(parent: Node, at: Vector3, p_max_radius: float, p_speed: float, p_damage: int,
		p_color: Color, p_start: float = 1.0, p_jumpable: bool = true) -> Shockwave:
	var w: Shockwave = Shockwave.new()
	w.max_radius = p_max_radius
	w.speed = p_speed
	w.damage = p_damage
	w.color = p_color
	w.start_radius = p_start
	w.jumpable = p_jumpable
	parent.add_child(w)
	w.global_position = Vector3(at.x, at.y, at.z)
	return w


func _ready() -> void:
	_radius = start_radius
	_outer = Vfx.make_flat(0.9, color)
	_inner = Vfx.make_flat(0.75, Color(color.r, color.g, color.b, 0.35))
	_outer.position.y = Vfx.GROUND_Y + 0.02
	_inner.position.y = Vfx.GROUND_Y + 0.01
	add_child(_outer)
	add_child(_inner)
	_apply_scale()


func _physics_process(delta: float) -> void:
	_radius += speed * delta
	if _radius >= max_radius:
		queue_free()
		return
	_apply_scale()

	var fade: float = clampf((max_radius - _radius) / (max_radius * 0.25), 0.0, 1.0)
	_outer.set_instance_shader_parameter("tint", Color(color.r, color.g, color.b, fade))
	_inner.set_instance_shader_parameter("tint", Color(color.r, color.g, color.b, 0.35 * fade))

	var pm: PlayerManager = Game.players()
	if not pm:
		return
	for p: CharacterBody3D in pm.get_all_players():
		if not is_instance_valid(p) or p.get("is_dead") == true:
			continue
		var id: int = p.get_instance_id()
		if _hit.has(id):
			continue
		if Game.is_online() and not p.is_multiplayer_authority():
			continue
		var flat: float = Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
		if absf(flat - _radius) > BAND:
			continue
		# a player's origin is 0.9 above their feet
		var feet: float = p.global_position.y - 0.9 - global_position.y
		if jumpable and feet > CLEAR_HEIGHT:
			continue
		_hit[id] = true
		var info: DamageInfo = DamageInfo.make(damage, DamageInfo.KIND_BLAST)
		info.position = p.global_position
		p.take_damage(damage, info)
		if p.has_method("apply_impulse"):
			var away: Vector3 = p.global_position - global_position
			away.y = 0.0
			p.apply_impulse(away.normalized() * 6.0 + Vector3(0, 3.0, 0))


func _apply_scale() -> void:
	_outer.scale = Vector3(_radius, 1.0, _radius)
	_inner.scale = Vector3(_radius * 0.96, 1.0, _radius * 0.96)
