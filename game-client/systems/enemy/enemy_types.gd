class_name EnemyTypes
extends RefCounted

# the enemy roster as data, and the factory that turns an id into a ready
# node. adding an enemy is one table row plus one behaviour script; there are
# no per-enemy scene files to keep in sync.
#
# cost      spawn budget points this enemy uses in a room
# min_diff  room difficulty at which it starts appearing
# weak      fraction of body height above which hits are weak-point hits

const DEFS: Dictionary = {
	&"swarmling": {
		"name": "broodling", "script": "swarmling", "radius": 0.25, "height": 0.45,
		"health": 14, "speed": 7.6, "damage": 5, "cost": 0.35, "min_diff": 1.0,
		"essence": 1, "mass": 0.4, "weak": 0.0,
	},
	&"chaser": {
		"name": "ripper hound", "script": "chaser", "radius": 0.42, "height": 1.05,
		"health": 45, "speed": 5.8, "damage": 10, "cost": 1.0, "min_diff": 1.0,
		"essence": 2, "mass": 1.0, "weak": 0.7,
	},
	&"exploder": {
		"name": "swelling spore", "script": "exploder", "radius": 0.42, "height": 1.1,
		"health": 30, "speed": 6.6, "damage": 30, "cost": 1.0, "min_diff": 1.15,
		"essence": 2, "mass": 0.8, "weak": 0.0,
	},
	&"shooter": {
		"name": "spore marksman", "script": "shooter", "radius": 0.4, "height": 1.8,
		"health": 50, "speed": 4.0, "damage": 9, "cost": 1.5, "min_diff": 1.25,
		"essence": 3, "mass": 1.0, "weak": 0.8,
	},
	&"spitter": {
		"name": "bile spitter", "script": "spitter", "radius": 0.55, "height": 1.2,
		"health": 60, "speed": 3.2, "damage": 14, "cost": 1.8, "min_diff": 1.35,
		"essence": 3, "mass": 1.4, "weak": 0.0,
	},
	&"leaper": {
		"name": "tendon leaper", "script": "leaper", "radius": 0.42, "height": 0.9,
		"health": 55, "speed": 4.6, "damage": 16, "cost": 1.6, "min_diff": 1.45,
		"essence": 3, "mass": 0.9, "weak": 0.65,
	},
	&"dasher": {
		"name": "blink fang", "script": "dasher", "radius": 0.4, "height": 1.3,
		"health": 55, "speed": 3.8, "damage": 18, "cost": 1.8, "min_diff": 1.5,
		"essence": 3, "mass": 0.9, "weak": 0.75,
	},
	&"sniper": {
		"name": "watcher stalk", "script": "sniper", "radius": 0.35, "height": 2.2,
		"health": 40, "speed": 2.6, "damage": 26, "cost": 2.0, "min_diff": 1.5,
		"essence": 4, "mass": 0.8, "weak": 0.8,
	},
	&"drone": {
		"name": "sting drone", "script": "drone", "radius": 0.4, "height": 0.8,
		"health": 35, "speed": 5.2, "damage": 7, "cost": 1.5, "min_diff": 1.6,
		"essence": 3, "mass": 0.6, "weak": 0.0, "flying": true,
	},
	&"support": {
		"name": "choir spore", "script": "support", "radius": 0.45, "height": 1.6,
		"health": 60, "speed": 3.5, "damage": 5, "cost": 2.0, "min_diff": 1.6,
		"essence": 4, "mass": 1.0, "weak": 0.75,
	},
	&"shielder": {
		"name": "carapace bulwark", "script": "shielder", "radius": 0.5, "height": 1.95,
		"health": 110, "speed": 3.0, "damage": 20, "cost": 2.5, "min_diff": 1.7,
		"essence": 5, "mass": 2.2, "weak": 0.85,
	},
	&"displacer": {
		"name": "phase wraith", "script": "displacer", "radius": 0.4, "height": 1.7,
		"health": 70, "speed": 4.2, "damage": 16, "cost": 2.2, "min_diff": 1.8,
		"essence": 4, "mass": 0.9, "weak": 0.78,
	},
	&"tank": {
		"name": "brood hulk", "script": "tank", "radius": 0.7, "height": 2.5,
		"health": 220, "speed": 2.6, "damage": 28, "cost": 3.5, "min_diff": 1.8,
		"essence": 7, "mass": 4.0, "weak": 0.82,
	},
	&"broodmother": {
		"name": "brood mother", "script": "broodmother", "radius": 1.1, "height": 1.8,
		"health": 260, "speed": 1.7, "damage": 12, "cost": 5.0, "min_diff": 2.0,
		"essence": 10, "mass": 6.0, "weak": 0.0,
	},
}

const ELITE_AFFIXES: Array[StringName] = [&"volatile", &"regenerating", &"swift", &"shielded", &"vampiric"]

static var _scripts: Dictionary = {}


static func exists(id: StringName) -> bool:
	return DEFS.has(id)


static func display_name(id: StringName) -> String:
	return DEFS.get(id, {}).get("name", String(id))


static func cost(id: StringName) -> float:
	return DEFS.get(id, {}).get("cost", 1.0)


static func min_difficulty(id: StringName) -> float:
	return DEFS.get(id, {}).get("min_diff", 1.0)


static func all_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in DEFS:
		out.append(id)
	return out


## builds an enemy node, not yet in the tree. the caller positions and adds it.
static func create(id: StringName, room_difficulty: float = 1.0, elite_affix: Variant = null, skin: StringName = &"default") -> EnemyBase:
	var def: Dictionary = DEFS.get(id, {})
	if def.is_empty():
		push_warning("unknown enemy type: %s" % id)
		return null
	var script: Script = _script_for(def.script)
	if not script:
		return null

	var enemy: EnemyBase = script.new() as EnemyBase
	enemy.type_id = id
	enemy.display_name = def.name
	enemy.body_radius = def.radius
	enemy.body_height = def.height
	enemy.model_path = "res://assets/models/grafted-brood-%s.glb" % String(id)
	enemy.essence_value = def.essence
	enemy.mass = def.mass
	enemy.weak_ratio = def.weak
	enemy.flying = def.get("flying", false)
	enemy.skin_id = skin
	enemy.collision_layer = Layers.ENEMY
	enemy.collision_mask = Layers.WORLD | Layers.PLAYER
	enemy.stats.set_base(&"move_speed", def.speed)
	enemy.stats.set_base(&"damage", def.damage)

	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = def.radius
	capsule.height = maxf(def.height, def.radius * 2.0 + 0.01)
	col.shape = capsule
	col.position.y = 0.0 if enemy.flying else capsule.height * 0.5
	enemy.add_child(col)

	var hc: HealthComponent = HealthComponent.new()
	hc.name = "HealthComponent"
	hc.max_health = def.health
	enemy.add_child(hc)

	enemy.scale_for(room_difficulty, hc)
	if elite_affix != null:
		enemy.make_elite(StringName(String(elite_affix)))
	return enemy


static func random_affix(rng: RandomNumberGenerator = null) -> StringName:
	var idx: int = rng.randi() % ELITE_AFFIXES.size() if rng else randi() % ELITE_AFFIXES.size()
	return ELITE_AFFIXES[idx]


static func _script_for(script_name: String) -> Script:
	if _scripts.has(script_name):
		return _scripts[script_name]
	var path: String = "res://systems/enemy/types/%s.gd" % script_name
	var s: Script = load(path) as Script
	if not s:
		push_error("enemy script missing: %s" % path)
	_scripts[script_name] = s
	return s
