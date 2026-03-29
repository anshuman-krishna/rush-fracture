class_name RoomGenerator
extends RefCounted

# generates a structured room sequence for a run.
# designed to feel paced, not random.

const MIN_ROOMS := 5
const MAX_ROOMS := 8
const BASE_DIFFICULTY := 1.0
const DIFFICULTY_STEP := 0.2


static func generate(seed_value: int = -1) -> Array[RunData.RoomData]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()

	var room_count: int = rng.randi_range(MIN_ROOMS, MAX_ROOMS)
	var sequence: Array[RunData.RoomData] = []

	# first room is always an easy combat room
	sequence.append(_create_room(
		0, RoomDefinitions.RoomType.COMBAT, BASE_DIFFICULTY
	))

	# generate middle rooms
	var elite_placed: bool = false
	var recovery_count: int = 0
	var last_type: RoomDefinitions.RoomType = RoomDefinitions.RoomType.COMBAT

	for i in range(1, room_count - 1):
		var progress: float = float(i) / float(room_count - 1)
		var difficulty: float = BASE_DIFFICULTY + DIFFICULTY_STEP * i
		var type: RoomDefinitions.RoomType = _pick_room_type(rng, progress, last_type, elite_placed, recovery_count)

		if type == RoomDefinitions.RoomType.ELITE:
			elite_placed = true
		if type == RoomDefinitions.RoomType.RECOVERY:
			recovery_count += 1

		sequence.append(_create_room(i, type, difficulty))
		last_type = type

	# final room is the boss encounter
	var final_difficulty: float = BASE_DIFFICULTY + DIFFICULTY_STEP * (room_count - 1) + 0.3
	sequence.append(_create_room(
		room_count - 1, RoomDefinitions.RoomType.BOSS, final_difficulty
	))

	return sequence


static func _pick_room_type(
	rng: RandomNumberGenerator,
	progress: float,
	last_type: RoomDefinitions.RoomType,
	elite_placed: bool,
	recovery_count: int,
) -> RoomDefinitions.RoomType:
	var roll: float = rng.randf()

	# elite: once per run, not too early, not after recovery
	if not elite_placed and progress > 0.4 and progress < 0.85:
		if roll < 0.25 and last_type != RoomDefinitions.RoomType.RECOVERY:
			return RoomDefinitions.RoomType.ELITE

	# recovery: max 1, not back-to-back, mid-run only
	if recovery_count < 1 and progress > 0.3 and progress < 0.7:
		if roll > 0.75 and last_type != RoomDefinitions.RoomType.RECOVERY:
			return RoomDefinitions.RoomType.RECOVERY

	# swarm: avoid consecutive swarms
	if roll < 0.35 and last_type != RoomDefinitions.RoomType.SWARM:
		return RoomDefinitions.RoomType.SWARM

	return RoomDefinitions.RoomType.COMBAT


static func _create_room(
	index: int,
	type: RoomDefinitions.RoomType,
	difficulty: float,
) -> RunData.RoomData:
	var room: RunData.RoomData = RunData.RoomData.new()
	room.id = "room_%d" % index
	room.type = type
	room.difficulty = difficulty
	room.enemy_budget = RoomDefinitions.enemy_budget_for(type, difficulty)
	room.reward_flag = RoomDefinitions.has_reward(type)
	return room
