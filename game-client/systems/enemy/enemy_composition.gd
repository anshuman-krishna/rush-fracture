class_name EnemyComposition
extends RefCounted

# decides which enemies a room spawns. a room has a point budget; each enemy
# type has a cost and a minimum difficulty, and each room type and biome
# leans toward certain roles. early rooms stay simple, later ones mix
# ranged, area-denial and support so there is always something to prioritise.

# how much each room type favours an enemy (missing = 1.0, 0 = never)
const ROOM_WEIGHTS: Dictionary = {
	RoomDefinitions.RoomType.SWARM: {
		&"swarmling": 6.0, &"chaser": 3.0, &"exploder": 2.0, &"leaper": 1.0,
		&"tank": 0.0, &"sniper": 0.0, &"shielder": 0.2, &"broodmother": 0.6, &"spitter": 0.4,
	},
	RoomDefinitions.RoomType.ELITE: {
		&"swarmling": 0.4, &"tank": 1.6, &"shielder": 1.5, &"support": 1.5,
	},
	RoomDefinitions.RoomType.HAZARD: {
		&"spitter": 2.5, &"sniper": 2.0, &"shooter": 1.6, &"drone": 1.6, &"exploder": 1.5, &"chaser": 0.6,
	},
	RoomDefinitions.RoomType.GAUNTLET: {
		&"chaser": 1.6, &"dasher": 1.6, &"leaper": 1.5, &"exploder": 1.4, &"broodmother": 0.2,
	},
	RoomDefinitions.RoomType.ELITE_CHAMBER: {
		&"swarmling": 0.0, &"shielder": 2.0, &"support": 2.0, &"shooter": 1.5, &"broodmother": 0.0,
	},
}

# each act has a signature roster
const BIOME_WEIGHTS: Dictionary = {
	&"hatchery": {&"chaser": 1.6, &"swarmling": 1.6, &"exploder": 1.4, &"spitter": 1.5, &"leaper": 1.4, &"broodmother": 1.3},
	&"marrow": {&"shooter": 1.6, &"shielder": 1.7, &"sniper": 1.5, &"drone": 1.6, &"support": 1.4, &"tank": 1.2},
	&"fracture": {&"displacer": 1.8, &"dasher": 1.6, &"tank": 1.4, &"drone": 1.3, &"sniper": 1.2, &"exploder": 1.2},
}

const BASE_WEIGHTS: Dictionary = {
	&"swarmling": 1.2, &"chaser": 3.0, &"exploder": 1.6, &"shooter": 2.0, &"spitter": 1.5,
	&"leaper": 1.5, &"dasher": 1.4, &"sniper": 1.1, &"drone": 1.3, &"support": 0.9,
	&"shielder": 1.1, &"displacer": 1.1, &"tank": 0.9, &"broodmother": 0.35,
}

const MAX_PER_ROOM: int = 26
const MAX_SUPPORTS: int = 2
const MAX_BROODMOTHERS: int = 1


## returns [{type: StringName, affix: Variant}] for the room. `affix` is null
## for a normal enemy or an elite affix id.
static func build(room: RunData.RoomData, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var budget: float = room.enemy_budget
	if budget <= 0.0:
		return out

	var weights: Dictionary = _weights_for(room)
	if weights.is_empty():
		return out
	var counts: Dictionary = {}

	# elite rooms open with their elite, paid for out of the budget
	if room.type == RoomDefinitions.RoomType.ELITE:
		var elite_type: StringName = _pick(weights, rng, counts, 99.0, 1.0)
		out.append({"type": elite_type, "affix": EnemyTypes.random_affix(rng)})
		budget -= EnemyTypes.cost(elite_type) * 1.5
	elif room.type == RoomDefinitions.RoomType.ELITE_CHAMBER:
		out.append({"type": &"broodmother", "affix": EnemyTypes.random_affix(rng)})

	# later rooms sprinkle in the odd elite on their own
	var elite_chance: float = clampf((room.difficulty - 1.6) * 0.07, 0.0, 0.18)

	var guard: int = 0
	while budget > 0.2 and out.size() < MAX_PER_ROOM and guard < 200:
		guard += 1
		var type: StringName = _pick(weights, rng, counts, budget + 0.6, 0.0)
		if type == &"":
			break
		var affix: Variant = null
		var cost: float = EnemyTypes.cost(type)
		if type != &"swarmling" and rng.randf() < elite_chance and budget >= cost * 2.0:
			affix = EnemyTypes.random_affix(rng)
			cost *= 2.0
		# broodlings arrive in clutches
		var copies: int = 3 if type == &"swarmling" else 1
		for c: int in copies:
			if budget <= 0.0 and c > 0:
				break
			out.append({"type": type, "affix": affix})
			budget -= cost
			counts[type] = counts.get(type, 0) + 1
	return out


## splits a composition into waves: a first wave and reinforcements.
static func split_waves(entries: Array[Dictionary], wave_count: int) -> Array:
	var waves: Array = []
	if entries.is_empty():
		return waves
	wave_count = clampi(wave_count, 1, entries.size())
	for i: int in wave_count:
		waves.append([])
	# elites and heavies lead; the rest are dealt round-robin
	for i: int in entries.size():
		var w: int = 0 if entries[i].affix != null else i % wave_count
		waves[w].append(entries[i])
	var packed: Array = []
	for w: Array in waves:
		if not w.is_empty():
			packed.append(w)
	return packed


static func _weights_for(room: RunData.RoomData) -> Dictionary:
	var room_w: Dictionary = ROOM_WEIGHTS.get(room.type, {})
	var biome_w: Dictionary = BIOME_WEIGHTS.get(room.biome, {})
	var out: Dictionary = {}
	for type: StringName in BASE_WEIGHTS:
		if EnemyTypes.min_difficulty(type) > room.difficulty + 0.001:
			continue
		var w: float = BASE_WEIGHTS[type] * float(room_w.get(type, 1.0)) * float(biome_w.get(type, 1.0))
		if w > 0.0:
			out[type] = w
	return out


static func _pick(weights: Dictionary, rng: RandomNumberGenerator, counts: Dictionary, max_cost: float, min_cost: float) -> StringName:
	var total: float = 0.0
	var eligible: Dictionary = {}
	for type: StringName in weights:
		var cost: float = EnemyTypes.cost(type)
		if cost > max_cost or cost < min_cost:
			continue
		if type == &"support" and counts.get(type, 0) >= MAX_SUPPORTS:
			continue
		if type == &"broodmother" and counts.get(type, 0) >= MAX_BROODMOTHERS:
			continue
		eligible[type] = weights[type]
		total += weights[type]
	if total <= 0.0:
		return &""
	var roll: float = rng.randf() * total
	for type: StringName in eligible:
		roll -= eligible[type]
		if roll <= 0.0:
			return type
	return eligible.keys()[0]
