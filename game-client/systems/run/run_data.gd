class_name RunData
extends RefCounted

# everything about one run: the map (floors, each with one or more room
# options), the path actually taken, and the running totals.

enum RunStatus {
	ACTIVE,
	PAUSED,
	FAILED,
	COMPLETED,
}

const MODE_STANDARD: StringName = &"standard"
const MODE_SPRINT: StringName = &"sprint"
const MODE_ENDLESS: StringName = &"endless"
const MODE_BOSS_RUSH: StringName = &"boss_rush"
const MODE_DAILY: StringName = &"daily"
const MODE_VERSUS: StringName = &"versus"

var run_id: String = ""
var status: RunStatus = RunStatus.ACTIVE
var mode: StringName = MODE_STANDARD
var seed_value: int = 0
var ascension: int = 0

## floors[i] is the list of rooms you may choose between on floor i
var floors: Array = []
## the room taken on each floor. starts as the first option of every floor
## and is overwritten floor by floor as the player chooses.
var room_sequence: Array[RoomData] = []
var current_room_index: int = 0

var total_enemies_killed: int = 0
var rooms_cleared: int = 0
var bosses_defeated: int = 0
var elites_killed: int = 0
var elapsed_time: float = 0.0
var damage_taken: int = 0
var essence: int = 0
var essence_earned: int = 0
var chosen_upgrades: Array[Dictionary] = []
var chosen_mutations: Array[Dictionary] = []
var run_tags: PackedStringArray = []
var metadata: Dictionary = {}


func current_room() -> RoomData:
	if current_room_index >= 0 and current_room_index < room_sequence.size():
		return room_sequence[current_room_index]
	return null


func total_rooms() -> int:
	return room_sequence.size()


func is_final_room() -> bool:
	return current_room_index >= room_sequence.size() - 1


func advance_room() -> bool:
	if is_final_room():
		return false
	current_room_index += 1
	return true


## the choices for the floor after the current one (empty on the last floor).
func next_options() -> Array:
	var next: int = current_room_index + 1
	if next >= floors.size():
		return []
	return floors[next]


## records which option of the next floor the player takes.
func choose_next(option_index: int) -> RoomData:
	var next: int = current_room_index + 1
	if next >= floors.size():
		return null
	var options: Array = floors[next]
	var room: RoomData = options[clampi(option_index, 0, options.size() - 1)]
	room_sequence[next] = room
	return room


func current_act() -> int:
	var room: RoomData = current_room()
	return room.act if room else 0


func is_endless() -> bool:
	return mode == MODE_ENDLESS


class RoomData extends RefCounted:
	var id: String = ""
	var type: RoomDefinitions.RoomType = RoomDefinitions.RoomType.COMBAT
	var difficulty: float = 1.0
	## spawn budget in points (see EnemyTypes cost)
	var enemy_budget: float = 5.0
	var reward: StringName = RoomDefinitions.REWARD_NONE
	var act: int = 0
	var floor_index: int = 0
	var biome: StringName = &"hatchery"
	var boss_id: StringName = &""
	## seeds this room's layout so every peer builds the same arena
	var seed_value: int = 0
	var status: RoomDefinitions.RoomStatus = RoomDefinitions.RoomStatus.PENDING
	var enemies_killed: int = 0
	var metadata: Dictionary = {}

	## older code read this flag; rewards are now a named type.
	var reward_flag: bool:
		get:
			return reward != RoomDefinitions.REWARD_NONE

	func is_boss() -> bool:
		return type == RoomDefinitions.RoomType.BOSS

	func is_peaceful() -> bool:
		return RoomDefinitions.is_peaceful(type)

	func title() -> String:
		if type == RoomDefinitions.RoomType.BOSS and boss_id != &"":
			return BossDefs.display_name(boss_id)
		return RoomDefinitions.type_to_string(type)
