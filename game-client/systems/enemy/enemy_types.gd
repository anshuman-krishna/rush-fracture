class_name EnemyTypes
extends RefCounted

enum Type {
	CHASER,
	SHOOTER,
	DASHER,
	TANK,
	EXPLODER,
	SNIPER,
	SUPPORT,
	DISPLACER,
}


static var type_names: Dictionary = {
	Type.CHASER: "chaser",
	Type.SHOOTER: "shooter",
	Type.DASHER: "dasher",
	Type.TANK: "tank",
	Type.EXPLODER: "exploder",
	Type.SNIPER: "sniper",
	Type.SUPPORT: "support",
	Type.DISPLACER: "displacer",
}


static func type_to_string(type: Type) -> String:
	return type_names.get(type, "unknown")


static func scene_path(type: Type) -> String:
	return "res://scenes/enemies/%s.tscn" % type_to_string(type)
