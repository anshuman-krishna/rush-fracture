class_name RunData
extends RefCounted


enum RunStatus {
	ACTIVE,
	PAUSED,
	FAILED,
	COMPLETED,
}


var run_id := ""
var status := RunStatus.ACTIVE
var current_room_index := 0
var room_sequence: Array[RoomData] = []
var total_enemies_killed := 0
var rooms_cleared := 0
var elapsed_time := 0.0
var chosen_upgrades: Array[Dictionary] = []
var chosen_mutations: Array[Dictionary] = []
var run_tags: PackedStringArray = []
var difficulty_scale := 1.0


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
	var id := ""
	var type: RoomDefinitions.RoomType = RoomDefinitions.RoomType.COMBAT
	var difficulty := 1.0
	var enemy_budget := 5
	var reward_flag := false
	var status: RoomDefinitions.RoomStatus = RoomDefinitions.RoomStatus.PENDING
	var enemies_killed := 0
	var metadata := {}
