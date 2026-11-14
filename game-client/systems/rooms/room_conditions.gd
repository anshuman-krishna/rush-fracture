class_name RoomConditions
extends RefCounted

# a condition is something true of a whole room for as long as you are in it:
# weak gravity, a tailwind, a storm. most cut both ways, helping or hurting
# the player and the brood alike, so a path choice can be about more than the
# reward at the end of it.
#
# which condition a room has is decided from the room's own seed, so every
# peer agrees, and it is stored in the room's metadata under "condition".

const KEY: String = "condition"
const CHANCE: float = 0.42

## player  [[stat, factor], ...] multipliers on the player's stats while in the room
## enemy   [[stat, factor], ...] multipliers on every enemy's stats
## the rest of a condition's behaviour lives where it has to: the room
## controller for storms, bursts, regrowth and drops, the fog in the biome.
const DEFS: Dictionary = {
	&"thin_air": {
		"name": "thin air", "text": "gravity is weak here: you hang in the air and steer it well",
		"color": Color(0.7, 0.85, 1.0),
		"player": [[&"gravity_scale", 0.55], [&"air_acceleration", 1.3]],
	},
	&"tailwind": {
		"name": "tailwind", "text": "everything moves a fifth faster, you included",
		"color": Color(0.4, 0.95, 1.0),
		"player": [[&"move_speed", 1.2]], "enemy": [[&"move_speed", 1.2]],
	},
	&"frenzy": {
		"name": "frenzy spores", "text": "everything hits 30% harder, you included",
		"color": Color(1.0, 0.4, 0.25),
		"player": [[&"damage", 1.3]], "enemy": [[&"damage", 1.3]],
	},
	&"brittle": {
		"name": "brittle shells", "text": "everything takes 25% more damage, you included",
		"color": Color(1.0, 0.35, 0.8),
		"player": [[&"damage_taken", 1.25]],
	},
	&"haze": {
		"name": "spore haze", "text": "you can barely see across the room, but essence is worth half again",
		"color": Color(0.75, 0.8, 0.65),
		"player": [[&"essence_gain", 1.5]],
	},
	&"overgrowth": {
		"name": "overgrowth", "text": "the brood regrows what you do not finish, and health orbs heal double",
		"color": Color(0.45, 1.0, 0.45),
		"player": [[&"orb_heal", 2.0]],
	},
	&"volatile": {
		"name": "volatile brood", "text": "everything that dies here bursts, and the burst does not care who is near",
		"color": Color(1.0, 0.6, 0.15),
	},
	&"storm": {
		"name": "static storm", "text": "lightning walks the room and strikes whatever stands under it",
		"color": Color(0.75, 0.85, 1.0),
	},
	&"famine": {
		"name": "barren ground", "text": "no health orbs drop here, but essence is doubled",
		"color": Color(0.9, 0.75, 0.4),
		"player": [[&"essence_gain", 2.0]],
	},
}

const BRITTLE_BONUS: float = 0.25
const REGROW_PER_SECOND: float = 0.02
const REGROW_QUIET_MSEC: int = 2000
const STORM_INTERVAL: float = 2.6
const STORM_WARNING: float = 1.1
const STORM_RADIUS: float = 3.4
const BURST_DELAY: float = 0.55
const BURST_RADIUS: float = 3.6
const HAZE_FOG: float = 4.5


static func exists(id: StringName) -> bool:
	return DEFS.has(id)


## the condition of this room, or &"" for none.
static func of(room: RunData.RoomData) -> StringName:
	if room == null:
		return &""
	var id: StringName = StringName(String(room.metadata.get(KEY, "")))
	return id if DEFS.has(id) else &""


static func display_name(id: StringName) -> String:
	return DEFS.get(id, {}).get("name", "")


static func text(id: StringName) -> String:
	return DEFS.get(id, {}).get("text", "")


static func color(id: StringName) -> Color:
	return DEFS.get(id, {}).get("color", Color.WHITE)


## decides this room's condition from its own seed. fights only, never the
## opening floor, never a boss.
static func assign(room: RunData.RoomData) -> void:
	room.metadata.erase(KEY)
	if room.is_peaceful() or room.is_boss() or room.floor_index <= 0:
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(room.seed_value) ^ 0x51ab3
	if rng.randf() >= CHANCE:
		return
	var ids: Array = DEFS.keys()
	room.metadata[KEY] = String(ids[rng.randi() % ids.size()])


static func apply_to_player(id: StringName, stats: StatBlock) -> void:
	clear_player(stats)
	for mod: Array in DEFS.get(id, {}).get("player", []):
		stats.set_mul(mod[0], &"room:condition", float(mod[1]))


static func clear_player(stats: StatBlock) -> void:
	stats.remove_key(&"room:condition")


static func apply_to_enemy(id: StringName, stats: StatBlock) -> void:
	for mod: Array in DEFS.get(id, {}).get("enemy", []):
		stats.set_mul(mod[0], &"room:condition", float(mod[1]))
