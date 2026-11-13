class_name ModelLibrary
extends RefCounted

# pulls named pieces out of the multi-part model files (the obstacle set and
# the prop set) once, and hands out copies on demand. the old code
# instantiated the whole file again for every single obstacle it placed.

const SETS: Dictionary = {
	"obstacles": "res://assets/models/grafted-brood-obstacles.glb",
	"props": "res://assets/models/grafted-brood-props.glb",
}

var _roots: Dictionary = {}
var _parts: Dictionary = {}


## a fresh copy of one named piece, positioned at its own origin. null if missing.
func part(set_name: String, part_name: String) -> Node3D:
	var template: Node3D = _template(set_name, part_name)
	if not template:
		return null
	return template.duplicate() as Node3D


## several pieces under one parent, each keeping the offset it has relative
## to the first (an egg and the glowing core inside it, for example).
func group(set_name: String, part_names: Array) -> Node3D:
	var wrapper: Node3D = Node3D.new()
	for n: Variant in part_names:
		var p: Node3D = part(set_name, String(n))
		if p:
			wrapper.add_child(p)
	return wrapper


func has_part(set_name: String, part_name: String) -> bool:
	return _template(set_name, part_name) != null


## frees the cached templates. call when the owning scene goes away.
func free_all() -> void:
	for key: Variant in _parts:
		var n: Node3D = _parts[key]
		if is_instance_valid(n):
			n.free()
	_parts.clear()
	for key: Variant in _roots:
		var r: Node = _roots[key]
		if is_instance_valid(r):
			r.free()
	_roots.clear()


func _template(set_name: String, part_name: String) -> Node3D:
	var key: String = "%s/%s" % [set_name, part_name]
	if _parts.has(key):
		return _parts[key]
	var root: Node = _root(set_name)
	if not root:
		_parts[key] = null
		return null
	var found: Node3D = root.find_child(part_name, true, false) as Node3D
	if found:
		# pieces sit under an intermediate group in the imported scene; detach
		# from whatever the real parent is and zero the placement it had there
		found.get_parent().remove_child(found)
		found.owner = null
		found.position = Vector3.ZERO
		found.rotation = Vector3.ZERO
	_parts[key] = found
	return found


func _root(set_name: String) -> Node:
	if _roots.has(set_name):
		return _roots[set_name]
	var path: String = SETS.get(set_name, "")
	var root: Node = null
	if not path.is_empty() and ResourceLoader.exists(path):
		var scene: PackedScene = load(path) as PackedScene
		if scene:
			root = scene.instantiate()
	_roots[set_name] = root
	return root
