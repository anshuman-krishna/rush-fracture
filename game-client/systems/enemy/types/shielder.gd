extends EnemyBase

# "carapace bulwark" — walks at you behind a plate that stops bullets, beams
# and thrown discs from the front. it turns slowly: get beside or behind it,
# hit it with a blast, or put enough into the plate to crack it.

const BASH_REACH: float = 1.8
const BASH_COOLDOWN: float = 2.4
const TURN_SPEED: float = 2.0
const FRONT_ARC: float = 0.3
const PLATE_HEALTH: float = 160.0

var _cooldown: float = 0.0
var _plate: float = PLATE_HEALTH
var _plate_node: Node3D


func _build_visual() -> void:
	super._build_visual()
	if model:
		_plate_node = model.find_child("shield", true, false) as Node3D


func _ai(delta: float, dist: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if dist <= BASH_REACH + body_radius + 0.4 and _cooldown <= 0.0:
		_cooldown = BASH_COOLDOWN
		_start_melee(0.5, BASH_REACH, damage(), 6.0, 0.5)
		return
	var dir: Vector3 = _steer(_to_target())
	_move(dir, speed(), 12.0, delta)
	# deliberately slow to turn: this is what makes flanking work
	_face_target(delta, TURN_SPEED * (1.4 if is_elite else 1.0))


## called by the damage pipeline before a hit lands. returns the amount that
## gets through.
func modify_incoming(amount: float, info: DamageInfo) -> float:
	if _plate <= 0.0 or info == null:
		return amount
	if info.kind == DamageInfo.KIND_BLAST or info.kind == DamageInfo.KIND_DOT or info.kind == DamageInfo.KIND_MELEE:
		return amount
	var facing: Vector3 = -global_transform.basis.z
	var incoming: Vector3 = info.direction
	if incoming.length() < 0.01 and is_instance_valid(info.source) and info.source is Node3D:
		incoming = global_position - (info.source as Node3D).global_position
	incoming.y = 0.0
	if incoming.length() < 0.01:
		return amount
	# the shot is blocked when it travels against the way the plate faces
	if facing.dot(-incoming.normalized()) < FRONT_ARC:
		return amount
	_plate -= amount
	Vfx.sparks(info.position, facing, Color(0.9, 0.9, 1.0), 6.0, 50.0)
	Game.sfx_at(&"shield_block", global_position, -10.0, 0.15)
	if _plate <= 0.0:
		_shatter()
	return 0.0


func _shatter() -> void:
	if _plate_node and is_instance_valid(_plate_node):
		_plate_node.visible = false
	Vfx.chunks(aim_point() - global_transform.basis.z * 0.5, Color(0.8, 0.75, 0.65), 7.0)
	Game.sfx_at(&"shield_break", global_position, -3.0, 0.1)
	stun(0.8)
