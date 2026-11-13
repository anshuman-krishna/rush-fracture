class_name RoomDefinitions
extends RefCounted

# what kinds of room exist, what they pay out, and how they are described on
# the path-choice screen.

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
	SHOP,
}

enum RoomStatus {
	PENDING,
	ACTIVE,
	CLEARED,
}

const REWARD_NONE: StringName = &"none"
const REWARD_UPGRADE: StringName = &"upgrade"
const REWARD_RARE: StringName = &"rare_upgrade"
const REWARD_MUTATION: StringName = &"mutation"
const REWARD_HEAL: StringName = &"heal"
const REWARD_ESSENCE: StringName = &"essence"
const REWARD_SHOP: StringName = &"shop"
const REWARD_BOSS: StringName = &"boss"

const INFO: Dictionary = {
	RoomType.COMBAT: {"name": "combat", "blurb": "a mixed pack.", "budget": 6.0, "reward": REWARD_UPGRADE, "danger": 1},
	RoomType.SWARM: {"name": "swarm", "blurb": "many small things, all at once.", "budget": 7.5, "reward": REWARD_UPGRADE, "danger": 1},
	RoomType.ELITE: {"name": "elite", "blurb": "one of them is much worse than the rest.", "budget": 5.0, "reward": REWARD_RARE, "danger": 2},
	RoomType.RECOVERY: {"name": "sanctuary", "blurb": "nothing here wants you dead. rest.", "budget": 0.0, "reward": REWARD_HEAL, "danger": 0},
	RoomType.TRANSITION: {"name": "passage", "blurb": "", "budget": 0.0, "reward": REWARD_NONE, "danger": 0},
	RoomType.BOSS: {"name": "boss", "blurb": "the way out is through it.", "budget": 0.0, "reward": REWARD_BOSS, "danger": 3},
	RoomType.HAZARD: {"name": "hazard", "blurb": "the floor is part of the fight.", "budget": 5.0, "reward": REWARD_UPGRADE, "danger": 2},
	RoomType.GAUNTLET: {"name": "gauntlet", "blurb": "three waves, no breaks.", "budget": 10.0, "reward": REWARD_RARE, "danger": 2},
	RoomType.ELITE_CHAMBER: {"name": "elite chamber", "blurb": "a brood mother and her guard.", "budget": 4.0, "reward": REWARD_MUTATION, "danger": 3},
	RoomType.SHOP: {"name": "tithe altar", "blurb": "spend essence. no fighting.", "budget": 0.0, "reward": REWARD_SHOP, "danger": 0},
}

const REWARD_NAMES: Dictionary = {
	REWARD_NONE: "nothing",
	REWARD_UPGRADE: "upgrade",
	REWARD_RARE: "rare upgrade",
	REWARD_MUTATION: "mutation",
	REWARD_HEAL: "heal",
	REWARD_ESSENCE: "essence cache",
	REWARD_SHOP: "shop",
	REWARD_BOSS: "upgrade + mutation",
}


static func type_to_string(type: RoomType) -> String:
	return INFO.get(type, {}).get("name", "unknown")


static func blurb(type: RoomType) -> String:
	return INFO.get(type, {}).get("blurb", "")


static func danger(type: RoomType) -> int:
	return INFO.get(type, {}).get("danger", 1)


static func default_reward(type: RoomType) -> StringName:
	return INFO.get(type, {}).get("reward", REWARD_NONE)


static func reward_name(reward: StringName) -> String:
	return REWARD_NAMES.get(reward, String(reward))


## spawn budget in points for a room of this type at this difficulty.
static func enemy_budget_for(type: RoomType, difficulty: float, player_count: int = 1) -> float:
	var base: float = INFO.get(type, {}).get("budget", 5.0)
	var scaled: float = base * (1.0 + maxf(0.0, difficulty - 1.0) * 0.7)
	return scaled * (1.0 + 0.6 * float(maxi(0, player_count - 1)))


## true for rooms with nothing to fight.
static func is_peaceful(type: RoomType) -> bool:
	return type == RoomType.RECOVERY or type == RoomType.SHOP or type == RoomType.TRANSITION
