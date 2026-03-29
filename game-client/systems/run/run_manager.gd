class_name RunManager
extends Node

signal run_started(data: RunData)
signal room_entered(room: RunData.RoomData)
signal room_cleared(room: RunData.RoomData)
signal run_failed(data: RunData)
signal run_completed(data: RunData)
signal upgrade_chosen(upgrade: Dictionary)
signal enemy_killed_in_run

var data: RunData
var is_active: bool = false


func _process(delta: float) -> void:
	if is_active and data and data.status == RunData.RunStatus.ACTIVE:
		data.elapsed_time += delta


func start_run(seed_value: int = -1) -> void:
	data = RunData.new()
	data.run_id = _generate_id()
	data.room_sequence = RoomGenerator.generate(seed_value)
	data.status = RunData.RunStatus.ACTIVE
	is_active = true
	run_started.emit(data)

	enter_current_room()


func enter_current_room() -> void:
	var room: RunData.RoomData = data.current_room()
	if not room:
		return
	room.status = RoomDefinitions.RoomStatus.ACTIVE
	room_entered.emit(room)


func on_room_enemies_cleared() -> void:
	var room: RunData.RoomData = data.current_room()
	if not room or room.status != RoomDefinitions.RoomStatus.ACTIVE:
		return

	room.status = RoomDefinitions.RoomStatus.CLEARED
	data.rooms_cleared += 1
	room_cleared.emit(room)


func advance_to_next_room() -> void:
	if data.is_final_room():
		complete_run()
		return
	data.advance_room()
	enter_current_room()


func register_kill() -> void:
	if not data:
		return
	data.total_enemies_killed += 1
	var room: RunData.RoomData = data.current_room()
	if room:
		room.enemies_killed += 1
	enemy_killed_in_run.emit()


func apply_upgrade(upgrade: Dictionary) -> void:
	if not data:
		return
	data.chosen_upgrades.append(upgrade)
	upgrade_chosen.emit(upgrade)


func fail_run() -> void:
	if not data:
		return
	data.status = RunData.RunStatus.FAILED
	is_active = false
	run_failed.emit(data)


func complete_run() -> void:
	if not data:
		return
	data.status = RunData.RunStatus.COMPLETED
	is_active = false
	run_completed.emit(data)


func _generate_id() -> String:
	var chars: String = "abcdef0123456789"
	var id: String = ""
	for i in 16:
		id += chars[randi() % chars.length()]
	return id
