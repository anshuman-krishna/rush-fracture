class_name DamageInfo
extends RefCounted

# describes one instance of damage as it travels from whatever caused it to
# whatever receives it, so feedback (numbers, markers, kill credit) and
# on-hit effects all read the same facts.

const KIND_BULLET: StringName = &"bullet"
const KIND_BEAM: StringName = &"beam"
const KIND_BLAST: StringName = &"blast"
const KIND_DOT: StringName = &"dot"
const KIND_MELEE: StringName = &"melee"
const KIND_PROJECTILE: StringName = &"projectile"
const KIND_HAZARD: StringName = &"hazard"
const KIND_SELF: StringName = &"self"

var amount: int = 0
var kind: StringName = KIND_BULLET
var crit: bool = false
## landed on the target's weak point (head / exposed core)
var weak: bool = false
## the node responsible: a player for outgoing damage, an enemy for incoming
var source: Node = null
## network id of the player behind this damage, when it arrived from another
## peer. 0 for anything local.
var peer: int = 0
var weapon: StringName = &""
var position: Vector3 = Vector3.ZERO
var direction: Vector3 = Vector3.ZERO
var knockback: float = 0.0
## false when this damage was itself caused by an on-hit effect, so effects
## can never trigger each other in a loop
var can_proc: bool = true
## true when the hit passed through invulnerability rules (run-ending falls)
var ignore_invulnerable: bool = false


static func make(p_amount: int, p_kind: StringName = KIND_BULLET, p_source: Node = null) -> DamageInfo:
	var d: DamageInfo = DamageInfo.new()
	d.amount = p_amount
	d.kind = p_kind
	d.source = p_source
	return d


func at(p_position: Vector3, p_direction: Vector3 = Vector3.ZERO) -> DamageInfo:
	position = p_position
	direction = p_direction
	return self


func no_proc() -> DamageInfo:
	can_proc = false
	return self
