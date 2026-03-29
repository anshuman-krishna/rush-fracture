class_name FractureDefinitions
extends RefCounted


enum FractureType {
	VELOCITY_SURGE,
	UNSTABLE_GRAVITY,
	ENEMY_DUPLICATION,
}


static var events: Dictionary = {
	FractureType.VELOCITY_SURGE: {
		"name": "velocity surge",
		"description": "speed amplified",
		"duration": 12.0,
	},
	FractureType.UNSTABLE_GRAVITY: {
		"name": "unstable gravity",
		"description": "gravity weakened",
		"duration": 15.0,
	},
	FractureType.ENEMY_DUPLICATION: {
		"name": "fracture echo",
		"description": "enemies may duplicate",
		"duration": 10.0,
	},
}


static func get_name(type: FractureType) -> String:
	return events[type].name


static func get_duration(type: FractureType) -> float:
	return events[type].duration
