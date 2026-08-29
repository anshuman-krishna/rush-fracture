class_name HealthComponent
extends Node

signal damaged(amount: int, current: int)
signal died

@export var max_health: int = 50

# first line of defense against a modified client sending a forged damage rpc
# (this can't validate against actual weapon state — that would need the host
# to know the attacker's live loadout — but it kills the trivial one-shot-any-
# enemy and unlimited-damage-spam versions of the exploit).
const MAX_DAMAGE_PER_HIT: int = 250
const MIN_DAMAGE_RPC_INTERVAL_MS: int = 40

var current_health: int
var _died_triggered: bool = false
# keyed by sending peer id — a single shared timestamp would let one
# attacker's rate limit silently eat a second attacker's simultaneous hit.
var _last_rpc_damage_ms: Dictionary = {}


func _ready() -> void:
	current_health = max_health


func _process(_delta: float) -> void:
	# detect death from synced health in multiplayer (non-authority)
	if not _is_multiplayer_active():
		return
	if not _died_triggered and current_health <= 0 and max_health > 0:
		if not _is_authority():
			_died_triggered = true
			died.emit()


func take_damage(amount: int) -> void:
	if _died_triggered:
		return

	if _is_multiplayer_active() and not _is_authority():
		# optimistic: apply locally for immediate feedback, rpc to host for authority
		_apply_damage(amount)
		_rpc_take_damage.rpc_id(1, amount)
		return

	_apply_damage(amount)


func _apply_damage(amount: int) -> void:
	if _died_triggered:
		return
	current_health = max(0, current_health - amount)
	damaged.emit(amount, current_health)

	if current_health <= 0:
		_died_triggered = true
		died.emit()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_take_damage(amount: int) -> void:
	if not _is_authority():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var now: int = Time.get_ticks_msec()
	var last: int = _last_rpc_damage_ms.get(sender, -MIN_DAMAGE_RPC_INTERVAL_MS)
	if now - last < MIN_DAMAGE_RPC_INTERVAL_MS:
		return
	_last_rpc_damage_ms[sender] = now
	_apply_damage(clampi(amount, 0, MAX_DAMAGE_PER_HIT))


func is_alive() -> bool:
	return current_health > 0


func _is_multiplayer_active() -> bool:
	return multiplayer and multiplayer.has_multiplayer_peer()


func _is_authority() -> bool:
	if not _is_multiplayer_active():
		return true
	return get_parent().is_multiplayer_authority()
