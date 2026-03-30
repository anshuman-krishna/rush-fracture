class_name RoomDefinitions
extends RefCounted


enum RoomType {
	COMBAT,
	SWARM,
	ELITE,
	RECOVERY,
	TRANSITION,
	BOSS,
	HAZARD,
	GAUNTLET,
	ELITE_CHAMBER,
}

enum RoomStatus {
	PENDING,
	ACTIVE,
	CLEARED,
}


static var type_names: Dictionary = {
	RoomType.COMBAT: "combat",
	RoomType.SWARM: "swarm",
	RoomType.ELITE: "elite",
	RoomType.RECOVERY: "recovery",
	RoomType.TRANSITION: "transition",
	RoomType.BOSS: "boss",
	RoomType.HAZARD: "hazard",
	RoomType.GAUNTLET: "gauntlet",
	RoomType.ELITE_CHAMBER: "elite chamber",
}


static func type_to_string(type: RoomType) -> String:
	return type_names.get(type, "unknown")


static func enemy_budget_for(type: RoomType, difficulty: float) -> int:
	var base: Dictionary = {
		RoomType.COMBAT: 5,
		RoomType.SWARM: 8,
		RoomType.ELITE: 3,
		RoomType.RECOVERY: 2,
		RoomType.TRANSITION: 0,
		RoomType.BOSS: 0,
		RoomType.HAZARD: 4,
		RoomType.GAUNTLET: 10,
		RoomType.ELITE_CHAMBER: 3,
	}
	return int(base.get(type, 4) * difficulty)


static func has_reward(type: RoomType) -> bool:
	match type:
		RoomType.ELITE, RoomType.RECOVERY, RoomType.BOSS, RoomType.ELITE_CHAMBER:
			return true
	return false
