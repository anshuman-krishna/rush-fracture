class_name JumpPad
extends Area3D

# throws a player into the air along a fixed arc. arenas use these to link
# the floor to raised decks and to give you a fast way out of a corner.

const COOLDOWN: float = 0.35

var launch_velocity: Vector3 = Vector3(0, 21, 0)
var color: Color = Color(0.62, 1.0, 0.36)
var _cool: Dictionary = {}
var _ring: MeshInstance3D
var _pulse: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitorable = false
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 0.95
	shape.height = 1.0
	col.shape = shape
	col.position.y = 0.6
	add_child(col)

	_ring = Vfx.make_flat(0.8, color)
	_ring.scale = Vector3(1.15, 1.0, 1.15)
	_ring.position.y = 0.26
	add_child(_ring)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_pulse += delta * 3.0
	if _ring:
		var a: float = 0.55 + 0.45 * sin(_pulse)
		_ring.set_instance_shader_parameter("tint", Color(color.r, color.g, color.b, a))
	for key: Variant in _cool.keys():
		_cool[key] -= delta
		if _cool[key] <= 0.0:
			_cool.erase(key)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player") or not body.has_method("launch"):
		return
	if Game.is_online() and not body.is_multiplayer_authority():
		return
	var id: int = body.get_instance_id()
	if _cool.has(id):
		return
	_cool[id] = COOLDOWN
	# keep some of the speed they came in with, so pads chain into movement
	var carry: Vector3 = Vector3(body.velocity.x, 0, body.velocity.z) * 0.6
	body.launch(launch_velocity + carry, 0.15)
	Vfx.ring(global_position + Vector3(0, 0.2, 0), 2.6, color, 0.3, 0.8, 0.25)
	Game.sfx_at(&"jump_pad", global_position, -5.0, 0.08)
