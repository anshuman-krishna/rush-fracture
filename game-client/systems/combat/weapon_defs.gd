class_name WeaponDefs
extends RefCounted

# the weapon catalogue: what exists, what script drives it, how it is unlocked.
# the armory, the loadout, the hud and the unlock shop all read from here.

const DEFAULT_LOADOUT: Array[StringName] = [&"pulse_rifle", &"scatter_cannon", &"beam_emitter"]
const LOADOUT_SIZE: int = 3

const CATALOG: Dictionary = {
	&"pulse_rifle": {
		"name": "grafted carbine",
		"role": "all-rounder",
		"script": "res://systems/combat/weapons/pulse_rifle.gd",
		"description": "accurate automatic fire at any range. rewards weak-point hits.",
		"cost": 0, "requirement": "",
	},
	&"scatter_cannon": {
		"name": "sporecaster",
		"role": "close range",
		"script": "res://systems/combat/weapons/scatter_cannon.gd",
		"description": "seven pellets per blast. devastating up close, useless far away.",
		"cost": 0, "requirement": "",
	},
	&"beam_emitter": {
		"name": "stinger",
		"role": "sustained",
		"script": "res://systems/combat/weapons/beam_emitter.gd",
		"description": "continuous beam that never misses. overheats if held too long.",
		"cost": 0, "requirement": "",
	},
	&"needler": {
		"name": "needle hive",
		"role": "ramping",
		"script": "res://systems/combat/weapons/needler.gd",
		"description": "sprays quills that embed in targets. enough of them detonate together.",
		"cost": 140, "requirement": "total_kills >= 150",
	},
	&"spore_launcher": {
		"name": "bile mortar",
		"role": "area",
		"script": "res://systems/combat/weapons/spore_launcher.gd",
		"description": "lobs an explosive spore. clears packs; mind your own feet.",
		"cost": 180, "requirement": "runs_completed >= 1",
	},
	&"rail_lance": {
		"name": "marrow lance",
		"role": "precision",
		"script": "res://systems/combat/weapons/rail_lance.gd",
		"description": "hold to charge, release to pierce everything in a line.",
		"cost": 220, "requirement": "bosses_defeated >= 1",
	},
	&"arc_caster": {
		"name": "synapse coil",
		"role": "crowd",
		"script": "res://systems/combat/weapons/arc_caster.gd",
		"description": "lightning that finds its own targets and chains between them.",
		"cost": 260, "requirement": "best_combo >= 12",
	},
	&"ripper": {
		"name": "ripper",
		"role": "ricochet",
		"script": "res://systems/combat/weapons/ripper.gd",
		"description": "throws a saw disc that bounces off walls and cuts through bodies.",
		"cost": 300, "requirement": "total_kills >= 800",
	},
}

## display order in the armory
const ORDER: Array[StringName] = [
	&"pulse_rifle", &"scatter_cannon", &"beam_emitter", &"needler",
	&"spore_launcher", &"rail_lance", &"arc_caster", &"ripper",
]


static func exists(id: StringName) -> bool:
	return CATALOG.has(id)


static func display_name(id: StringName) -> String:
	return CATALOG.get(id, {}).get("name", String(id))


static func is_free(id: StringName) -> bool:
	return CATALOG.get(id, {}).get("cost", 0) == 0


static func create(id: StringName) -> BaseWeapon:
	var def: Dictionary = CATALOG.get(id, {})
	if def.is_empty():
		push_warning("unknown weapon id: %s" % id)
		return null
	var script: Script = load(def.script) as Script
	if not script:
		push_error("weapon script missing: %s" % def.script)
		return null
	var weapon: BaseWeapon = script.new() as BaseWeapon
	weapon.name = String(id).to_pascal_case()
	return weapon


## cleans a saved loadout: drops unknown or duplicate ids and pads with defaults.
static func sanitize_loadout(ids: Array, owned: Callable = Callable()) -> Array[StringName]:
	var out: Array[StringName] = []
	for raw: Variant in ids:
		var id: StringName = StringName(String(raw))
		if not CATALOG.has(id) or out.has(id):
			continue
		if owned.is_valid() and not owned.call(id):
			continue
		out.append(id)
		if out.size() >= LOADOUT_SIZE:
			break
	for id: StringName in DEFAULT_LOADOUT:
		if out.size() >= LOADOUT_SIZE:
			break
		if not out.has(id):
			out.append(id)
	return out
