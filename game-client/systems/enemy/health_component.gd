class_name HealthComponent
extends Node

signal damaged(amount: int, current: int)
signal died

@export var max_health: int = 50

var current_health: int
var _died_triggered: bool = false


func _ready() -> void:
	current_health = max_health


func _process(_delta: float) -> void:
	# detect death from synced health in multiplayer (non-authority)
	if not _died_triggered and current_health <= 0 and max_health > 0:
		if _is_multiplayer_active() and not _is_authority():
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
	if _is_authority():
		_apply_damage(amount)


func is_alive() -> bool:
	return current_health > 0


func _is_multiplayer_active() -> bool:
	return multiplayer and multiplayer.has_multiplayer_peer()


func _is_authority() -> bool:
	if not _is_multiplayer_active():
		return true
	return get_parent().is_multiplayer_authority()
