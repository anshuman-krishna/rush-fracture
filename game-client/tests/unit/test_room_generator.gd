extends "res://tests/unit/test_case.gd"

# RoomGenerator: the run map. it must be fully determined by its seed, since
# co-op peers and daily runs rely on generating the same map independently.

const T: Dictionary = RoomDefinitions.RoomType


func _gen(mode: StringName, seed_value: int = 1234, ascension: int = 0, players: int = 1) -> Array:
	return RoomGenerator.generate({"mode": mode, "seed": seed_value, "ascension": ascension, "players": players})


func _signature(floors: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for options: Array in floors:
		for room: RunData.RoomData in options:
			parts.append("%s|%d|%s|%s|%.3f|%.3f|%d" % [room.id, room.type, room.reward, room.boss_id, room.difficulty, room.enemy_budget, room.seed_value])
	return ",".join(parts)


func test_same_seed_same_map() -> void:
	for mode: StringName in [RunData.MODE_STANDARD, RunData.MODE_SPRINT, RunData.MODE_ENDLESS, RunData.MODE_BOSS_RUSH]:
		eq(_signature(_gen(mode, 99)), _signature(_gen(mode, 99)), "%s is deterministic" % mode)


func test_different_seed_different_map() -> void:
	ne(_signature(_gen(RunData.MODE_STANDARD, 1)), _signature(_gen(RunData.MODE_STANDARD, 2)), "seeds differ")


func test_standard_structure() -> void:
	for seed_value: int in [1, 7, 42, 1000, 987654]:
		var floors: Array = _gen(RunData.MODE_STANDARD, seed_value)
		eq(floors.size(), 15, "standard has 15 floors (seed %d)" % seed_value)
		eq(floors[0].size(), 1, "first floor has no choice")
		eq((floors[0][0] as RunData.RoomData).type, T.COMBAT, "first floor is combat")
		var bosses: Array = []
		for i: int in floors.size():
			var options: Array = floors[i]
			check(options.size() >= 1 and options.size() <= 3, "floor %d has 1-3 options" % i)
			var first: RunData.RoomData = options[0]
			if first.type == T.BOSS:
				eq(options.size(), 1, "a boss floor has one option")
				bosses.append(first.boss_id)
				# the floor before a boss is the rest stop
				var rest: Array = floors[i - 1]
				eq(rest.size(), 2, "rest floor offers two options")
				var kinds: Array = [(rest[0] as RunData.RoomData).type, (rest[1] as RunData.RoomData).type]
				check(kinds.has(T.RECOVERY) and kinds.has(T.SHOP), "rest floor is sanctuary or shop")
		eq(bosses.size(), 3, "three bosses")
		eq(bosses[0], &"warden", "act one boss")
		check(bosses[1] == &"matriarch" or bosses[1] == &"stalker", "act two boss is matriarch or stalker")
		eq(bosses[2], &"titan", "act three boss")
		eq((floors[floors.size() - 1][0] as RunData.RoomData).type, T.BOSS, "run ends on a boss")


func test_no_duplicate_types_within_a_floor() -> void:
	var floors: Array = _gen(RunData.MODE_STANDARD, 555)
	for options: Array in floors:
		var seen: Dictionary = {}
		for room: RunData.RoomData in options:
			check(not seen.has(room.type), "floor offers distinct room types")
			seen[room.type] = true


func test_room_seeds_are_unique() -> void:
	var seen: Dictionary = {}
	var total: int = 0
	for options: Array in _gen(RunData.MODE_STANDARD, 31337):
		for room: RunData.RoomData in options:
			seen[room.seed_value] = true
			total += 1
	eq(seen.size(), total, "every room has its own layout seed")


func test_difficulty_never_drops() -> void:
	var last: float = 0.0
	for options: Array in _gen(RunData.MODE_STANDARD, 8):
		var d: float = (options[0] as RunData.RoomData).difficulty
		check(d >= last - 0.0001, "difficulty is non-decreasing")
		last = d
	check(last > 2.0, "the final room is well above base difficulty")


func test_every_act_offers_a_mutation() -> void:
	for seed_value: int in range(1, 30):
		var floors: Array = _gen(RunData.MODE_STANDARD, seed_value)
		var per_act: Dictionary = {}
		for options: Array in floors:
			for room: RunData.RoomData in options:
				if room.reward == RoomDefinitions.REWARD_MUTATION:
					per_act[room.act] = true
		for act: int in 3:
			check(per_act.has(act), "act %d offers a mutation (seed %d)" % [act + 1, seed_value])


func test_ascension_raises_difficulty_and_adds_the_core() -> void:
	var base: Array = _gen(RunData.MODE_STANDARD, 5, 0)
	var hard: Array = _gen(RunData.MODE_STANDARD, 5, 3)
	check((hard[0][0] as RunData.RoomData).difficulty > (base[0][0] as RunData.RoomData).difficulty, "ascension makes room one harder")
	eq(base.size(), 15, "no extra floor at ascension 0")
	eq(hard.size(), 16, "ascension 2+ adds a floor")
	eq((hard[15][0] as RunData.RoomData).boss_id, &"core", "the extra floor is the fracture core")


func test_player_count_scales_budget() -> void:
	var solo: RunData.RoomData = _gen(RunData.MODE_STANDARD, 5, 0, 1)[0][0]
	var duo: RunData.RoomData = _gen(RunData.MODE_STANDARD, 5, 0, 2)[0][0]
	check(duo.enemy_budget > solo.enemy_budget, "two players face a bigger budget")


func test_other_modes() -> void:
	eq(_gen(RunData.MODE_SPRINT).size(), 6, "sprint is six floors")
	var rush: Array = _gen(RunData.MODE_BOSS_RUSH)
	eq(rush.size(), 10, "boss rush is five prep rooms and five bosses")
	var rush_bosses: Array = []
	for options: Array in rush:
		var room: RunData.RoomData = options[0]
		if room.type == T.BOSS:
			rush_bosses.append(room.boss_id)
	eq(rush_bosses, [&"warden", &"stalker", &"matriarch", &"titan", &"core"], "boss rush order")
	var endless: Array = _gen(RunData.MODE_ENDLESS)
	eq(endless.size(), RoomGenerator.ENDLESS_ACTS * 5, "endless is generated twelve acts deep")


func test_every_boss_id_exists() -> void:
	for mode: StringName in [RunData.MODE_STANDARD, RunData.MODE_ENDLESS, RunData.MODE_BOSS_RUSH, RunData.MODE_SPRINT]:
		for options: Array in _gen(mode, 77, 3):
			for room: RunData.RoomData in options:
				if room.type == T.BOSS:
					check(BossDefs.exists(room.boss_id), "boss '%s' is defined" % room.boss_id)
				check(Biome.exists(room.biome), "biome '%s' is defined" % room.biome)


func test_race_generator() -> void:
	var a: Array = RaceGenerator.generate(42, 2)
	var b: Array = RaceGenerator.generate(42, 2)
	eq(_signature(a), _signature(b), "race map is deterministic")
	eq(a.size(), RaceGenerator.RACE_ROOMS, "race length")
	for options: Array in a:
		eq(options.size(), 1, "race floors have no choice")
		ne((options[0] as RunData.RoomData).type, T.BOSS, "race has no boss room")
