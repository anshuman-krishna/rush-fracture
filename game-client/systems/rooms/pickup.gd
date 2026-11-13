class_name Pickup
extends Node3D

# something an enemy dropped: essence (the in-run currency) or health.
# it pops out, settles, then flies to the player once they are close.
#
# drops are per-player: each peer spawns its own copy of a drop and only its
# own player can collect it, so nobody races a teammate for loot.

signal collected(kind: StringName, value: int)

const KIND_ESSENCE: StringName = &"essence"
const KIND_HEALTH: StringName = &"health"
const LIFETIME: float = 30.0
const MAGNET_SPEED: float = 26.0
const COLLECT_DISTANCE: float = 1.1

var kind: StringName = KIND_ESSENCE
var value: int = 1

var _velocity: Vector3 = Vector3.ZERO
var _age: float = 0.0
var _settled: bool = false
var _attracted: bool = false
var _mesh: MeshInstance3D
var _spin: float = 0.0
var _floor_y: float = 0.45


## pulls this pickup to the player from anywhere (used when a room is cleared).
func attract() -> void:
	_attracted = true
	_age = maxf(_age, 0.4)


static func create(p_kind: StringName, p_value: int) -> Pickup:
	var p: Pickup = Pickup.new()
	p.kind = p_kind
	p.value = p_value
	return p


func _ready() -> void:
	var color: Color = Color(0.62, 1.0, 0.36) if kind == KIND_ESSENCE else Color(1.0, 0.3, 0.35)
	_mesh = MeshInstance3D.new()
	if kind == KIND_ESSENCE:
		var prism: PrismMesh = PrismMesh.new()
		prism.size = Vector3(0.22, 0.34, 0.22)
		_mesh.mesh = prism
	else:
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.22
		sphere.height = 0.44
		sphere.radial_segments = 10
		sphere.rings = 5
		_mesh.mesh = sphere
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	_mesh.material_override = mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)

	var a: float = randf() * TAU
	_velocity = Vector3(cos(a) * randf_range(1.5, 4.0), randf_range(4.0, 7.0), sin(a) * randf_range(1.5, 4.0))
	_spin = randf() * TAU
	_floor_y = maxf(0.45, global_position.y * 0.0 + 0.45)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return
	_spin += delta * 3.0
	_mesh.rotation.y = _spin

	var player: CharacterBody3D = Game.local_player()
	if is_instance_valid(player) and player.get("is_dead") != true and _age > 0.35:
		var to_player: Vector3 = player.global_position - global_position
		var dist: float = to_player.length()
		var reach: float = player.stats.value(&"pickup_radius") if "stats" in player else 3.5
		# health only comes to you if you can use it
		var wanted: bool = kind != KIND_HEALTH or player.health < player.max_health
		if wanted and (dist <= reach or _attracted):
			_attracted = true
			_velocity = to_player.normalized() * MAGNET_SPEED
			global_position += _velocity * delta
			if dist <= COLLECT_DISTANCE:
				collected.emit(kind, value)
				Vfx.sparks(global_position, Vector3.UP, (_mesh.material_override as StandardMaterial3D).albedo_color, 4.0, 180.0)
				queue_free()
			return
		_attracted = false

	if not _settled:
		_velocity.y -= 22.0 * delta
		global_position += _velocity * delta
		if global_position.y <= _floor_y and _velocity.y < 0.0:
			global_position.y = _floor_y
			if absf(_velocity.y) < 2.0:
				_settled = true
				_velocity = Vector3.ZERO
			else:
				_velocity = Vector3(_velocity.x * 0.5, -_velocity.y * 0.35, _velocity.z * 0.5)
	else:
		_mesh.position.y = sin(_age * 3.0) * 0.08
		# blink out in the last few seconds
		if LIFETIME - _age < 4.0:
			_mesh.visible = fmod(_age, 0.3) < 0.18
