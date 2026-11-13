class_name RaceGenerator
extends RefCounted

# the short fixed map used by race and pvp-encounter matches: four rooms of
# rising difficulty, no boss and no path choices, so every player runs the
# same gauntlet before they meet.

const RACE_ROOMS: int = 4
const BASE_DIFFICULTY: float = 1.0
const DIFFICULTY_STEP: float = 0.25


## returns floors (each with a single room), in the shape RunManager expects.
static func generate(seed_value: int, players: int = 1) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var biome: StringName = Biome.for_act(rng.randi() % Biome.ACT_ORDER.size())
	var floors: Array = []
	for i: int in RACE_ROOMS:
		var difficulty: float = BASE_DIFFICULTY + DIFFICULTY_STEP * i
		var type: RoomDefinitions.RoomType = _pick_type(rng, i)
		var room: RunData.RoomData = RunData.RoomData.new()
		room.seed_value = rng.randi()
		room.id = "race_%d_%d" % [i, room.seed_value % 100000]
		room.type = type
		room.act = 0
		room.floor_index = i
		room.biome = biome
		room.difficulty = difficulty
		room.enemy_budget = RoomDefinitions.enemy_budget_for(type, difficulty, players)
		# upgrades after rooms two and four
		room.reward = RoomDefinitions.REWARD_UPGRADE if i == 1 or i == 3 else RoomDefinitions.REWARD_NONE
		floors.append([room])
	return floors


static func _pick_type(rng: RandomNumberGenerator, index: int) -> RoomDefinitions.RoomType:
	if index == 0:
		return RoomDefinitions.RoomType.COMBAT
	var roll: float = rng.randf()
	if index >= 3 and roll < 0.3:
		return RoomDefinitions.RoomType.ELITE
	if index >= 2 and roll < 0.4:
		return RoomDefinitions.RoomType.SWARM
	if roll < 0.25:
		return RoomDefinitions.RoomType.HAZARD
	return RoomDefinitions.RoomType.COMBAT
