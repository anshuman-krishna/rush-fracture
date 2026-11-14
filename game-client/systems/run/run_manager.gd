class_name RunManager
extends Node

# owns the current RunData and moves the run from floor to floor. it knows
# nothing about combat; game_manager tells it when a room is cleared and
# which path was chosen.

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


## cfg: mode, seed, ascension, players (see RoomGenerator.generate).
func start_run(cfg: Dictionary) -> void:
	start_run_with_floors(RoomGenerator.generate(cfg), cfg)


## starts a run on a ready-made map (race/versus sequences, tests).
func start_run_with_floors(floors: Array, cfg: Dictionary = {}) -> void:
	data = RunData.new()
	data.run_id = _generate_id()
	data.mode = cfg.get("mode", RunData.MODE_STANDARD)
	data.seed_value = int(cfg.get("seed", 0))
	data.ascension = int(cfg.get("ascension", 0))
	data.difficulty = Difficulty.valid(cfg.get("difficulty", ""))
	data.floors = floors
	data.room_sequence.clear()
	for options: Array in floors:
		data.room_sequence.append(options[0] as RunData.RoomData)
	data.status = RunData.RunStatus.ACTIVE
	is_active = true
	run_started.emit(data)
	enter_current_room()


## wraps a flat list of rooms as single-option floors.
func start_run_with_sequence(sequence: Array[RunData.RoomData], cfg: Dictionary = {}) -> void:
	var floors: Array = []
	for room: RunData.RoomData in sequence:
		floors.append([room])
	start_run_with_floors(floors, cfg)


func enter_current_room() -> void:
	var room: RunData.RoomData = data.current_room()
	if not room:
		return
	room.status = RoomDefinitions.RoomStatus.ACTIVE
	room_entered.emit(room)


func on_room_enemies_cleared() -> void:
	if not data:
		return
	var room: RunData.RoomData = data.current_room()
	if not room or room.status != RoomDefinitions.RoomStatus.ACTIVE:
		return
	room.status = RoomDefinitions.RoomStatus.CLEARED
	data.rooms_cleared += 1
	if room.is_boss():
		data.bosses_defeated += 1
	room_cleared.emit(room)


## moves on to the next floor, taking `option_index` of its choices.
func advance_to_next_room(option_index: int = 0) -> void:
	if not data or data.status != RunData.RunStatus.ACTIVE:
		return
	if data.is_final_room():
		complete_run()
		return
	data.choose_next(option_index)
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


func add_essence(amount: int) -> void:
	if not data or amount == 0:
		return
	data.essence = maxi(0, data.essence + amount)
	if amount > 0:
		data.essence_earned += amount


func fail_run() -> void:
	if not data or data.status != RunData.RunStatus.ACTIVE:
		return
	data.status = RunData.RunStatus.FAILED
	is_active = false
	run_failed.emit(data)


func complete_run() -> void:
	# guarded against a second call: in co-op the host and a client can both
	# reach "nothing left to do" and ask for completion at nearly the same time.
	if not data or data.status != RunData.RunStatus.ACTIVE:
		return
	data.status = RunData.RunStatus.COMPLETED
	is_active = false
	run_completed.emit(data)


func _generate_id() -> String:
	var chars: String = "abcdef0123456789"
	var id: String = ""
	for i: int in 16:
		id += chars[randi() % chars.length()]
	return id
