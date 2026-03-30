class_name EnemyComposition
extends RefCounted

# determines which enemy types appear in a room based on room type and difficulty.
# early rooms keep it simple. later rooms introduce complex mixes.


static func get_composition(
	room_type: RoomDefinitions.RoomType,
	difficulty: float,
	budget: int,
) -> Array[EnemyTypes.Type]:
	var result: Array[EnemyTypes.Type] = []
	if budget <= 0:
		return result

	var available: Array = _available_types(difficulty)
	var weights: Dictionary = _type_weights(room_type, difficulty)

	for i in budget:
		var type: EnemyTypes.Type = _weighted_pick(available, weights)
		result.append(type)

	return result


static func _available_types(difficulty: float) -> Array[EnemyTypes.Type]:
	var types: Array[EnemyTypes.Type] = [EnemyTypes.Type.CHASER]

	if difficulty >= 1.2:
		types.append(EnemyTypes.Type.EXPLODER)
	if difficulty >= 1.4:
		types.append(EnemyTypes.Type.SHOOTER)
	if difficulty >= 1.5:
		types.append(EnemyTypes.Type.SNIPER)
	if difficulty >= 1.6:
		types.append(EnemyTypes.Type.DASHER)
	if difficulty >= 1.6:
		types.append(EnemyTypes.Type.SUPPORT)
	if difficulty >= 1.8:
		types.append(EnemyTypes.Type.TANK)
	if difficulty >= 1.8:
		types.append(EnemyTypes.Type.DISPLACER)

	return types


static func _type_weights(
	room_type: RoomDefinitions.RoomType,
	difficulty: float,
) -> Dictionary:
	match room_type:
		RoomDefinitions.RoomType.SWARM:
			return {
				EnemyTypes.Type.CHASER: 5,
				EnemyTypes.Type.EXPLODER: 3,
				EnemyTypes.Type.SHOOTER: 1,
				EnemyTypes.Type.DASHER: 2,
				EnemyTypes.Type.TANK: 0,
				EnemyTypes.Type.SNIPER: 0,
				EnemyTypes.Type.SUPPORT: 1,
				EnemyTypes.Type.DISPLACER: 1,
			}
		RoomDefinitions.RoomType.ELITE:
			return {
				EnemyTypes.Type.CHASER: 2,
				EnemyTypes.Type.EXPLODER: 1,
				EnemyTypes.Type.SHOOTER: 3,
				EnemyTypes.Type.DASHER: 2,
				EnemyTypes.Type.TANK: 3,
				EnemyTypes.Type.SNIPER: 2,
				EnemyTypes.Type.SUPPORT: 2,
				EnemyTypes.Type.DISPLACER: 2,
			}
		RoomDefinitions.RoomType.HAZARD:
			# hazard rooms favor ranged and tricky enemies
			return {
				EnemyTypes.Type.CHASER: 2,
				EnemyTypes.Type.EXPLODER: 3,
				EnemyTypes.Type.SHOOTER: 2,
				EnemyTypes.Type.DASHER: 1,
				EnemyTypes.Type.TANK: 1,
				EnemyTypes.Type.SNIPER: 3,
				EnemyTypes.Type.SUPPORT: 1,
				EnemyTypes.Type.DISPLACER: 2,
			}
		RoomDefinitions.RoomType.GAUNTLET:
			# gauntlet waves: high aggression
			return {
				EnemyTypes.Type.CHASER: 4,
				EnemyTypes.Type.EXPLODER: 3,
				EnemyTypes.Type.SHOOTER: 2,
				EnemyTypes.Type.DASHER: 3,
				EnemyTypes.Type.TANK: 1,
				EnemyTypes.Type.SNIPER: 1,
				EnemyTypes.Type.SUPPORT: 2,
				EnemyTypes.Type.DISPLACER: 2,
			}
		RoomDefinitions.RoomType.ELITE_CHAMBER:
			# elite chamber: fewer but stronger synergy picks
			return {
				EnemyTypes.Type.CHASER: 1,
				EnemyTypes.Type.EXPLODER: 1,
				EnemyTypes.Type.SHOOTER: 2,
				EnemyTypes.Type.DASHER: 2,
				EnemyTypes.Type.TANK: 3,
				EnemyTypes.Type.SNIPER: 3,
				EnemyTypes.Type.SUPPORT: 3,
				EnemyTypes.Type.DISPLACER: 3,
			}
		_:
			# combat / default — balanced
			var variety: float = clamp((difficulty - 1.0) * 2.0, 0.0, 1.0)
			return {
				EnemyTypes.Type.CHASER: int(5 - variety * 2),
				EnemyTypes.Type.EXPLODER: int(1 + variety * 2),
				EnemyTypes.Type.SHOOTER: int(1 + variety * 2),
				EnemyTypes.Type.DASHER: int(variety * 2),
				EnemyTypes.Type.TANK: int(variety * 1.5),
				EnemyTypes.Type.SNIPER: int(variety * 1.5),
				EnemyTypes.Type.SUPPORT: int(variety),
				EnemyTypes.Type.DISPLACER: int(variety),
			}


static func _weighted_pick(
	types: Array[EnemyTypes.Type],
	weights: Dictionary,
) -> EnemyTypes.Type:
	var total: int = 0
	for t in types:
		total += int(weights.get(t, 0))

	if total <= 0:
		return types[0]

	var roll: int = randi() % total
	var cumulative: int = 0
	for t in types:
		cumulative += int(weights.get(t, 0))
		if roll < cumulative:
			return t

	return types[0]
