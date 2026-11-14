class_name Skins
extends RefCounted

# palette swaps for the Grafted Brood models.
#
# every model in the game is built from the same five named materials, so a
# skin is just five replacement materials plus an accent colour (used for
# tracers, trails and ui highlights). the same mechanism recolours weapons,
# the player body, and whole enemy strains per biome.

const MATERIAL_NAMES: PackedStringArray = ["chitin", "bone_carapace", "membrane", "biolum", "grafted_steel"]

# id -> { name, chitin, bone, membrane, glow, steel, accent, glow_energy }
const PALETTES: Dictionary = {
	&"default": {
		"name": "brood standard",
		"chitin": Color(0.345, 0.267, 0.318), "bone": Color(0.788, 0.725, 0.635),
		"membrane": Color(0.612, 0.29, 0.373), "glow": Color(0.616, 1.0, 0.361),
		"steel": Color(0.545, 0.588, 0.561), "accent": Color(0.62, 1.0, 0.36), "glow_energy": 1.7,
	},
	&"ember": {
		"name": "ember",
		"chitin": Color(0.16, 0.13, 0.13), "bone": Color(0.62, 0.5, 0.42),
		"membrane": Color(0.55, 0.16, 0.08), "glow": Color(1.0, 0.45, 0.1),
		"steel": Color(0.36, 0.3, 0.28), "accent": Color(1.0, 0.5, 0.15), "glow_energy": 2.2,
	},
	&"void": {
		"name": "void",
		"chitin": Color(0.07, 0.06, 0.11), "bone": Color(0.42, 0.4, 0.52),
		"membrane": Color(0.26, 0.1, 0.42), "glow": Color(0.72, 0.36, 1.0),
		"steel": Color(0.22, 0.22, 0.3), "accent": Color(0.75, 0.4, 1.0), "glow_energy": 2.4,
	},
	&"toxin": {
		"name": "toxin",
		"chitin": Color(0.2, 0.24, 0.12), "bone": Color(0.7, 0.72, 0.5),
		"membrane": Color(0.42, 0.5, 0.1), "glow": Color(0.92, 1.0, 0.2),
		"steel": Color(0.4, 0.44, 0.34), "accent": Color(0.9, 1.0, 0.25), "glow_energy": 2.0,
	},
	&"ivory": {
		"name": "ivory",
		"chitin": Color(0.82, 0.8, 0.76), "bone": Color(0.96, 0.94, 0.88),
		"membrane": Color(0.85, 0.62, 0.55), "glow": Color(1.0, 0.82, 0.35),
		"steel": Color(0.7, 0.7, 0.72), "accent": Color(1.0, 0.85, 0.4), "glow_energy": 1.8,
	},
	&"abyss": {
		"name": "abyss",
		"chitin": Color(0.06, 0.13, 0.2), "bone": Color(0.5, 0.66, 0.72),
		"membrane": Color(0.08, 0.32, 0.42), "glow": Color(0.25, 0.9, 1.0),
		"steel": Color(0.24, 0.36, 0.42), "accent": Color(0.3, 0.92, 1.0), "glow_energy": 2.2,
	},
	&"bloodline": {
		"name": "bloodline",
		"chitin": Color(0.26, 0.05, 0.07), "bone": Color(0.78, 0.66, 0.62),
		"membrane": Color(0.7, 0.08, 0.12), "glow": Color(1.0, 0.18, 0.22),
		"steel": Color(0.4, 0.3, 0.3), "accent": Color(1.0, 0.25, 0.28), "glow_energy": 2.3,
	},
	&"gilded": {
		"name": "gilded",
		"chitin": Color(0.2, 0.16, 0.08), "bone": Color(0.95, 0.78, 0.36),
		"membrane": Color(0.6, 0.4, 0.12), "glow": Color(1.0, 0.96, 0.75),
		"steel": Color(0.86, 0.68, 0.28), "accent": Color(1.0, 0.86, 0.4), "glow_energy": 2.0,
	},
	# enemy strains, one per act
	&"strain_marrow": {
		"name": "marrow strain",
		"chitin": Color(0.36, 0.36, 0.42), "bone": Color(0.9, 0.9, 0.86),
		"membrane": Color(0.42, 0.5, 0.62), "glow": Color(0.4, 0.85, 1.0),
		"steel": Color(0.62, 0.68, 0.72), "accent": Color(0.4, 0.85, 1.0), "glow_energy": 1.9,
	},
	&"strain_fracture": {
		"name": "fracture strain",
		"chitin": Color(0.26, 0.17, 0.36), "bone": Color(0.68, 0.58, 0.78),
		"membrane": Color(0.5, 0.12, 0.5), "glow": Color(1.0, 0.3, 0.85),
		"steel": Color(0.34, 0.3, 0.44), "accent": Color(1.0, 0.35, 0.85), "glow_energy": 2.3,
	},
	&"strain_bloom": {
		"name": "bloom strain",
		"chitin": Color(0.5, 0.36, 0.4), "bone": Color(0.97, 0.92, 0.88),
		"membrane": Color(0.9, 0.5, 0.6), "glow": Color(1.0, 0.72, 0.8),
		"steel": Color(0.7, 0.62, 0.64), "accent": Color(1.0, 0.7, 0.78), "glow_energy": 1.9,
	},
	&"strain_deep": {
		"name": "drowned strain",
		"chitin": Color(0.08, 0.2, 0.22), "bone": Color(0.55, 0.74, 0.72),
		"membrane": Color(0.1, 0.42, 0.4), "glow": Color(0.25, 1.0, 0.85),
		"steel": Color(0.26, 0.4, 0.42), "accent": Color(0.25, 1.0, 0.85), "glow_energy": 2.2,
	},
	&"strain_ash": {
		"name": "ash strain",
		"chitin": Color(0.17, 0.14, 0.13), "bone": Color(0.7, 0.6, 0.52),
		"membrane": Color(0.6, 0.2, 0.08), "glow": Color(1.0, 0.5, 0.15),
		"steel": Color(0.38, 0.32, 0.3), "accent": Color(1.0, 0.5, 0.15), "glow_energy": 2.3,
	},
	&"strain_elite": {
		"name": "elite strain",
		"chitin": Color(0.3, 0.06, 0.05), "bone": Color(0.9, 0.75, 0.5),
		"membrane": Color(0.75, 0.12, 0.05), "glow": Color(1.0, 0.4, 0.05),
		"steel": Color(0.5, 0.36, 0.3), "accent": Color(1.0, 0.45, 0.1), "glow_energy": 2.6,
	},
}

## skins a player can equip, in shop order
const PLAYER_SKINS: Array[StringName] = [&"default", &"ember", &"toxin", &"abyss", &"void", &"bloodline", &"ivory", &"gilded"]

static var _cache: Dictionary = {}


static func exists(id: StringName) -> bool:
	return PALETTES.has(id)


static func display_name(id: StringName) -> String:
	return PALETTES.get(id, PALETTES[&"default"]).get("name", String(id))


static func accent(id: StringName) -> Color:
	return PALETTES.get(id, PALETTES[&"default"]).get("accent", Color(0.62, 1.0, 0.36))


static func glow(id: StringName) -> Color:
	return PALETTES.get(id, PALETTES[&"default"]).get("glow", Color(0.62, 1.0, 0.36))


## recolours every mesh under `root` whose material is one of the five shared
## materials. "default" leaves the model's own materials in place.
static func apply(root: Node, id: StringName) -> void:
	if not root or id == &"default" or not PALETTES.has(id):
		return
	var mats: Dictionary = _materials_for(id)
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi: MeshInstance3D = n as MeshInstance3D
			if mi.mesh:
				for s: int in mi.mesh.get_surface_count():
					var src: Material = mi.mesh.surface_get_material(s)
					if src and mats.has(src.resource_name):
						mi.set_surface_override_material(s, mats[src.resource_name])
		for child: Node in n.get_children():
			stack.append(child)


## the material name a mesh surface was authored with ("biolum", "chitin"...),
## regardless of any override currently on it.
static func source_material_name(mi: MeshInstance3D, surface: int = 0) -> String:
	if not mi or not mi.mesh or surface >= mi.mesh.get_surface_count():
		return ""
	var src: Material = mi.mesh.surface_get_material(surface)
	return src.resource_name if src else ""


static func _materials_for(id: StringName) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var p: Dictionary = PALETTES[id]
	var energy: float = p.get("glow_energy", 1.8)
	var out: Dictionary = {}

	var chitin: StandardMaterial3D = StandardMaterial3D.new()
	chitin.albedo_color = p.chitin
	chitin.roughness = 0.48
	chitin.metallic = 0.2
	out["chitin"] = chitin

	var bone: StandardMaterial3D = StandardMaterial3D.new()
	bone.albedo_color = p.bone
	bone.roughness = 0.56
	bone.metallic = 0.05
	out["bone_carapace"] = bone

	var membrane: StandardMaterial3D = StandardMaterial3D.new()
	membrane.albedo_color = Color(p.membrane.r, p.membrane.g, p.membrane.b, 0.9)
	membrane.roughness = 0.26
	membrane.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	out["membrane"] = membrane

	var glow_mat: StandardMaterial3D = StandardMaterial3D.new()
	glow_mat.albedo_color = p.glow
	glow_mat.emission_enabled = true
	glow_mat.emission = p.glow
	glow_mat.emission_energy_multiplier = energy
	glow_mat.roughness = 0.2
	out["biolum"] = glow_mat

	var steel: StandardMaterial3D = StandardMaterial3D.new()
	steel.albedo_color = p.steel
	steel.roughness = 0.34
	steel.metallic = 0.38
	out["grafted_steel"] = steel

	for key: String in out:
		(out[key] as StandardMaterial3D).resource_name = key
	_cache[id] = out
	return out
