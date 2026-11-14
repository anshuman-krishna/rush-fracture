class_name HealthComponent
extends Node

# hit points for anything that can be damaged (enemies, bosses, destructible
# props). in multiplayer the host owns the truth: a client only reports its
# hits to the host, which clamps what it accepts, and every client takes the
# resulting health (and death) from what the host sends back. a client never
# decides on its own that something died.

signal damaged(amount: int, current: int, info: DamageInfo)
signal died(info: DamageInfo)
signal healed(amount: int, current: int)
signal shield_broken

@export var max_health: int = 50

# first line of defense against a modified client forging damage rpcs. this
# can't validate against the attacker's real loadout, but it removes the
# trivial one-shot-anything and unlimited-spam versions of the exploit.
const MAX_DAMAGE_PER_HIT: int = 5000
## the most one peer may report against one target in a second. generous: a
## shotgun lands ten pellets in one frame and every one of them is real.
const MAX_DAMAGE_PER_SECOND: int = 40000

var current_health: int
## incoming damage is multiplied by this (armour < 1, vulnerability > 1)
var damage_scale: float = 1.0
## while true every hit is ignored (spawn-in, phase transitions)
var invulnerable: bool = false
## absorbs damage before health does. 0 = no shield.
var shield: int = 0
var max_shield: int = 0
## msec timestamp of the last damage taken, for regeneration rules
var last_damage_msec: int = 0

var _died_triggered: bool = false
# keyed by sending peer id, so one attacker's budget never eats another's
# hits: peer -> [window start msec, damage accepted in the window]
var _rpc_budget: Dictionary = {}


func _ready() -> void:
	current_health = max_health


func _process(_delta: float) -> void:
	# clients learn about a death through the replicated health value
	if _died_triggered or not Game.is_online() or _is_authority():
		return
	if current_health <= 0 and max_health > 0:
		_died_triggered = true
		died.emit(null)


## resets to a new maximum at full health (used when scaling for difficulty).
func set_max(value: int) -> void:
	max_health = maxi(1, value)
	current_health = max_health


func set_shield(value: int) -> void:
	max_shield = maxi(0, value)
	shield = max_shield


## applies damage. returns true if this call is what killed the target, as
## seen locally (a client's prediction can be overruled by the host).
func take_damage(amount: int, info: DamageInfo = null) -> bool:
	if _died_triggered or amount <= 0:
		return false
	if invulnerable and not (info and info.ignore_invulnerable):
		return false

	if Game.is_online() and not _is_authority():
		# report it and show the hit, but leave the numbers to the host
		_rpc_take_damage.rpc_id(1, amount, info.crit if info else false)
		damaged.emit(amount, current_health, info)
		return false
	return _apply_damage(amount, info)


## bypasses invulnerability and shields: used for scripted deaths (falling
## out of the world, self-detonation).
func kill(info: DamageInfo = null) -> void:
	if _died_triggered:
		return
	shield = 0
	current_health = 0
	_died_triggered = true
	damaged.emit(max_health, 0, info)
	died.emit(info)


func heal(amount: int) -> void:
	if _died_triggered or amount <= 0 or current_health >= max_health:
		return
	var before: int = current_health
	current_health = mini(current_health + amount, max_health)
	healed.emit(current_health - before, current_health)


func is_alive() -> bool:
	return current_health > 0 and not _died_triggered


func ratio() -> float:
	return float(current_health) / float(maxi(max_health, 1))


func _apply_damage(amount: int, info: DamageInfo) -> bool:
	if _died_triggered:
		return false
	var dealt: int = maxi(1, int(round(amount * damage_scale)))
	last_damage_msec = Time.get_ticks_msec()

	if shield > 0:
		var absorbed: int = mini(shield, dealt)
		shield -= absorbed
		dealt -= absorbed
		if shield <= 0:
			shield_broken.emit()
		if dealt <= 0:
			damaged.emit(absorbed, current_health, info)
			return false

	current_health = maxi(0, current_health - dealt)
	damaged.emit(dealt, current_health, info)

	if current_health <= 0:
		_died_triggered = true
		died.emit(info)
		return true
	return false


@rpc("any_peer", "call_remote", "reliable")
func _rpc_take_damage(amount: int, crit: bool) -> void:
	# a report can arrive for a target the room removed a moment ago
	if not is_inside_tree() or not _is_authority():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if invulnerable or amount <= 0:
		return
	amount = mini(amount, MAX_DAMAGE_PER_HIT)
	var now: int = Time.get_ticks_msec()
	var budget: Array = _rpc_budget.get(sender, [now, 0])
	if now - int(budget[0]) >= 1000:
		budget = [now, 0]
	if int(budget[1]) + amount > MAX_DAMAGE_PER_SECOND:
		return
	budget[1] = int(budget[1]) + amount
	_rpc_budget[sender] = budget
	var info: DamageInfo = DamageInfo.make(amount)
	info.crit = crit
	info.peer = sender
	_apply_damage(info.amount, info)


func _is_authority() -> bool:
	if not Game.is_online():
		return true
	return get_parent().is_multiplayer_authority()
