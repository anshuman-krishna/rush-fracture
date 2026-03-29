class_name RunData
extends RefCounted


enum RunStatus {
	ACTIVE,
	PAUSED,
	FAILED,
	COMPLETED,
}


var run_id: String = ""
var status: RunStatus = RunStatus.ACTIVE
var current_room_index: int = 0
var room_sequence: Array[RoomData] = []
var total_enemies_killed: int = 0
var rooms_cleared: int = 0
var elapsed_time: float = 0.0
var chosen_upgrades: Array[Dictionary] = []
var chosen_mutations: Array[Dictionary] = []
var run_tags: PackedStringArray = []
var difficulty_scale: float = 1.0


func current_room() -> RoomData:
	if current_room_index < room_sequence.size():
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


class RoomData extends RefCounted:
	var id: String = ""
	var type: RoomDefinitions.RoomType = RoomDefinitions.RoomType.COMBAT
	var difficulty: float = 1.0
	var enemy_budget: int = 5
	var reward_flag: bool = false
	var status: RoomDefinitions.RoomStatus = RoomDefinitions.RoomStatus.PENDING
	var enemies_killed: int = 0
	var metadata: Dictionary = {}
