class_name HealthComponent
extends Node

signal damaged(amount: int, current: int)
signal died

@export var max_health := 50

var current_health: int


func _ready() -> void:
	current_health = max_health


func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	damaged.emit(amount, current_health)

	if current_health <= 0:
		died.emit()


func is_alive() -> bool:
	return current_health > 0
