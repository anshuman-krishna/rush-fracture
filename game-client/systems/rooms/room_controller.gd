class_name RoomController
extends Node3D

# manages a single room lifecycle: spawn enemies, track completion, clean up.
# reconfigures the arena in-place between rooms — no scene swapping.

signal all_enemies_dead
signal enemy_killed
signal boss_defeated

@export var spawn_radius: float = 22.0
@export var min_spawn_distance: float = 6.0

const ARENA_RADIUS: float = 35.0
const ARENA_WALL_HEIGHT: float = 6.0
const ARENA_WALL_SEGMENTS: int = 24
const FALL_KILL_Y: float = -20.0

# "Hive Growth" obstacle set — grafted brood art lane, see testing/design-ideas.md.
# all nine archetypes are modelled and wired: pillar / crate cluster /
# breakable wall / ramp / low_wall / tall_pillar / cylinder_pillar /
# half_cover / barrier_arc. see designs-usage.md's "Extending the lane".
const OBSTACLE_MODEL_PATH: String = "res://assets/models/grafted-brood-obstacles.glb"
# the carapace ramp's deck bakes a fixed slope (rotation.x = -0.42 rad on a
# 1.5 × 2.6m box — see ramp_deck in bio-lane-models.js). _spawn_ramp derives
# height from length using that same angle instead of rolling it separately,
# so the visual tilt always matches the collision tilt.
const RAMP_DECK_TILT: float = 0.42
const RAMP_NATURAL_WIDTH: float = 1.5
const RAMP_NATURAL_LENGTH: float = 2.6
# "split_carapace_screen"'s gap is baked at this fraction of its natural
# length (see bio-lane-models.js); _spawn_half_cover derives gap from length
# using the same ratio so a uniform x-scale keeps the model's gap accurate.
const HALF_COVER_GAP_RATIO: float = 0.24

var active_room: RunData.RoomData
var enemies_alive: int = 0
var room_active: bool = false
var _enemy_scenes: Dictionary = {}
var _boss_scene: PackedScene
var _warden_scene: PackedScene
var active_boss: Node
var current_palette: RoomPalette
var _dup_counter: int = 0
var _gauntlet_waves_remaining: int = 0
var _gauntlet_timer: float = 0.0
var _placed_obstacles: Array[AABB] = []

@onready var arena_root: Node3D = $ArenaRoot
@onready var enemy_root: Node3D = $EnemyRoot
@onready var hazard_root: Node3D = $HazardRoot


func _ready() -> void:
	_preload_enemy_scenes()
	_preload_boss_scene()
	_preload_warden_scene()


func _process(_delta: float) -> void:
	if not room_active or enemies_alive <= 0:
		return
	# safety net: kill any enemy that fell off the map
	for child in enemy_root.get_children():
		if not is_instance_valid(child) or not child is Node3D:
			continue
		if child.global_position.y < FALL_KILL_Y:
			var hc: HealthComponent = child.get_node_or_null("HealthComponent") as HealthComponent
			if hc and hc.is_alive():
				hc._apply_damage(hc.max_health * 10)


func enter_room(room: RunData.RoomData) -> void:
	_clear_room()
	active_room = room
	room_active = false
	current_palette = RoomPalette.pick_for_room(
		room.id.get_slice("_", 1).to_int(), room.type)

	# seed random state from room id so both peers get identical layout
	seed(room.id.hash())

	_configure_arena(room)
	_apply_palette()
	_place_hazards(room)

	await get_tree().create_timer(0.4).timeout

	if room.type == RoomDefinitions.RoomType.BOSS:
		_spawn_boss(room)
	elif room.type == RoomDefinitions.RoomType.ELITE_CHAMBER:
		_spawn_warden(room)
	elif room.type == RoomDefinitions.RoomType.GAUNTLET:
		_start_gauntlet(room)
	else:
		_spawn_enemies(room)
	room_active = true


func _preload_enemy_scenes() -> void:
	for type in EnemyTypes.Type.values():
		var path: String = EnemyTypes.scene_path(type)
		if ResourceLoader.exists(path):
			_enemy_scenes[type] = load(path)


func _preload_boss_scene() -> void:
	var path: String = "res://scenes/enemies/boss_fracture_titan.tscn"
	if ResourceLoader.exists(path):
		_boss_scene = load(path)


func _preload_warden_scene() -> void:
	var path: String = "res://scenes/enemies/boss_fracture_warden.tscn"
	if ResourceLoader.exists(path):
		_warden_scene = load(path)


func _spawn_enemies(room: RunData.RoomData) -> void:
	var count: int = room.enemy_budget
	# ELITE rooms get one elite unit; ELITE_CHAMBER is a room fully dedicated
	# to elites, so every spawned enemy there is elite.
	var is_elite_room: bool = room.type == RoomDefinitions.RoomType.ELITE
	var is_full_elite_room: bool = room.type == RoomDefinitions.RoomType.ELITE_CHAMBER
	var composition: Array[EnemyTypes.Type] = EnemyComposition.get_composition(room.type, room.difficulty, count)
	enemies_alive = 0

	for i in composition.size():
		var type: EnemyTypes.Type = composition[i]
		var scene: PackedScene = _enemy_scenes.get(type, _enemy_scenes.get(EnemyTypes.Type.CHASER))
		if not scene:
			continue

		var instance: CharacterBody3D = scene.instantiate() as CharacterBody3D
		instance.name = "Enemy_%d" % i
		instance.global_position = _get_spawn_position()

		var elite_unit: bool = is_full_elite_room or (is_elite_room and i == 0)
		_scale_enemy(instance, room.difficulty, elite_unit)

		# apply cursed enemy speed bonus
		var speed_bonus: float = room.metadata.get("enemy_speed_bonus", 0.0)
		if speed_bonus > 0 and "move_speed" in instance:
			instance.move_speed *= (1.0 + speed_bonus)

		var health: HealthComponent = instance.get_node_or_null("HealthComponent") as HealthComponent
		if health:
			health.died.connect(_on_enemy_died)

		enemy_root.add_child(instance)
		_setup_enemy_multiplayer(instance)
		enemies_alive += 1


func _spawn_boss(room: RunData.RoomData) -> void:
	if not _boss_scene:
		return

	active_boss = _boss_scene.instantiate() as BossController
	active_boss.name = "Boss_0"
	active_boss.global_position = Vector3(0, 1.0, -15.0)

	# scale boss health by difficulty
	var bh: HealthComponent = active_boss.get_node_or_null("HealthComponent") as HealthComponent
	if bh:
		bh.max_health = int(bh.max_health * room.difficulty)
		bh.current_health = bh.max_health
		bh.died.connect(_on_enemy_died)

	active_boss.boss_defeated.connect(_on_boss_defeated)
	enemy_root.add_child(active_boss)
	_setup_enemy_multiplayer(active_boss)
	enemies_alive = 1


func _spawn_warden(room: RunData.RoomData) -> void:
	if not _warden_scene:
		return

	active_boss = _warden_scene.instantiate() as BossWardenController
	active_boss.name = "BossWarden_0"
	active_boss.global_position = Vector3(0, 1.0, -12.0)

	var bh: HealthComponent = active_boss.get_node_or_null("HealthComponent") as HealthComponent
	if bh:
		bh.max_health = int(bh.max_health * room.difficulty)
		bh.current_health = bh.max_health
		bh.died.connect(_on_enemy_died)

	active_boss.boss_defeated.connect(_on_boss_defeated)
	enemy_root.add_child(active_boss)
	_setup_enemy_multiplayer(active_boss)
	enemies_alive = 1


func _start_gauntlet(room: RunData.RoomData) -> void:
	# gauntlet: 3 waves of enemies, next wave spawns when current clears
	_gauntlet_waves_remaining = 3
	_spawn_gauntlet_wave(room)


func _spawn_gauntlet_wave(room: RunData.RoomData) -> void:
	var wave_budget: int = maxi(int(room.enemy_budget / 3), 2)
	var composition: Array[EnemyTypes.Type] = EnemyComposition.get_composition(
		room.type, room.difficulty, wave_budget)

	for i in composition.size():
		var type: EnemyTypes.Type = composition[i]
		var scene: PackedScene = _enemy_scenes.get(type, _enemy_scenes.get(EnemyTypes.Type.CHASER))
		if not scene:
			continue

		var instance: CharacterBody3D = scene.instantiate() as CharacterBody3D
		instance.name = "GauntletEnemy_%d_%d" % [_gauntlet_waves_remaining, i]
		instance.global_position = _get_spawn_position()
		_scale_enemy(instance, room.difficulty, false)

		var speed_bonus: float = room.metadata.get("enemy_speed_bonus", 0.0)
		if speed_bonus > 0 and "move_speed" in instance:
			instance.move_speed *= (1.0 + speed_bonus)

		var h: HealthComponent = instance.get_node_or_null("HealthComponent") as HealthComponent
		if h:
			h.died.connect(_on_enemy_died)

		enemy_root.add_child(instance)
		_setup_enemy_multiplayer(instance)
		enemies_alive += 1


func _on_boss_defeated() -> void:
	boss_defeated.emit()


func _scale_enemy(enemy: CharacterBody3D, difficulty: float, is_elite_unit: bool) -> void:
	var health: HealthComponent = enemy.get_node_or_null("HealthComponent") as HealthComponent
	if health:
		health.max_health = int(health.max_health * difficulty)
		if is_elite_unit:
			health.max_health = int(health.max_health * 2.5)
		health.current_health = health.max_health

	if is_elite_unit:
		if "move_speed" in enemy:
			enemy.move_speed *= 1.3
		if "attack_damage" in enemy:
			enemy.attack_damage = int(enemy.attack_damage * 2.0)
		if "is_elite" in enemy:
			enemy.is_elite = true
		enemy.scale = Vector3(1.5, 1.5, 1.5)
		_apply_elite_visual(enemy)
	else:
		if "move_speed" in enemy:
			enemy.move_speed *= (1.0 + (difficulty - 1.0) * 0.15)
		if "attack_damage" in enemy:
			enemy.attack_damage = int(enemy.attack_damage * (1.0 + (difficulty - 1.0) * 0.1))


func _apply_elite_visual(enemy: CharacterBody3D) -> void:
	var mesh: MeshInstance3D = enemy.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not mesh:
		return
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.05, 0.05, 1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.1, 0.0)
	mat.emission_energy_multiplier = 1.5
	mesh.set_surface_override_material(0, mat)


func _on_enemy_died() -> void:
	enemies_alive -= 1
	enemy_killed.emit()
	if enemies_alive <= 0 and room_active:
		# gauntlet: spawn next wave if waves remain
		if _gauntlet_waves_remaining > 1 and active_room and active_room.type == RoomDefinitions.RoomType.GAUNTLET:
			_gauntlet_waves_remaining -= 1
			# brief delay between waves
			get_tree().create_timer(1.0).timeout.connect(func():
				if room_active and active_room:
					_spawn_gauntlet_wave(active_room)
			)
			return
		room_active = false
		all_enemies_dead.emit()


func _get_spawn_position() -> Vector3:
	# try up to 10 times to find a position that doesn't overlap obstacles
	for _attempt in 10:
		var angle: float = randf() * TAU
		var distance: float = min_spawn_distance + randf() * (spawn_radius - min_spawn_distance)
		var pos: Vector3 = Vector3(cos(angle) * distance, 1.0, sin(angle) * distance)
		# clamp inside arena
		var flat_dist: float = Vector2(pos.x, pos.z).length()
		if flat_dist > ARENA_RADIUS - 3.0:
			var scale_f: float = (ARENA_RADIUS - 3.0) / flat_dist
			pos.x *= scale_f
			pos.z *= scale_f
		# check against placed obstacles
		var blocked: bool = false
		var test_aabb: AABB = AABB(pos - Vector3(1, 0, 1), Vector3(2, 2, 2))
		for obs in _placed_obstacles:
			if test_aabb.intersects(obs):
				blocked = true
				break
		if not blocked:
			return pos
	# fallback — spawn near center
	return Vector3(randf_range(-3, 3), 1.0, randf_range(-3, 3))


func _configure_arena(room: RunData.RoomData) -> void:
	_clear_obstacles()
	_placed_obstacles.clear()

	_build_arena_border(room)
	_build_floor_detail()

	if room.type == RoomDefinitions.RoomType.RECOVERY:
		return

	# room-specific layouts
	match room.type:
		RoomDefinitions.RoomType.BOSS:
			_layout_boss_arena(room)
			return
		RoomDefinitions.RoomType.GAUNTLET:
			_layout_gauntlet_arena(room)
			return
		RoomDefinitions.RoomType.ELITE_CHAMBER:
			_layout_elite_chamber(room)
			return

	var obstacle_count: int = 0
	match room.type:
		RoomDefinitions.RoomType.COMBAT:
			obstacle_count = clampi(int(room.difficulty * 2), 3, 8)
		RoomDefinitions.RoomType.SWARM:
			obstacle_count = clampi(int(room.difficulty), 2, 4)
		RoomDefinitions.RoomType.ELITE:
			obstacle_count = clampi(int(room.difficulty * 1.5), 3, 6)
		RoomDefinitions.RoomType.HAZARD:
			obstacle_count = clampi(int(room.difficulty * 2.5), 4, 10)

	for i in obstacle_count:
		_place_obstacle(i, obstacle_count, room)

	# add height variation for higher difficulty
	if room.difficulty >= 1.4:
		var platform_count: int = clampi(int((room.difficulty - 1.2) * 2), 1, 3)
		for i in platform_count:
			_place_elevated_platform(room)


func _apply_palette() -> void:
	if not current_palette:
		return

	# floor material
	var floor_node: MeshInstance3D = get_node_or_null("/root/Main/Floor/FloorMesh") as MeshInstance3D
	if floor_node:
		var mat: Material = floor_node.get_surface_override_material(0)
		if not mat:
			mat = StandardMaterial3D.new()
			floor_node.set_surface_override_material(0, mat)
		if mat is StandardMaterial3D:
			mat.albedo_color = current_palette.floor_color
			mat.emission_enabled = true
			mat.emission = current_palette.floor_emission
			mat.emission_energy_multiplier = 0.3
			mat.roughness = 0.85

	# directional light
	var light: DirectionalLight3D = get_node_or_null("/root/Main/DirectionalLight3D") as DirectionalLight3D
	if light:
		light.light_color = current_palette.light_color
		light.light_energy = current_palette.light_energy


func _place_obstacle(index: int, total: int, room: RunData.RoomData) -> void:
	var obstacle_type: int = randi() % 10
	var angle: float = (float(index) / float(total)) * TAU + randf() * 0.5
	var dist: float = 6.0 + randf() * 14.0
	var pos: Vector3 = Vector3(cos(angle) * dist, 0, sin(angle) * dist)

	# clamp inside arena bounds
	var flat_dist: float = Vector2(pos.x, pos.z).length()
	if flat_dist > ARENA_RADIUS - 4.0:
		var scale_f: float = (ARENA_RADIUS - 4.0) / flat_dist
		pos.x *= scale_f
		pos.z *= scale_f

	match obstacle_type:
		0:
			_spawn_pillar(pos, room)
		1:
			_spawn_low_wall(pos, angle, room)
		2:
			_spawn_crate_cluster(pos, room)
		3:
			_spawn_ramp(pos, angle, room)
		4:
			_spawn_tall_pillar(pos, room)
		5:
			_spawn_cylinder_pillar(pos, room)
		6:
			_spawn_half_cover(pos, angle, room)
		7:
			_spawn_barrier_arc(pos, angle, room)
		8, 9:
			_spawn_breakable_wall(pos, angle, room)


func _try_register_obstacle(pos: Vector3, size: Vector3) -> bool:
	var margin: float = 1.5
	var new_aabb: AABB = AABB(
		pos - size * 0.5 - Vector3(margin, 0, margin),
		size + Vector3(margin * 2, 0, margin * 2)
	)
	# don't overlap player spawn
	var spawn_zone: AABB = AABB(Vector3(-3, -1, -3), Vector3(6, 4, 6))
	if new_aabb.intersects(spawn_zone):
		return false
	for existing in _placed_obstacles:
		if new_aabb.intersects(existing):
			return false
	_placed_obstacles.append(new_aabb)
	return true


func _get_obstacle_color(variation: float = 0.0) -> Color:
	if current_palette:
		var c: Color = current_palette.obstacle_color
		return Color(c.r + randf() * 0.03 + variation, c.g + randf() * 0.03 + variation, c.b + randf() * 0.03 + variation, 1)
	return Color(0.1 + variation, 0.1 + variation, 0.12 + variation, 1)


func _get_emission_color() -> Color:
	if current_palette:
		return current_palette.floor_emission
	return Color(0.3, 0.1, 0.1)


# --- arena border ---

func _build_arena_border(room: RunData.RoomData) -> void:
	var wall_color: Color = _get_obstacle_color(-0.04)
	var emit_color: Color = _get_emission_color()

	for i in ARENA_WALL_SEGMENTS:
		var angle: float = (float(i) / float(ARENA_WALL_SEGMENTS)) * TAU
		var next_angle: float = (float(i + 1) / float(ARENA_WALL_SEGMENTS)) * TAU
		var mid_angle: float = (angle + next_angle) * 0.5
		var seg_length: float = 2.0 * ARENA_RADIUS * sin(PI / ARENA_WALL_SEGMENTS)

		var wall: StaticBody3D = StaticBody3D.new()
		wall.position = Vector3(cos(mid_angle) * ARENA_RADIUS, 0, sin(mid_angle) * ARENA_RADIUS)
		wall.rotation.y = -mid_angle + PI * 0.5

		var mesh: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(seg_length + 0.2, ARENA_WALL_HEIGHT, 0.5)
		mesh.mesh = box
		mesh.position.y = ARENA_WALL_HEIGHT / 2.0
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = wall_color
		mat.roughness = 0.9
		mesh.material_override = mat

		var col: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(seg_length + 0.2, ARENA_WALL_HEIGHT, 0.5)
		col.shape = shape
		col.position.y = ARENA_WALL_HEIGHT / 2.0

		wall.add_child(mesh)
		wall.add_child(col)
		wall.collision_layer = 1
		arena_root.add_child(wall)

		# glow trim at base of wall
		if i % 3 == 0:
			var trim: MeshInstance3D = MeshInstance3D.new()
			var trim_box: BoxMesh = BoxMesh.new()
			trim_box.size = Vector3(seg_length + 0.2, 0.08, 0.55)
			trim.mesh = trim_box
			trim.position.y = 0.04
			var trim_mat: StandardMaterial3D = StandardMaterial3D.new()
			trim_mat.emission_enabled = true
			trim_mat.albedo_color = emit_color
			trim_mat.emission = emit_color
			trim_mat.emission_energy_multiplier = 0.8
			trim.material_override = trim_mat
			wall.add_child(trim)

		# top trim on every other segment
		if i % 2 == 0:
			var top_trim: MeshInstance3D = MeshInstance3D.new()
			var top_box: BoxMesh = BoxMesh.new()
			top_box.size = Vector3(seg_length + 0.2, 0.06, 0.55)
			top_trim.mesh = top_box
			top_trim.position.y = ARENA_WALL_HEIGHT
			var top_mat: StandardMaterial3D = StandardMaterial3D.new()
			top_mat.emission_enabled = true
			top_mat.albedo_color = emit_color * 0.6
			top_mat.emission = emit_color * 0.6
			top_mat.emission_energy_multiplier = 0.5
			top_trim.material_override = top_mat
			wall.add_child(top_trim)


func _build_floor_detail() -> void:
	var emit_color: Color = _get_emission_color()
	# radial ring lines on the floor for spatial awareness
	var ring_radii: Array[float] = [10.0, 20.0, 30.0]
	for radius in ring_radii:
		var segments: int = 32
		for i in segments:
			var angle: float = (float(i) / float(segments)) * TAU
			var next_angle: float = (float(i + 1) / float(segments)) * TAU
			var mid: float = (angle + next_angle) * 0.5
			var seg_len: float = 2.0 * radius * sin(PI / segments)

			var line: MeshInstance3D = MeshInstance3D.new()
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(seg_len, 0.02, 0.04)
			line.mesh = box
			line.position = Vector3(cos(mid) * radius, 0.11, sin(mid) * radius)
			line.rotation.y = -mid + PI * 0.5

			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.albedo_color = emit_color * 0.3
			mat.emission_enabled = true
			mat.emission = emit_color * 0.2
			mat.emission_energy_multiplier = 0.3
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.4
			line.material_override = mat
			arena_root.add_child(line)

	# cross lines through center
	for angle in [0.0, PI * 0.5]:
		var cross: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(ARENA_RADIUS * 2.0, 0.02, 0.05)
		cross.mesh = box
		cross.position.y = 0.11
		cross.rotation.y = angle

		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = emit_color * 0.25
		mat.emission_enabled = true
		mat.emission = emit_color * 0.15
		mat.emission_energy_multiplier = 0.2
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.3
		cross.material_override = mat
		arena_root.add_child(cross)


# --- room-type specific layouts ---

func _layout_boss_arena(room: RunData.RoomData) -> void:
	# boss arena: symmetrical pillars forming a ring, clear center
	var pillar_count: int = 8
	for i in pillar_count:
		var angle: float = (float(i) / float(pillar_count)) * TAU
		var dist: float = 18.0
		var pos: Vector3 = Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		_spawn_tall_pillar(pos, room)

	# inner cover ring — breakable walls for dynamic cover
	for i in 4:
		var angle: float = (float(i) / 4.0) * TAU + PI * 0.25
		var pos: Vector3 = Vector3(cos(angle) * 10.0, 0, sin(angle) * 10.0)
		_spawn_breakable_wall(pos, angle, room)

	# additional low walls between breakable ones
	for i in 4:
		var angle: float = (float(i) / 4.0) * TAU
		var pos: Vector3 = Vector3(cos(angle) * 14.0, 0, sin(angle) * 14.0)
		_spawn_low_wall(pos, angle, room)


func _layout_gauntlet_arena(room: RunData.RoomData) -> void:
	# gauntlet: parallel barriers creating lanes
	var lane_count: int = 3
	var spacing: float = 8.0
	for i in lane_count:
		var z_offset: float = (float(i) - float(lane_count - 1) * 0.5) * spacing
		# staggered barriers along the lane
		for j in 4:
			var x_pos: float = -12.0 + j * 8.0
			var side: float = 1.0 if (i + j) % 2 == 0 else -1.0
			var pos: Vector3 = Vector3(x_pos, 0, z_offset + side * 1.5)
			if _try_register_obstacle(pos, Vector3(3, 1.2, 0.4)):
				_spawn_low_wall(pos, 0.0, room)

	# some pillars for vertical cover
	for i in 3:
		var angle: float = randf() * TAU
		var pos: Vector3 = Vector3(cos(angle) * 8.0, 0, sin(angle) * 8.0)
		_spawn_cylinder_pillar(pos, room)


func _layout_elite_chamber(room: RunData.RoomData) -> void:
	# elite chamber: central arena with 4 elevated platforms at corners
	var corner_dist: float = 14.0
	for i in 4:
		var angle: float = (float(i) / 4.0) * TAU + PI * 0.25
		var pos: Vector3 = Vector3(cos(angle) * corner_dist, 0, sin(angle) * corner_dist)
		_spawn_elevated_platform_at(pos, 4.0, 4.0, 1.2 + randf() * 0.5, room)

	# barrier arcs around center
	for i in 4:
		var angle: float = (float(i) / 4.0) * TAU
		var pos: Vector3 = Vector3(cos(angle) * 8.0, 0, sin(angle) * 8.0)
		_spawn_barrier_arc(pos, angle, room)


# --- obstacle types ---

## extracts one or more named top-level parts from the "Hive Growth" obstacle
## model into a single wrapper Node3D, positioned/rotated back to zero so a
## caller can freely position/scale the wrapper. parts that shared a local
## offset in the source model (e.g. an eggsac body + its glow core) keep
## that relative alignment once both are zeroed onto the same wrapper.
func _load_obstacle_parts(names: Array) -> Node3D:
	var scene: PackedScene = load(OBSTACLE_MODEL_PATH) as PackedScene
	if not scene:
		return null
	var diorama: Node3D = scene.instantiate() as Node3D
	var wrapper: Node3D = Node3D.new()
	for n in names:
		var part: Node3D = diorama.find_child(n, true, false) as Node3D
		if not part:
			continue
		diorama.remove_child(part)
		part.position = Vector3.ZERO
		part.rotation = Vector3.ZERO
		wrapper.add_child(part)
	diorama.queue_free()
	return wrapper


func _spawn_pillar(pos: Vector3, room: RunData.RoomData) -> void:
	var height: float = 1.5 + randf() * 2.0
	var width: float = 0.8 + randf() * 0.6

	if not _try_register_obstacle(pos, Vector3(width, height, width)):
		return

	var pillar: StaticBody3D = StaticBody3D.new()
	pillar.position = pos

	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(width, height, width)
	col.shape = shape
	col.position.y = height / 2.0
	pillar.add_child(col)

	# "rib-arch pillar" — natural size ~1.1 wide, ~3.44 tall (see bounds in
	# designs-usage.md); scaled non-uniformly to fit this instance's rolled
	# footprint, same way the old procedural box was stretched to size.
	var model: Node3D = _load_obstacle_parts(["pillar_rib_arch"])
	if model:
		model.scale = Vector3(width / 1.1, height / 3.44, width / 1.1)
		pillar.add_child(model)

	pillar.collision_layer = 1
	arena_root.add_child(pillar)


func _spawn_low_wall(pos: Vector3, angle: float, room: RunData.RoomData) -> void:
	var length: float = 2.5 + randf() * 3.0
	var height: float = 0.8 + randf() * 0.5

	if not _try_register_obstacle(pos, Vector3(length, height, 0.4)):
		return

	var wall: StaticBody3D = StaticBody3D.new()
	wall.position = pos
	wall.rotation.y = angle + randf() * 0.3

	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(length, height, 0.4)
	col.shape = shape
	col.position.y = height / 2.0
	wall.add_child(col)

	wall.collision_layer = 1
	arena_root.add_child(wall)

	# "rib fence" — natural size 3.46 long x 1.15 tall (measured bbox, see
	# designs-usage.md); depth is fixed in the model so only length/height scale.
	var model: Node3D = _load_obstacle_parts(["rib_fence"])
	if model:
		model.scale = Vector3(length / 3.46, height / 1.15, 1.0)
		wall.add_child(model)


func _spawn_crate_cluster(pos: Vector3, room: RunData.RoomData) -> void:
	if not _try_register_obstacle(pos, Vector3(3, 1.5, 3)):
		return

	# "egg-sac cluster" — 4 sac variants in the model, natural sizes below
	# (see designs-usage.md); cycled across crates and scaled to each rolled
	# footprint, same non-uniform-stretch approach as the pillar.
	var egg_sizes: Array[float] = [0.84, 0.68, 0.6, 0.6]

	var count: int = 2 + randi() % 3
	for i in count:
		var crate: StaticBody3D = StaticBody3D.new()
		var offset: Vector3 = Vector3((randf() - 0.5) * 2.0, 0, (randf() - 0.5) * 2.0)
		crate.position = pos + offset
		var s: float = 0.5 + randf() * 0.5
		var h: float = 0.4 + randf() * 0.8

		var col: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(s, h, s)
		col.shape = shape
		col.position.y = h / 2.0
		crate.add_child(col)

		var variant: int = i % 4
		var model: Node3D = _load_obstacle_parts(["eggsac_%d" % (variant + 1), "eggsac_core_%d" % (variant + 1)])
		if model:
			var natural_xz: float = egg_sizes[variant]
			var natural_y: float = natural_xz * 1.25  # sac geometry is scaled [1, 1.25, 1] in the source
			model.scale = Vector3(s / natural_xz, h / natural_y, s / natural_xz)
			model.position.y = h / 2.0
			crate.add_child(model)

		crate.collision_layer = 1
		arena_root.add_child(crate)


func _spawn_ramp(pos: Vector3, angle: float, room: RunData.RoomData) -> void:
	var length: float = 3.0 + randf() * 2.0
	var width: float = 1.5 + randf() * 1.0
	# height is derived, not rolled — see RAMP_DECK_TILT above.
	var height: float = length * tan(RAMP_DECK_TILT)

	if not _try_register_obstacle(pos, Vector3(width, height, length)):
		return

	var ramp: StaticBody3D = StaticBody3D.new()
	ramp.position = pos
	ramp.rotation.y = angle

	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(width, 0.15, length)
	col.shape = shape
	col.position = Vector3(0, height / 2.0, 0)
	col.rotation.x = -atan2(height, length)
	ramp.add_child(col)

	ramp.collision_layer = 1
	arena_root.add_child(ramp)

	# "carapace ramp" — natural deck is 1.5 wide × 2.6 long (pre-tilt); a
	# uniform y/z scale preserves the baked tilt exactly (non-uniform would
	# shear it), while x (width) sits outside the tilt axis and scales freely.
	var model: Node3D = _load_obstacle_parts(["carapace_ramp"])
	if model:
		var slope_scale: float = length / RAMP_NATURAL_LENGTH
		model.scale = Vector3(width / RAMP_NATURAL_WIDTH, slope_scale, slope_scale)
		ramp.add_child(model)


func _spawn_tall_pillar(pos: Vector3, room: RunData.RoomData) -> void:
	var width: float = 0.5 + randf() * 0.3
	var height: float = 3.5 + randf() * 2.0

	if not _try_register_obstacle(pos, Vector3(width, height, width)):
		return

	var pillar: StaticBody3D = StaticBody3D.new()
	pillar.position = pos

	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(width, height, width)
	col.shape = shape
	col.position.y = height / 2.0
	pillar.add_child(col)

	pillar.collision_layer = 1
	arena_root.add_child(pillar)

	# "bone spire" — natural size 0.78 wide x 4.57 tall (measured bbox, see
	# designs-usage.md).
	var model: Node3D = _load_obstacle_parts(["bone_spire"])
	if model:
		model.scale = Vector3(width / 0.78, height / 4.57, width / 0.78)
		pillar.add_child(model)


func _spawn_cylinder_pillar(pos: Vector3, room: RunData.RoomData) -> void:
	var radius: float = 0.6 + randf() * 0.5
	var height: float = 2.0 + randf() * 2.5

	if not _try_register_obstacle(pos, Vector3(radius * 2, height, radius * 2)):
		return

	var pillar: StaticBody3D = StaticBody3D.new()
	pillar.position = pos

	# use cylinder collision
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	col.position.y = height / 2.0
	pillar.add_child(col)

	pillar.collision_layer = 1
	arena_root.add_child(pillar)

	# "swollen trunk" — natural radius 0.95, height 3.25 (measured bbox, see
	# designs-usage.md).
	var model: Node3D = _load_obstacle_parts(["swollen_trunk"])
	if model:
		model.scale = Vector3(radius / 0.95, height / 3.25, radius / 0.95)
		pillar.add_child(model)


func _spawn_half_cover(pos: Vector3, angle: float, room: RunData.RoomData) -> void:
	# wall with a gap in the middle for shooting through. the gap is derived
	# from length rather than rolled independently, matching the fixed ratio
	# baked into "split_carapace_screen" (see HALF_COVER_GAP_RATIO).
	var length: float = 4.0 + randf() * 2.0
	var height: float = 1.4 + randf() * 0.4
	var gap: float = length * HALF_COVER_GAP_RATIO

	if not _try_register_obstacle(pos, Vector3(length, height, 0.4)):
		return

	var cover: StaticBody3D = StaticBody3D.new()
	cover.position = pos
	cover.rotation.y = angle + randf() * 0.4

	# left/right collision sections
	var half_len: float = (length - gap) * 0.5
	for side in [-1.0, 1.0]:
		var col: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(half_len, height, 0.35)
		col.shape = shape
		col.position = Vector3(side * (half_len + gap) * 0.5, height / 2.0, 0)
		cover.add_child(col)

	var top_col: CollisionShape3D = CollisionShape3D.new()
	var top_shape: BoxShape3D = BoxShape3D.new()
	top_shape.size = Vector3(length, 0.15, 0.35)
	top_col.shape = top_shape
	top_col.position.y = height
	cover.add_child(top_col)

	cover.collision_layer = 1
	arena_root.add_child(cover)

	# uniform x/y scale of the whole group preserves the baked gap ratio
	# exactly (an independent gap scale would require splitting the panels
	# into two extracted parts, which the model doesn't need). natural size
	# 5.06 long x 1.713 tall, measured bbox — see designs-usage.md.
	var model: Node3D = _load_obstacle_parts(["split_carapace_screen"])
	if model:
		model.scale = Vector3(length / 5.06, height / 1.713, 1.0)
		cover.add_child(model)


func _spawn_barrier_arc(pos: Vector3, angle: float, room: RunData.RoomData) -> void:
	# curved barrier made of 3 connected segments
	var arc_radius: float = 2.5 + randf() * 1.5
	var height: float = 1.0 + randf() * 0.6
	var segments: int = 3

	if not _try_register_obstacle(pos, Vector3(arc_radius * 2, height, arc_radius * 2)):
		return

	var arc_root: StaticBody3D = StaticBody3D.new()
	arc_root.position = pos
	arc_root.rotation.y = angle
	arc_root.collision_layer = 1

	# "rib corral" — one reusable curved-fence segment (natural 1.76 long x
	# 1.1 tall, measured bbox) instanced per arc segment, plus a shared trim
	# bar (natural 4.5 long); see designs-usage.md.
	for i in segments:
		var seg_angle: float = (float(i) / float(segments) - 0.5) * PI * 0.6
		var seg_pos: Vector3 = Vector3(sin(seg_angle) * arc_radius, 0, cos(seg_angle) * arc_radius)
		var seg_length: float = 2.0 * arc_radius * sin(PI * 0.6 / (2 * segments))

		var col: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(seg_length, height, 0.3)
		col.shape = shape
		col.position = seg_pos + Vector3(0, height / 2.0, 0)
		col.rotation.y = -seg_angle
		arc_root.add_child(col)

		var model: Node3D = _load_obstacle_parts(["corral_segment"])
		if model:
			model.scale = Vector3(seg_length / 1.76, height / 1.1, 1.0)
			model.position = seg_pos
			model.rotation.y = -seg_angle
			arc_root.add_child(model)

	var trim: Node3D = _load_obstacle_parts(["corral_trim"])
	if trim:
		trim.scale = Vector3(arc_radius * 1.5 / 4.5, 1.0, 1.0)
		trim.position.y = height
		arc_root.add_child(trim)

	arena_root.add_child(arc_root)


func _place_elevated_platform(room: RunData.RoomData) -> void:
	var angle: float = randf() * TAU
	var dist: float = 8.0 + randf() * 10.0
	var pos: Vector3 = Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	var w: float = 3.0 + randf() * 3.0
	var d: float = 3.0 + randf() * 3.0
	var h: float = 0.8 + randf() * 1.0
	_spawn_elevated_platform_at(pos, w, d, h, room)


func _spawn_elevated_platform_at(pos: Vector3, w: float, d: float, h: float, room: RunData.RoomData) -> void:
	if not _try_register_obstacle(pos, Vector3(w, h, d)):
		return

	var platform: StaticBody3D = StaticBody3D.new()
	platform.position = pos

	# platform surface
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(w, h, d)
	mesh.mesh = box
	mesh.position.y = h / 2.0
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = _get_obstacle_color(0.03)
	mat.roughness = 0.8
	mesh.material_override = mat

	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(w, h, d)
	col.shape = shape
	col.position.y = h / 2.0

	platform.add_child(mesh)
	platform.add_child(col)
	platform.collision_layer = 1
	arena_root.add_child(platform)

	# edge trim glow on all 4 sides
	var emit: Color = _get_emission_color()
	var sides: Array[Dictionary] = [
		{"size": Vector3(w + 0.04, 0.06, 0.06), "pos": Vector3(0, h, d * 0.5)},
		{"size": Vector3(w + 0.04, 0.06, 0.06), "pos": Vector3(0, h, -d * 0.5)},
		{"size": Vector3(0.06, 0.06, d + 0.04), "pos": Vector3(w * 0.5, h, 0)},
		{"size": Vector3(0.06, 0.06, d + 0.04), "pos": Vector3(-w * 0.5, h, 0)},
	]
	for side_data in sides:
		var trim: MeshInstance3D = MeshInstance3D.new()
		var trim_box: BoxMesh = BoxMesh.new()
		trim_box.size = side_data["size"]
		trim.mesh = trim_box
		trim.position = side_data["pos"]
		var trim_mat: StandardMaterial3D = StandardMaterial3D.new()
		trim_mat.emission_enabled = true
		trim_mat.albedo_color = emit
		trim_mat.emission = emit
		trim_mat.emission_energy_multiplier = 0.6
		trim.material_override = trim_mat
		platform.add_child(trim)

	# ramp leading up to the platform
	var ramp_length: float = h * 2.5
	var ramp: MeshInstance3D = MeshInstance3D.new()
	var ramp_box: BoxMesh = BoxMesh.new()
	ramp_box.size = Vector3(minf(w * 0.6, 2.0), 0.12, ramp_length)
	ramp.mesh = ramp_box
	ramp.position = Vector3(0, h * 0.5, d * 0.5 + ramp_length * 0.4)
	ramp.rotation.x = atan2(h, ramp_length)
	var ramp_mat: StandardMaterial3D = StandardMaterial3D.new()
	ramp_mat.albedo_color = _get_obstacle_color(0.05)
	ramp.material_override = ramp_mat
	platform.add_child(ramp)

	var ramp_col: CollisionShape3D = CollisionShape3D.new()
	var ramp_shape: BoxShape3D = BoxShape3D.new()
	ramp_shape.size = Vector3(minf(w * 0.6, 2.0), 0.12, ramp_length)
	ramp_col.shape = ramp_shape
	ramp_col.position = Vector3(0, h * 0.5, d * 0.5 + ramp_length * 0.4)
	ramp_col.rotation.x = atan2(h, ramp_length)
	platform.add_child(ramp_col)


func _spawn_breakable_wall(pos: Vector3, angle: float, room: RunData.RoomData) -> void:
	# destructible cover — blocks shots until broken. reduces damage while intact.
	var length: float = 3.0 + randf() * 2.0
	var height: float = 1.5 + randf() * 0.5
	var hit_points: int = 4

	if not _try_register_obstacle(pos, Vector3(length, height, 0.5)):
		return

	var wall: StaticBody3D = StaticBody3D.new()
	wall.position = pos
	wall.rotation.y = angle + randf() * 0.3
	wall.collision_layer = 1
	wall.set_meta("breakable", true)
	wall.set_meta("hit_points", hit_points)
	wall.set_meta("max_hit_points", hit_points)

	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "WallCollision"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(length, height, 0.35)
	col.shape = shape
	col.position.y = height / 2.0
	wall.add_child(col)

	# "breakable membrane wall" — already visibly cracked (wall_fissure_1..5).
	# natural size ~2.23 wide, ~2.02 tall (see bounds in designs-usage.md);
	# scaled non-uniformly to fit this instance's rolled footprint.
	var model: Node3D = _load_obstacle_parts(["breakable_membrane_wall"])
	if model:
		model.name = "WallModel"
		model.scale = Vector3(length / 2.23, height / 2.02, 1.0)
		wall.add_child(model)

	arena_root.add_child(wall)


func damage_breakable_wall(wall: StaticBody3D) -> void:
	if not wall.has_meta("breakable"):
		return
	var hp: int = wall.get_meta("hit_points") - 1
	wall.set_meta("hit_points", hp)
	var max_hp: int = wall.get_meta("max_hit_points")
	var damage_ratio: float = 1.0 - float(hp) / float(max_hp)

	var model: Node3D = wall.get_node_or_null("WallModel") as Node3D
	if model:
		# brighten the model's own pre-cracked fissures as damage accrues
		for i in range(1, 6):
			var fissure: MeshInstance3D = model.find_child("wall_fissure_%d" % i, true, false) as MeshInstance3D
			if not fissure:
				continue
			var mat: Material = fissure.get_surface_override_material(0)
			if not mat:
				mat = fissure.get_active_material(0)
			if mat is StandardMaterial3D:
				var unique_mat: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
				fissure.set_surface_override_material(0, unique_mat)
				unique_mat.emission_energy_multiplier = 1.7 + damage_ratio * 3.0

		# shake the wall
		var tween: Tween = model.create_tween()
		tween.tween_property(model, "position:x", model.position.x + 0.05, 0.03)
		tween.tween_property(model, "position:x", model.position.x - 0.05, 0.03)
		tween.tween_property(model, "position:x", model.position.x, 0.03)

	if hp <= 0:
		_destroy_breakable_wall(wall)


func _destroy_breakable_wall(wall: StaticBody3D) -> void:
	# explode into fragments
	var pos: Vector3 = wall.global_position
	var emit: Color = _get_emission_color()
	for i in 5:
		var frag: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.3 + randf() * 0.3, 0.2 + randf() * 0.3, 0.2 + randf() * 0.2)
		frag.mesh = box
		frag.global_position = pos + Vector3(randf_range(-1, 1), randf_range(0.2, 1.5), randf_range(-1, 1))
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = _get_obstacle_color(0.05)
		mat.emission_enabled = true
		mat.emission = emit
		mat.emission_energy_multiplier = 0.8
		frag.material_override = mat
		arena_root.add_child(frag)

		var tween: Tween = frag.create_tween()
		tween.set_parallel(true)
		tween.tween_property(frag, "position:y", frag.position.y - 1.0, 0.5)
		tween.tween_property(frag, "scale", Vector3.ZERO, 0.4).set_delay(0.2)
		tween.chain().tween_callback(frag.queue_free)

	arena_root.remove_child(wall)
	wall.free()


func _place_hazards(room: RunData.RoomData) -> void:
	_clear_hazards()
	if room.type == RoomDefinitions.RoomType.RECOVERY or room.type == RoomDefinitions.RoomType.BOSS:
		return

	var hazard_count: int = 0
	if room.type == RoomDefinitions.RoomType.HAZARD:
		hazard_count = clampi(int(room.difficulty * 4), 4, 10)
	elif room.difficulty >= 1.4:
		hazard_count = clampi(int((room.difficulty - 1.2) * 3), 1, 5)

	var hazard_roll: float = randf()
	for i in hazard_count:
		if hazard_roll < 0.4:
			_place_spike_zone(i, hazard_count)
		elif hazard_roll < 0.7:
			_place_damage_tile(i, hazard_count)
		else:
			_place_lava_pit(i, hazard_count)
		hazard_roll = randf()


func _place_spike_zone(index: int, total: int) -> void:
	var zone: Area3D = Area3D.new()
	var angle: float = (float(index) / float(total)) * TAU + randf() * 1.0
	var dist: float = 4.0 + randf() * 12.0
	zone.position = Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	zone.collision_layer = 0
	zone.collision_mask = 1

	var size: float = 2.0 + randf() * 2.0
	var tint: Color = current_palette.hazard_tint if current_palette else Color(0.8, 0.1, 0.0)

	# base plate
	var base_mesh: MeshInstance3D = MeshInstance3D.new()
	var base_box: BoxMesh = BoxMesh.new()
	base_box.size = Vector3(size, 0.08, size)
	base_mesh.mesh = base_box
	base_mesh.position.y = 0.04
	var base_mat: StandardMaterial3D = StandardMaterial3D.new()
	base_mat.albedo_color = Color(tint.r * 0.3, tint.g * 0.3, tint.b * 0.3, 1)
	base_mesh.material_override = base_mat
	zone.add_child(base_mesh)

	# spike protrusions
	var spike_count: int = clampi(int(size * 2), 3, 8)
	for i in spike_count:
		var spike: MeshInstance3D = MeshInstance3D.new()
		var spike_box: BoxMesh = BoxMesh.new()
		var sw: float = 0.08 + randf() * 0.06
		var sh: float = 0.15 + randf() * 0.2
		spike_box.size = Vector3(sw, sh, sw)
		spike.mesh = spike_box
		spike.position = Vector3(
			(randf() - 0.5) * (size - 0.2),
			0.08 + sh / 2.0,
			(randf() - 0.5) * (size - 0.2)
		)
		var spike_mat: StandardMaterial3D = StandardMaterial3D.new()
		spike_mat.albedo_color = Color(tint.r * 0.8, tint.g * 0.1, tint.b * 0.05, 1)
		spike_mat.emission_enabled = true
		spike_mat.emission = tint
		spike_mat.emission_energy_multiplier = 0.4
		spike.material_override = spike_mat
		zone.add_child(spike)

	# glow border
	var border_emit: Color = tint * 0.6
	for side_data in _get_border_sides(size, 0.1):
		var border: MeshInstance3D = MeshInstance3D.new()
		var border_box: BoxMesh = BoxMesh.new()
		border_box.size = side_data["size"]
		border.mesh = border_box
		border.position = side_data["pos"]
		var border_mat: StandardMaterial3D = StandardMaterial3D.new()
		border_mat.emission_enabled = true
		border_mat.albedo_color = border_emit
		border_mat.emission = border_emit
		border_mat.emission_energy_multiplier = 0.5
		border.material_override = border_mat
		zone.add_child(border)

	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(size, 0.5, size)
	col.shape = shape
	col.position.y = 0.25
	zone.add_child(col)

	var can_damage: bool = true
	zone.body_entered.connect(func(body):
		if body.is_in_group("player") and body.has_method("take_damage") and can_damage:
			body.take_damage(8)
			can_damage = false
			get_tree().create_timer(0.5).timeout.connect(func(): can_damage = true)
	)

	hazard_root.add_child(zone)


func _place_damage_tile(index: int, total: int) -> void:
	var tile: Area3D = Area3D.new()
	var angle: float = (float(index) / float(total)) * TAU + randf() * 0.8
	var dist: float = 5.0 + randf() * 10.0
	tile.position = Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	tile.collision_layer = 0
	tile.collision_mask = 1

	var size: float = 3.0 + randf() * 2.0
	var tint: Color = current_palette.hazard_tint if current_palette else Color(0.5, 0.4, 0.0)

	# warning pattern — alternating strips
	var strip_count: int = clampi(int(size * 1.5), 3, 6)
	for i in strip_count:
		var strip: MeshInstance3D = MeshInstance3D.new()
		var strip_box: BoxMesh = BoxMesh.new()
		strip_box.size = Vector3(size, 0.03, size / strip_count * 0.6)
		strip.mesh = strip_box
		strip.position = Vector3(0, 0.02, (float(i) / strip_count - 0.5) * size)
		var strip_mat: StandardMaterial3D = StandardMaterial3D.new()
		if i % 2 == 0:
			strip_mat.albedo_color = Color(tint.r * 0.5, tint.g * 0.4, tint.b * 0.05, 1)
		else:
			strip_mat.albedo_color = Color(tint.r * 0.2, tint.g * 0.15, tint.b * 0.02, 1)
		strip_mat.emission_enabled = true
		strip_mat.emission = tint * 0.3
		strip_mat.emission_energy_multiplier = 0.2
		strip.material_override = strip_mat
		tile.add_child(strip)

	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(size, 0.3, size)
	col.shape = shape
	col.position.y = 0.15
	tile.add_child(col)

	var can_damage: bool = true
	tile.body_entered.connect(func(body):
		if body.is_in_group("player") and body.has_method("take_damage") and can_damage:
			body.take_damage(5)
			can_damage = false
			get_tree().create_timer(0.4).timeout.connect(func(): can_damage = true)
	)

	hazard_root.add_child(tile)


func _place_lava_pit(index: int, total: int) -> void:
	var pit: Area3D = Area3D.new()
	var angle: float = (float(index) / float(total)) * TAU + randf() * 0.6
	var dist: float = 6.0 + randf() * 10.0
	pit.position = Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	pit.collision_layer = 0
	pit.collision_mask = 1

	var size: float = 2.5 + randf() * 2.0
	var tint: Color = current_palette.hazard_tint if current_palette else Color(1.0, 0.2, 0.0)

	# sunken pit visual (slightly below floor level)
	var pit_mesh: MeshInstance3D = MeshInstance3D.new()
	var pit_box: BoxMesh = BoxMesh.new()
	pit_box.size = Vector3(size, 0.2, size)
	pit_mesh.mesh = pit_box
	pit_mesh.position.y = -0.05
	var pit_mat: StandardMaterial3D = StandardMaterial3D.new()
	pit_mat.albedo_color = Color(tint.r * 0.6, tint.g * 0.08, tint.b * 0.02, 1)
	pit_mat.emission_enabled = true
	pit_mat.emission = tint
	pit_mat.emission_energy_multiplier = 1.2
	pit_mesh.material_override = pit_mat
	pit.add_child(pit_mesh)

	# rim around the pit
	var rim_thickness: float = 0.15
	for side_data in _get_border_sides(size, rim_thickness):
		var rim: MeshInstance3D = MeshInstance3D.new()
		var rim_box: BoxMesh = BoxMesh.new()
		rim_box.size = side_data["size"] + Vector3(0, 0.12, 0)
		rim.mesh = rim_box
		rim.position = side_data["pos"] + Vector3(0, 0.06, 0)
		var rim_mat: StandardMaterial3D = StandardMaterial3D.new()
		rim_mat.albedo_color = _get_obstacle_color(0.02)
		rim.material_override = rim_mat
		pit.add_child(rim)

	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(size, 0.4, size)
	col.shape = shape
	col.position.y = 0.2
	pit.add_child(col)

	var can_damage: bool = true
	pit.body_entered.connect(func(body):
		if body.is_in_group("player") and body.has_method("take_damage") and can_damage:
			body.take_damage(10)
			can_damage = false
			get_tree().create_timer(0.6).timeout.connect(func(): can_damage = true)
	)

	hazard_root.add_child(pit)


func _get_border_sides(size: float, thickness: float) -> Array[Dictionary]:
	var h: float = size * 0.5
	return [
		{"size": Vector3(size, 0.04, thickness), "pos": Vector3(0, 0.02, h)},
		{"size": Vector3(size, 0.04, thickness), "pos": Vector3(0, 0.02, -h)},
		{"size": Vector3(thickness, 0.04, size), "pos": Vector3(h, 0.02, 0)},
		{"size": Vector3(thickness, 0.04, size), "pos": Vector3(-h, 0.02, 0)},
	]


func _clear_obstacles() -> void:
	if not arena_root:
		return
	var children: Array[Node] = arena_root.get_children()
	for child in children:
		arena_root.remove_child(child)
		child.free()


func _clear_hazards() -> void:
	if not hazard_root:
		return
	var children: Array[Node] = hazard_root.get_children()
	for child in children:
		hazard_root.remove_child(child)
		child.free()


func spawn_duplicate_enemy() -> void:
	if not active_room or enemies_alive <= 0:
		return

	var type: EnemyTypes.Type = EnemyComposition.get_composition(active_room.type, active_room.difficulty, 1)[0]
	var scene: PackedScene = _enemy_scenes.get(type, _enemy_scenes.get(EnemyTypes.Type.CHASER))
	if not scene:
		return

	_dup_counter += 1
	var instance: CharacterBody3D = scene.instantiate() as CharacterBody3D
	instance.name = "Dup_%d" % _dup_counter
	instance.global_position = _get_spawn_position()
	_scale_enemy(instance, active_room.difficulty, false)

	var health: HealthComponent = instance.get_node_or_null("HealthComponent") as HealthComponent
	if health:
		health.died.connect(_on_enemy_died)

	enemy_root.add_child(instance)
	_setup_enemy_multiplayer(instance)
	enemies_alive += 1


func clear_current_room() -> void:
	_clear_room()


func _clear_room() -> void:
	_clear_obstacles()
	_clear_hazards()
	_placed_obstacles.clear()
	if enemy_root:
		var children: Array[Node] = enemy_root.get_children()
		for child in children:
			enemy_root.remove_child(child)
			child.free()
	enemies_alive = 0
	room_active = false
	active_room = null
	active_boss = null
	_dup_counter = 0
	_gauntlet_waves_remaining = 0


func _setup_enemy_multiplayer(enemy: CharacterBody3D) -> void:
	# in multiplayer, host is authority for all enemies
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return

	enemy.set_multiplayer_authority(1)

	# add interpolator for smooth movement on clients
	var interp: NetworkInterpolator = NetworkInterpolator.new()
	interp.name = "NetInterp"
	enemy.add_child(interp)

	# add synchronizer — syncs interpolator targets, not raw position
	var sync: MultiplayerSynchronizer = MultiplayerSynchronizer.new()
	sync.name = "EnemySync"
	sync.set_multiplayer_authority(1)
	sync.replication_interval = 0.05  # 20 updates/sec

	var config: SceneReplicationConfig = SceneReplicationConfig.new()
	config.add_property(NodePath("%s:sync_position" % interp.get_path()))
	config.add_property(NodePath("%s:sync_rotation" % interp.get_path()))

	# sync health so clients see correct health values
	var hc: HealthComponent = enemy.get_node_or_null("HealthComponent") as HealthComponent
	if hc:
		config.add_property(NodePath("%s:current_health" % hc.get_path()))

	sync.replication_config = config
	enemy.add_child(sync)
