class_name RoomGenerator
extends RefCounted

# builds the map for a run: a list of floors, each offering one to three
# rooms to choose between. fully determined by the seed, so co-op peers and
# daily runs all get the same map.
#
# a standard run is three acts. each act is a few choice floors, a rest stop
# (sanctuary or altar), then that act's boss. the other modes are built from
# the same pieces in a different order.

const BASE_DIFFICULTY: float = 1.0
const FLOOR_STEP: float = 0.13
const ACT_STEP: float = 0.1
const ASCENSION_STEP: float = 0.12
const CHOICE_FLOORS_PER_ACT: int = 3
const ENDLESS_ACTS: int = 12
const ONSLAUGHT_ROOMS: int = 8
const HUNT_FLOORS: int = 5
const DRAFT_PICKS: int = 6

const ACT_BOSSES: Array = [[&"warden", &"harrower"], [&"matriarch", &"stalker"], [&"titan", &"choir"]]
const ENDLESS_BOSSES: Array[StringName] = [&"warden", &"stalker", &"harrower", &"matriarch", &"choir", &"titan", &"core"]
const RUSH_BOSSES: Array[StringName] = [&"warden", &"harrower", &"stalker", &"matriarch", &"choir", &"titan", &"core"]
const ONSLAUGHT_TYPES: Array = [
	RoomDefinitions.RoomType.SWARM, RoomDefinitions.RoomType.GAUNTLET, RoomDefinitions.RoomType.COMBAT,
	RoomDefinitions.RoomType.GAUNTLET, RoomDefinitions.RoomType.ELITE, RoomDefinitions.RoomType.GAUNTLET,
	RoomDefinitions.RoomType.SWARM, RoomDefinitions.RoomType.GAUNTLET,
]


## cfg: mode, seed, ascension, players. returns floors (Array of Array[RoomData]).
static func generate(cfg: Dictionary) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(cfg.get("seed", 0))
	var mode: StringName = cfg.get("mode", RunData.MODE_STANDARD)
	var ascension: int = int(cfg.get("ascension", 0))
	var players: int = maxi(1, int(cfg.get("players", 1)))

	match mode:
		RunData.MODE_SPRINT, RunData.MODE_DEADLINE:
			return _build_acts(rng, 1, ascension, players, true, false)
		RunData.MODE_ENDLESS:
			return _build_acts(rng, ENDLESS_ACTS, ascension, players, false, true)
		RunData.MODE_BOSS_RUSH:
			return _build_boss_rush(rng, ascension, players)
		RunData.MODE_ONSLAUGHT:
			return _build_onslaught(rng, ascension, players)
		RunData.MODE_TEMPEST:
			return _build_tempest(rng, ascension, players)
		RunData.MODE_HUNT:
			return _build_hunt(rng, ascension, players)
		RunData.MODE_DRAFT:
			return _build_draft(rng, ascension, players)
	return _build_acts(rng, 3, ascension, players, false, false)


static func _build_acts(rng: RandomNumberGenerator, act_count: int, ascension: int, players: int,
		sprint: bool, endless: bool) -> Array:
	var floors: Array = []
	var floor_index: int = 0
	var biome_offset: int = rng.randi() % Biome.ACT_POOLS.size() if sprint else 0

	for act: int in act_count:
		var biome: StringName = Biome.pick(rng, act + biome_offset)
		var mutation_given: bool = false

		for step: int in CHOICE_FLOORS_PER_ACT + (1 if sprint else 0):
			var diff: float = _difficulty(floor_index, act, ascension, sprint)
			var options: Array = []
			if act == 0 and step == 0:
				# every run opens on the same gentle room
				options.append(_room(rng, floor_index, act, biome, RoomDefinitions.RoomType.COMBAT, diff, players))
			else:
				var count: int = 2 if rng.randf() < 0.45 else 3
				for type: RoomDefinitions.RoomType in _pick_types(rng, count, step, act):
					options.append(_room(rng, floor_index, act, biome, type, diff, players))
				# make sure each act offers a mutation somewhere before its boss
				if not mutation_given and step == CHOICE_FLOORS_PER_ACT - 1:
					var has_mutation: bool = false
					for r: RunData.RoomData in options:
						if r.reward == RoomDefinitions.REWARD_MUTATION:
							has_mutation = true
					if not has_mutation:
						(options[rng.randi() % options.size()] as RunData.RoomData).reward = RoomDefinitions.REWARD_MUTATION
			for r: RunData.RoomData in options:
				if r.reward == RoomDefinitions.REWARD_MUTATION:
					mutation_given = true
			floors.append(options)
			floor_index += 1

		# rest stop: choose between healing and spending
		var rest_diff: float = _difficulty(floor_index, act, ascension, sprint)
		floors.append([
			_room(rng, floor_index, act, biome, RoomDefinitions.RoomType.RECOVERY, rest_diff, players),
			_room(rng, floor_index, act, biome, RoomDefinitions.RoomType.SHOP, rest_diff, players),
		])
		floor_index += 1

		var boss_diff: float = _difficulty(floor_index, act, ascension, sprint) + 0.1
		var boss_room: RunData.RoomData = _room(rng, floor_index, act, biome, RoomDefinitions.RoomType.BOSS, boss_diff, players)
		if endless:
			boss_room.boss_id = ENDLESS_BOSSES[act % ENDLESS_BOSSES.size()]
		elif sprint:
			var pool: Array = ACT_BOSSES[posmod(act + biome_offset, ACT_BOSSES.size())]
			boss_room.boss_id = pool[rng.randi() % pool.size()]
		else:
			var act_pool: Array = ACT_BOSSES[mini(act, ACT_BOSSES.size() - 1)]
			boss_room.boss_id = act_pool[rng.randi() % act_pool.size()]
		floors.append([boss_room])
		floor_index += 1

	# high ascension: the last act's boss is not the end
	if not sprint and not endless and ascension >= 2:
		var last_act: int = act_count - 1
		var core_room: RunData.RoomData = _room(rng, floor_index, last_act, &"fracture", RoomDefinitions.RoomType.BOSS,
			_difficulty(floor_index, last_act, ascension, false) + 0.15, players)
		core_room.boss_id = &"core"
		floors.append([core_room])
	return floors


static func _build_boss_rush(rng: RandomNumberGenerator, ascension: int, players: int) -> Array:
	var floors: Array = []
	var floor_index: int = 0
	for i: int in RUSH_BOSSES.size():
		var biome: StringName = Biome.pick(rng, i)
		var diff: float = 1.3 + 0.24 * float(i) + ASCENSION_STEP * float(ascension)
		# an armory stop before each boss: a rare upgrade, no fight
		var prep: RunData.RoomData = _room(rng, floor_index, i, biome, RoomDefinitions.RoomType.RECOVERY, diff, players)
		prep.reward = RoomDefinitions.REWARD_RARE
		prep.metadata["double_reward"] = true
		floors.append([prep])
		floor_index += 1
		var boss_room: RunData.RoomData = _room(rng, floor_index, i, biome, RoomDefinitions.RoomType.BOSS, diff, players)
		boss_room.boss_id = RUSH_BOSSES[i]
		floors.append([boss_room])
		floor_index += 1
	return floors


## onslaught: eight fights in a row with no choice and no rest, then a boss.
static func _build_onslaught(rng: RandomNumberGenerator, ascension: int, players: int) -> Array:
	var floors: Array = []
	var biome: StringName = Biome.pick(rng, 0)
	for i: int in ONSLAUGHT_ROOMS:
		var act: int = i / 3
		if i % 3 == 0:
			biome = Biome.pick(rng, act)
		var diff: float = BASE_DIFFICULTY + 0.2 * float(i) + ASCENSION_STEP * float(ascension)
		var room: RunData.RoomData = _room(rng, i, act, biome, ONSLAUGHT_TYPES[i % ONSLAUGHT_TYPES.size()], diff, players)
		# always something to build with: an upgrade every room, a mutation every third
		room.reward = RoomDefinitions.REWARD_MUTATION if i % 3 == 2 else RoomDefinitions.REWARD_UPGRADE
		floors.append([room])
	var last: int = ONSLAUGHT_ROOMS
	var boss_room: RunData.RoomData = _room(rng, last, 2, biome, RoomDefinitions.RoomType.BOSS,
		BASE_DIFFICULTY + 0.2 * float(last) + ASCENSION_STEP * float(ascension), players)
	boss_room.boss_id = RUSH_BOSSES[rng.randi() % RUSH_BOSSES.size()]
	floors.append([boss_room])
	return floors


## tempest: two acts where every fight has a condition, the ground is thick
## with fields, and every reward is paid twice.
static func _build_tempest(rng: RandomNumberGenerator, ascension: int, players: int) -> Array:
	var floors: Array = _build_acts(rng, 2, ascension, players, false, false)
	for options: Array in floors:
		for room: RunData.RoomData in options:
			if room.is_peaceful() or room.is_boss():
				continue
			RoomConditions.assign(room, 1.0, true)
			room.metadata["dense_fields"] = true
			room.metadata["double_reward"] = true
	return floors


## hunt: every fight is an elite. five floors of them, a rest half way, a boss.
static func _build_hunt(rng: RandomNumberGenerator, ascension: int, players: int) -> Array:
	var floors: Array = []
	var floor_index: int = 0
	var biome: StringName = Biome.pick(rng, 1)
	for step: int in HUNT_FLOORS:
		if step == 3:
			biome = Biome.pick(rng, 2)
			floors.append([
				_room(rng, floor_index, 1, biome, RoomDefinitions.RoomType.RECOVERY, 1.0, players),
				_room(rng, floor_index, 1, biome, RoomDefinitions.RoomType.SHOP, 1.0, players),
			])
			floor_index += 1
		var act: int = 0 if step < 3 else 1
		var diff: float = BASE_DIFFICULTY + 0.18 * float(step) + ASCENSION_STEP * float(ascension)
		var options: Array = []
		options.append(_room(rng, floor_index, act, biome, RoomDefinitions.RoomType.ELITE, diff, players))
		options.append(_room(rng, floor_index, act, biome,
			RoomDefinitions.RoomType.ELITE_CHAMBER if step >= 1 else RoomDefinitions.RoomType.ELITE, diff, players))
		floors.append(options)
		floor_index += 1
	var boss_room: RunData.RoomData = _room(rng, floor_index, 1, biome, RoomDefinitions.RoomType.BOSS,
		BASE_DIFFICULTY + 0.18 * float(HUNT_FLOORS) + 0.2 + ASCENSION_STEP * float(ascension), players)
	var pool: Array = [&"stalker", &"matriarch", &"choir", &"harrower"]
	boss_room.boss_id = pool[rng.randi() % pool.size()]
	floors.append([boss_room])
	return floors


## draft: build first, fight after. an armory that hands out the whole build,
## then one hard act whose rooms pay only essence.
static func _build_draft(rng: RandomNumberGenerator, ascension: int, players: int) -> Array:
	var biome: StringName = Biome.pick(rng, 2)
	var armory: RunData.RoomData = _room(rng, 0, 0, biome, RoomDefinitions.RoomType.RECOVERY, 1.0, players)
	armory.reward = RoomDefinitions.REWARD_NONE
	armory.metadata["draft"] = DRAFT_PICKS
	var floors: Array = [[armory]]
	for options: Array in _build_acts(rng, 1, ascension, players, true, false):
		for room: RunData.RoomData in options:
			room.floor_index += 1
			room.biome = biome
			if room.is_peaceful():
				continue
			room.difficulty += 0.7
			room.enemy_budget = RoomDefinitions.enemy_budget_for(room.type, room.difficulty, players)
			if not room.is_boss():
				room.reward = RoomDefinitions.REWARD_ESSENCE
		floors.append(options)
	return floors


static func _difficulty(floor_index: int, act: int, ascension: int, sprint: bool) -> float:
	var step: float = FLOOR_STEP * (1.6 if sprint else 1.0)
	return BASE_DIFFICULTY + step * float(floor_index) + ACT_STEP * float(act) + ASCENSION_STEP * float(ascension)


static func _pick_types(rng: RandomNumberGenerator, count: int, step: int, act: int) -> Array:
	var weights: Dictionary = {
		RoomDefinitions.RoomType.COMBAT: 5.0,
		RoomDefinitions.RoomType.SWARM: 3.0,
		RoomDefinitions.RoomType.HAZARD: 2.0 if step >= 1 or act >= 1 else 0.0,
		RoomDefinitions.RoomType.ELITE: 2.5 if step >= 1 or act >= 1 else 0.0,
		RoomDefinitions.RoomType.GAUNTLET: 2.0 if step >= 1 or act >= 1 else 0.0,
		RoomDefinitions.RoomType.ELITE_CHAMBER: 1.5 if act >= 1 or step >= 2 else 0.0,
	}
	var picked: Array = []
	for i: int in count:
		var total: float = 0.0
		for t: Variant in weights:
			total += weights[t]
		if total <= 0.0:
			break
		var roll: float = rng.randf() * total
		for t: Variant in weights:
			roll -= weights[t]
			if roll <= 0.0:
				picked.append(t)
				weights[t] = 0.0
				break
	if picked.is_empty():
		picked.append(RoomDefinitions.RoomType.COMBAT)
	return picked


static func _room(rng: RandomNumberGenerator, floor_index: int, act: int, biome: StringName,
		type: RoomDefinitions.RoomType, difficulty: float, players: int) -> RunData.RoomData:
	var room: RunData.RoomData = RunData.RoomData.new()
	room.seed_value = rng.randi()
	room.id = "f%d_%s_%d" % [floor_index, RoomDefinitions.type_to_string(type).replace(" ", "_"), room.seed_value % 100000]
	room.type = type
	room.act = act
	room.floor_index = floor_index
	room.biome = biome
	room.difficulty = difficulty
	room.enemy_budget = RoomDefinitions.enemy_budget_for(type, difficulty, players)
	room.reward = RoomDefinitions.default_reward(type)
	if type == RoomDefinitions.RoomType.COMBAT and rng.randf() < 0.25:
		room.reward = RoomDefinitions.REWARD_ESSENCE
	RoomConditions.assign(room)
	return room
