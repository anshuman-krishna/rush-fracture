class_name BaseWeapon
extends Node3D

# base class for all weapons. defines the shared interface
# that weapon_manager relies on for type-safe access.

signal enemy_killed
signal enemy_hit(position: Vector3)

var base_damage: int = 0
var base_fire_rate: float = 0.0
var shake_on_fire: float = 0.0


func try_fire(_effective_damage: int, _effective_fire_rate: float) -> bool:
	return false


func get_weapon_name() -> String:
	return ""
