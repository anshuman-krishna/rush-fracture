class_name FractureDefinitions
extends RefCounted


enum FractureType {
	VELOCITY_SURGE,
	UNSTABLE_GRAVITY,
	ENEMY_DUPLICATION,
	LOW_GRAVITY,
	DOUBLE_SPEED_ENEMIES,
	RANDOM_EXPLOSIONS,
	VISION_DISTORTION,
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
	FractureType.LOW_GRAVITY: {
		"name": "void drift",
		"description": "gravity near zero",
		"duration": 10.0,
	},
	FractureType.DOUBLE_SPEED_ENEMIES: {
		"name": "adrenaline leak",
		"description": "enemies move 2x faster",
		"duration": 12.0,
	},
	FractureType.RANDOM_EXPLOSIONS: {
		"name": "unstable field",
		"description": "random explosions across the arena",
		"duration": 10.0,
	},
	FractureType.VISION_DISTORTION: {
		"name": "perception fracture",
		"description": "vision warped",
		"duration": 8.0,
	},
}


static func get_name(type: FractureType) -> String:
	return events[type].name


static func get_duration(type: FractureType) -> float:
	return events[type].duration
