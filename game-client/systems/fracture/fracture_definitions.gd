class_name FractureDefinitions
extends RefCounted

# fracture events: temporary rule changes that can hit a room mid-fight.

enum FractureType {
	VELOCITY_SURGE,
	UNSTABLE_GRAVITY,
	ENEMY_DUPLICATION,
	LOW_GRAVITY,
	DOUBLE_SPEED_ENEMIES,
	RANDOM_EXPLOSIONS,
	VISION_DISTORTION,
	BLOOD_FRENZY,
	ESSENCE_STORM,
}

const EVENTS: Dictionary = {
	FractureType.VELOCITY_SURGE: {"name": "velocity surge", "description": "you are much faster", "duration": 12.0},
	FractureType.UNSTABLE_GRAVITY: {"name": "unstable gravity", "description": "gravity weakens", "duration": 14.0},
	FractureType.ENEMY_DUPLICATION: {"name": "fracture echo", "description": "the dead come back as copies", "duration": 10.0},
	FractureType.LOW_GRAVITY: {"name": "void drift", "description": "gravity almost gone", "duration": 10.0},
	FractureType.DOUBLE_SPEED_ENEMIES: {"name": "adrenaline leak", "description": "enemies move far faster", "duration": 11.0},
	FractureType.RANDOM_EXPLOSIONS: {"name": "unstable field", "description": "the ground erupts at random", "duration": 10.0},
	FractureType.VISION_DISTORTION: {"name": "perception fracture", "description": "your view closes in", "duration": 9.0},
	FractureType.BLOOD_FRENZY: {"name": "blood frenzy", "description": "everyone hits harder, including you", "duration": 12.0},
	FractureType.ESSENCE_STORM: {"name": "essence storm", "description": "triple essence while it lasts", "duration": 12.0},
}


static func get_event_name(type: int) -> String:
	return EVENTS.get(type, {}).get("name", "")


static func get_description(type: int) -> String:
	return EVENTS.get(type, {}).get("description", "")


static func get_duration(type: int) -> float:
	return EVENTS.get(type, {}).get("duration", 10.0)
