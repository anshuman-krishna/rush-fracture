class_name BossBase
extends CharacterBody3D

# shared base for the 2 boss controllers. both used to duplicate the same
# telegraph/attack state machine, gravity, targeting, damage-flash/death, and
# even the same shape of ring-VFX helpers independently. combat identity
# (attack selection, attack execution, idle movement, phase transition
# thresholds, add-spawning) stays in each subclass — only the boilerplate
# that was byte-for-byte identical moved here, same split as EnemyBase uses
# for the 8 standard enemies.

signal phase_changed(phase: int)
signal boss_defeated

enum Phase { ONE, TWO }
enum AttackState { IDLE, TELEGRAPH, ATTACKING, COOLDOWN }

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var target: CharacterBody3D
var current_phase: Phase = Phase.ONE
var _player_manager: PlayerManager
var attack_state: AttackState = AttackState.IDLE
var attack_timer: float = 0.0
# each boss's base cooldown before its next attack choice — a real mutable
# field (not a constant) since boss_controller permanently discounts it once
# when phase 2 triggers. subclasses set their starting value in _ready().
var attack_cooldown_base: float = 3.0
var phase_two_triggered: bool = false
var is_dying: bool = false
var _telegraph_timer: float = 0.0
var _attack_duration: float = 0.0
var _pending_attack: String = ""
var _adds_spawned: int = 0

@onready var health: HealthComponent = $HealthComponent

# the single mesh part used for telegraph-color signaling (_show_telegraph /
# _clear_telegraph / _flash_phase_transition) — set by a subclass's
# _build_visual(), normally to a model's biolum "core" glow mesh. hit-flash
# and death-fade below don't depend on it, they act on every mesh part found.
var mesh: MeshInstance3D


func _ready() -> void:
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	add_to_group("enemies")
	add_to_group("boss")
	_player_manager = get_node_or_null("/root/Main/PlayerManager") as PlayerManager
	_build_visual()


## override in a subclass to build its unique procedural mesh or load a model.
func _build_visual() -> void:
	pass


## loads an imported model (e.g. a .glb) and adds it as a child. returns the
## instantiated root so a subclass can pull named parts out of it via
## _find_mesh() — glTF import preserves each part's original mesh name as its
## Godot node name.
func _load_visual_model(path: String) -> Node3D:
	var scene: PackedScene = load(path) as PackedScene
	if not scene:
		return null
	var instance: Node3D = scene.instantiate() as Node3D
	add_child(instance)
	return instance


func _find_mesh(root: Node, mesh_name: String) -> MeshInstance3D:
	if not root:
		return null
	return root.find_child(mesh_name, true, false) as MeshInstance3D


## makes a mesh's material a per-instance override so the telegraph-color
## mutations below never bleed into the shared imported resource every other
## boss instance (or the next run's boss) would otherwise reuse.
func _make_material_unique(mi: MeshInstance3D) -> void:
	if not mi:
		return
	var mat: Material = mi.get_active_material(0)
	if mat:
		mi.set_surface_override_material(0, mat.duplicate())


func _all_meshes() -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	_collect_meshes(self, found)
	return found


func _collect_meshes(node: Node, found: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			found.append(child)
		_collect_meshes(child, found)


func _physics_process(delta: float) -> void:
	if is_dying:
		return

	if not _is_local_authority():
		return

	_apply_gravity(delta)
	_check_phase_transition()

	if not target:
		_find_target()
		move_and_slide()
		return

	var distance: float = global_position.distance_to(target.global_position)
	if distance > _get_detection_range():
		move_and_slide()
		return

	match attack_state:
		AttackState.IDLE:
			_handle_idle(delta, distance)
		AttackState.TELEGRAPH:
			_handle_telegraph(delta)
		AttackState.ATTACKING:
			_handle_attacking(delta)
		AttackState.COOLDOWN:
			_handle_cooldown(delta)

	_face_target()
	move_and_slide()

	_phase_tick(delta)


## override — each boss's detection range differs. named distinctly (not
## `detection_range`) so each subclass can still declare its own
## @export var detection_range without colliding with this method.
func _get_detection_range() -> float:
	return 40.0


## override — per-phase, per-frame extras (add-spawning, arena hazards).
func _phase_tick(_delta: float) -> void:
	pass


## override — idle movement + attack-timer countdown, differs per boss.
func _handle_idle(_delta: float, _distance: float) -> void:
	pass


## override — pick which attack to telegraph next.
func _choose_attack(_distance: float) -> void:
	pass


## override — resolve the telegraphed attack (_pending_attack) into damage/VFX.
func _execute_attack() -> void:
	pass


## override — return this boss's cooldown multiplier once phase 2 hits.
func _phase_two_cooldown_mult() -> float:
	return 1.0


func _begin_telegraph(attack_name: String, duration: float) -> void:
	attack_state = AttackState.TELEGRAPH
	_pending_attack = attack_name
	_telegraph_timer = duration
	velocity.x = 0
	velocity.z = 0
	_show_telegraph(attack_name)


func _handle_telegraph(delta: float) -> void:
	_telegraph_timer -= delta
	if _telegraph_timer <= 0:
		_execute_attack()


func _handle_attacking(delta: float) -> void:
	_attack_duration -= delta
	if _attack_duration <= 0:
		var cd: float = attack_cooldown_base
		if current_phase == Phase.TWO:
			cd *= _phase_two_cooldown_mult()
		attack_timer = cd
		attack_state = AttackState.IDLE
		_clear_telegraph()


func _handle_cooldown(delta: float) -> void:
	attack_timer -= delta
	if attack_timer <= 0:
		attack_state = AttackState.IDLE


## override — telegraph-specific emission color/intensity per attack name.
func _show_telegraph(_attack_name: String) -> void:
	pass


## override — reset emission back to this boss's idle look.
func _clear_telegraph() -> void:
	pass


func _get_players() -> Array:
	if _player_manager:
		return _player_manager.get_all_players()
	return get_tree().get_nodes_in_group("player")


## override — chase movement toward target, differs per boss (acceleration
## constant and phase-dependent speed multiplier both differ, so this stays
## fully per-subclass rather than a shared parameterized helper — same
## reasoning EnemyBase uses for never hoisting _chase()).
func _chase(_delta: float) -> void:
	pass


## override — hp-ratio threshold and phase-2 side effects differ per boss.
func _check_phase_transition() -> void:
	pass


func _face_target() -> void:
	if not target:
		return
	var look_pos: Vector3 = target.global_position
	look_pos.y = global_position.y
	if global_position.distance_to(look_pos) > 0.1:
		look_at(look_pos)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta


func _find_target() -> void:
	if _player_manager:
		target = _player_manager.get_nearest_player(global_position)
	else:
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0] as CharacterBody3D


func _on_damaged(_amount: int, _current: int) -> void:
	_flash_hit()


func _on_died() -> void:
	is_dying = true
	boss_defeated.emit()
	_play_death()


func _flash_hit() -> void:
	# flashes every mesh part, not just the telegraph-color core — a
	# multi-part model needs the whole body to read as "hit."
	for mi: MeshInstance3D in _all_meshes():
		var mat: Material = mi.get_surface_override_material(0)
		if not mat:
			mat = mi.get_active_material(0)
		if not mat is StandardMaterial3D:
			continue
		var unique_mat: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
		mi.set_surface_override_material(0, unique_mat)
		var original_color: Color = unique_mat.albedo_color
		unique_mat.albedo_color = Color.WHITE
		var tween: Tween = create_tween()
		tween.tween_property(unique_mat, "albedo_color", original_color, 0.1)


func _play_death() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale:y", 0.1, 0.8).set_ease(Tween.EASE_IN)
	for mi: MeshInstance3D in _all_meshes():
		tween.parallel().tween_property(mi, "transparency", 1.0, 1.0)
	tween.tween_callback(queue_free)


## override — bright flash + scale-up when phase 2 triggers, colors differ.
func _flash_phase_transition() -> void:
	pass


func get_phase() -> int:
	return current_phase + 1


func _get_audio() -> AudioManager:
	return get_node_or_null("/root/Main/AudioManager") as AudioManager


func get_health_ratio() -> float:
	if not health:
		return 0.0
	return float(health.current_health) / float(health.max_health)


func _is_local_authority() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	return is_multiplayer_authority()


## static-size disc that fades out in place — used by both bosses' slam VFX.
func _spawn_flat_ring_visual(radius: float, albedo: Color, emission: Color, energy: float = 2.0) -> void:
	var indicator: MeshInstance3D = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.1
	indicator.mesh = disc

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = energy
	indicator.material_override = mat

	indicator.global_position = Vector3(global_position.x, 0.1, global_position.z)
	get_tree().root.add_child(indicator)

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.tween_callback(func():
		if is_instance_valid(indicator):
			indicator.queue_free()
	)


## ring that grows from a point to target_radius while fading — used by
## both bosses' shockwave/pulse VFX.
func _spawn_expanding_ring_visual(target_radius: float, albedo: Color, emission: Color, duration: float = 0.4, energy: float = 2.0, height: float = 0.12) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = height
	ring.mesh = cyl

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = energy
	ring.material_override = mat

	ring.global_position = Vector3(global_position.x, 0.1, global_position.z)
	get_tree().root.add_child(ring)

	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(target_radius, 1, target_radius), duration)
	tween.tween_property(mat, "albedo_color:a", 0.0, duration)
	tween.chain().tween_callback(func():
		if is_instance_valid(ring):
			ring.queue_free()
	)
