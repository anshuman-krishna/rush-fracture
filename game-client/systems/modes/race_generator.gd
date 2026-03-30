class_name RaceGenerator
extends RefCounted

# generates room sequences for race mode.
# each player gets an independent path of rooms.
# after race_rooms rooms, players meet for a pvp encounter.

const RACE_ROOMS: int = 4
const BASE_DIFFICULTY: float = 1.0
const DIFFICULTY_STEP: float = 0.25


static func generate(seed_value: int = -1) -> Array[RunData.RoomData]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()

	var sequence: Array[RunData.RoomData] = []

	# race path: 4 combat/varied rooms, no boss, escalating difficulty
	for i in RACE_ROOMS:
		var difficulty: float = BASE_DIFFICULTY + DIFFICULTY_STEP * i
		var type: RoomDefinitions.RoomType = _pick_race_room(rng, i)
		var room: RunData.RoomData = RunData.RoomData.new()
		room.id = "race_%d" % i
		room.type = type
		room.difficulty = difficulty
		room.enemy_budget = RoomDefinitions.enemy_budget_for(type, difficulty)
		room.reward_flag = i == 1 or i == 3  # upgrades at rooms 2 and 4
		sequence.append(room)

	return sequence


static func _pick_race_room(rng: RandomNumberGenerator, index: int) -> RoomDefinitions.RoomType:
	# first room is always combat
	if index == 0:
		return RoomDefinitions.RoomType.COMBAT

	var roll: float = rng.randf()

	# later rooms get harder types
	if index >= 3 and roll < 0.3:
		return RoomDefinitions.RoomType.ELITE
	if index >= 2 and roll < 0.4:
		return RoomDefinitions.RoomType.SWARM
	if roll < 0.25:
		return RoomDefinitions.RoomType.HAZARD

	return RoomDefinitions.RoomType.COMBAT
