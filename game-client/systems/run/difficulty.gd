class_name Difficulty
extends RefCounted

# how hard the brood hits and how much it can take, chosen on the title
# screen. separate from ascension: ascension is a ladder you climb by
# winning, this is a dial anyone can turn before any run.

const DEFAULT: StringName = &"standard"
const ORDER: Array[StringName] = [&"gentle", &"standard", &"brutal", &"nightmare"]

## damage_taken  multiplier on everything that hurts the player
## enemy_health  multiplier on enemy and boss health
## enemy_speed   multiplier on enemy movement
## shards        multiplier on shards earned
const DEFS: Dictionary = {
	&"gentle": {
		"name": "gentle", "color": Color(0.45, 1.0, 0.5),
		"text": "you take 30% less damage and the brood has 15% less health. shards -20%.",
		"damage_taken": 0.7, "enemy_health": 0.85, "enemy_speed": 1.0, "shards": 0.8,
	},
	&"standard": {
		"name": "standard", "color": Color(0.86, 0.8, 0.68),
		"text": "the game as it was balanced.",
		"damage_taken": 1.0, "enemy_health": 1.0, "enemy_speed": 1.0, "shards": 1.0,
	},
	&"brutal": {
		"name": "brutal", "color": Color(1.0, 0.72, 0.2),
		"text": "you take 25% more damage; the brood has 20% more health and moves 8% faster. shards +30%.",
		"damage_taken": 1.25, "enemy_health": 1.2, "enemy_speed": 1.08, "shards": 1.3,
	},
	&"nightmare": {
		"name": "nightmare", "color": Color(1.0, 0.33, 0.26),
		"text": "you take 50% more damage; the brood has 40% more health and moves 15% faster. shards +60%.",
		"damage_taken": 1.5, "enemy_health": 1.4, "enemy_speed": 1.15, "shards": 1.6,
	},
}


static func exists(id: StringName) -> bool:
	return DEFS.has(id)


## `id` if it is a real difficulty, the default otherwise.
static func valid(id: Variant) -> StringName:
	var key: StringName = StringName(String(id))
	return key if DEFS.has(key) else DEFAULT


static func display_name(id: StringName) -> String:
	return DEFS[valid(id)].name


static func text(id: StringName) -> String:
	return DEFS[valid(id)].text


static func color(id: StringName) -> Color:
	return DEFS[valid(id)].color


static func value(id: StringName, key: String) -> float:
	return float(DEFS[valid(id)].get(key, 1.0))


static func apply_to_player(id: StringName, stats: StatBlock) -> void:
	stats.set_mul(&"damage_taken", &"difficulty", value(id, "damage_taken"))
