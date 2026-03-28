class_name RoomDefinitions
extends RefCounted


enum RoomType {
	COMBAT,
	SWARM,
	ELITE,
	RECOVERY,
	TRANSITION,
}

enum RoomStatus {
	PENDING,
	ACTIVE,
	CLEARED,
}


static var type_names := {
	RoomType.COMBAT: "combat",
	RoomType.SWARM: "swarm",
	RoomType.ELITE: "elite",
	RoomType.RECOVERY: "recovery",
	RoomType.TRANSITION: "transition",
}


static func type_to_string(type: RoomType) -> String:
	return type_names.get(type, "unknown")


static func enemy_budget_for(type: RoomType, difficulty: float) -> int:
	var base := {
		RoomType.COMBAT: 5,
		RoomType.SWARM: 8,
		RoomType.ELITE: 3,
		RoomType.RECOVERY: 2,
		RoomType.TRANSITION: 0,
	}
	return int(base.get(type, 4) * difficulty)


static func has_reward(type: RoomType) -> bool:
	return type == RoomType.ELITE or type == RoomType.RECOVERY
