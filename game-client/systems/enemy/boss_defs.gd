class_name BossDefs
extends RefCounted

# the boss roster and its factory, mirroring EnemyTypes.

const DEFS: Dictionary = {
	&"warden": {
		"name": "brood warden", "script": "warden", "model": "warden",
		"radius": 0.9, "height": 2.8, "health": 950, "speed": 2.8, "damage": 16,
		"intro": "it has been waiting at the door.",
	},
	&"stalker": {
		"name": "rift stalker", "script": "stalker", "model": "stalker",
		"radius": 0.6, "height": 3.4, "health": 1150, "speed": 6.5, "damage": 18,
		"intro": "you will not see it arrive.",
	},
	&"matriarch": {
		"name": "hive matriarch", "script": "matriarch", "model": "matriarch",
		"radius": 1.7, "height": 4.2, "health": 1600, "speed": 2.2, "damage": 20,
		"intro": "every one of them was hers.",
	},
	&"titan": {
		"name": "fracture titan", "script": "titan", "model": "titan",
		"radius": 1.3, "height": 6.0, "health": 2500, "speed": 3.1, "damage": 24,
		"intro": "the hive's last answer.",
	},
	&"core": {
		"name": "fracture core", "script": "core", "model": "core",
		"radius": 1.5, "height": 6.5, "health": 2200, "speed": 0.0, "damage": 22,
		"intro": "what all of it grew around.",
	},
}

static var _scripts: Dictionary = {}


static func exists(id: StringName) -> bool:
	return DEFS.has(id)


static func display_name(id: StringName) -> String:
	return DEFS.get(id, {}).get("name", String(id))


static func intro(id: StringName) -> String:
	return DEFS.get(id, {}).get("intro", "")


## builds a boss node, not yet in the tree. `health_scale` covers difficulty,
## ascension and player count.
static func create(id: StringName, health_scale: float = 1.0, damage_scale: float = 1.0, skin: StringName = &"default") -> BossBase:
	var def: Dictionary = DEFS.get(id, {})
	if def.is_empty():
		push_warning("unknown boss: %s" % id)
		return null
	var script: Script = _script_for(def.script)
	if not script:
		return null

	var boss: BossBase = script.new() as BossBase
	boss.boss_id = id
	boss.type_id = id
	boss.display_name = def.name
	boss.title = def.name
	boss.body_radius = def.radius
	boss.body_height = def.height
	boss.model_path = "res://assets/models/grafted-brood-%s.glb" % def.model
	boss.essence_value = 40
	boss.mass = 50.0
	boss.skin_id = skin
	boss.collision_layer = Layers.ENEMY
	boss.collision_mask = Layers.WORLD | Layers.PLAYER
	boss.stats.set_base(&"move_speed", def.speed)
	boss.stats.set_base(&"damage", def.damage)
	boss.stats.set_mul(&"damage", &"scale", damage_scale)

	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = def.radius
	capsule.height = maxf(def.height, def.radius * 2.0 + 0.01)
	col.shape = capsule
	col.position.y = capsule.height * 0.5
	boss.add_child(col)

	var hc: HealthComponent = HealthComponent.new()
	hc.name = "HealthComponent"
	hc.max_health = maxi(1, int(def.health * health_scale))
	boss.add_child(hc)
	return boss


static func _script_for(script_name: String) -> Script:
	if _scripts.has(script_name):
		return _scripts[script_name]
	var path: String = "res://systems/enemy/bosses/%s.gd" % script_name
	var s: Script = load(path) as Script
	if not s:
		push_error("boss script missing: %s" % path)
	_scripts[script_name] = s
	return s
