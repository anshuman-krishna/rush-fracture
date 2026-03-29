class_name NetworkInterpolator
extends Node

# smooths position and rotation for network-synced nodes.
# attach to any CharacterBody3D that receives position updates from host.
# the synchronizer writes to sync_position/sync_rotation on the parent.
# this node lerps the parent toward those targets.

const INTERP_SPEED: float = 16.0

var sync_position: Vector3 = Vector3.ZERO
var sync_rotation: Vector3 = Vector3.ZERO
var _initialized: bool = false


func _ready() -> void:
	var parent: Node3D = get_parent() as Node3D
	if parent:
		sync_position = parent.global_position
		sync_rotation = parent.rotation
		_initialized = true


func _physics_process(delta: float) -> void:
	if not _initialized:
		return

	var parent: Node3D = get_parent() as Node3D
	if not parent:
		return

	# only interpolate on non-authority (clients)
	if not parent.multiplayer or not parent.multiplayer.has_multiplayer_peer():
		return
	if parent.is_multiplayer_authority():
		# authority: copy actual values to sync vars for transmission
		sync_position = parent.global_position
		sync_rotation = parent.rotation
		return

	# client: lerp toward synced targets
	parent.global_position = parent.global_position.lerp(sync_position, INTERP_SPEED * delta)
	parent.rotation.y = lerp_angle(parent.rotation.y, sync_rotation.y, INTERP_SPEED * delta)
