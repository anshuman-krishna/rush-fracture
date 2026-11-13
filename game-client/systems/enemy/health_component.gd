class_name HealthComponent
extends Node

# hit points for anything that can be damaged (enemies, bosses, destructible
# props). in multiplayer the host owns the truth: a client applies its own
# hits locally for instant feedback and forwards them to the host, which
# clamps and rate-limits what it accepts.

signal damaged(amount: int, current: int, info: DamageInfo)
signal died(info: DamageInfo)
signal healed(amount: int, current: int)
signal shield_broken

@export var max_health: int = 50

# first line of defense against a modified client forging damage rpcs. this
# can't validate against the attacker's real loadout, but it removes the
# trivial one-shot-anything and unlimited-spam versions of the exploit.
const MAX_DAMAGE_PER_HIT: int = 600
const MIN_DAMAGE_RPC_INTERVAL_MS: int = 15

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
# keyed by sending peer id — one shared timestamp would let one attacker's
# rate limit silently eat a second attacker's simultaneous hit.
var _last_rpc_damage_ms: Dictionary = {}


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
		var killed: bool = _apply_damage(amount, info)
		_rpc_take_damage.rpc_id(1, amount, info.crit if info else false)
		return killed
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
	if not _is_authority():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var now: int = Time.get_ticks_msec()
	var last: int = _last_rpc_damage_ms.get(sender, -MIN_DAMAGE_RPC_INTERVAL_MS)
	if now - last < MIN_DAMAGE_RPC_INTERVAL_MS:
		return
	_last_rpc_damage_ms[sender] = now
	if invulnerable:
		return
	var info: DamageInfo = DamageInfo.make(clampi(amount, 0, MAX_DAMAGE_PER_HIT))
	info.crit = crit
	_apply_damage(info.amount, info)


func _is_authority() -> bool:
	if not Game.is_online():
		return true
	return get_parent().is_multiplayer_authority()
