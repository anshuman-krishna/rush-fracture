class_name RoomController
extends Node3D

# manages a single room lifecycle: spawn enemies, track completion, clean up.
# reconfigures the arena in-place between rooms — no scene swapping.

signal all_enemies_dead
signal enemy_killed
signal boss_defeated

@export var spawn_radius := 22.0
@export var min_spawn_distance := 6.0

var active_room: RunData.RoomData
var enemies_alive := 0
var room_active := false
var _enemy_scenes := {}
var _boss_scene: PackedScene
var active_boss: BossController
var current_palette: RoomPalette

@onready var arena_root: Node3D = $ArenaRoot
@onready var enemy_root: Node3D = $EnemyRoot
@onready var hazard_root: Node3D = $HazardRoot


func _ready() -> void:
	_preload_enemy_scenes()
	_preload_boss_scene()


func enter_room(room: RunData.RoomData) -> void:
	_clear_room()
	active_room = room
	room_active = false
	current_palette = RoomPalette.pick_for_room(
		room.id.get_slice("_", 1).to_int(), room.type)

	_configure_arena(room)
	_apply_palette()
	_place_hazards(room)

	await get_tree().create_timer(0.4).timeout

	if room.type == RoomDefinitions.RoomType.BOSS:
		_spawn_boss(room)
	else:
		_spawn_enemies(room)
	room_active = true


func _preload_enemy_scenes() -> void:
	for type in EnemyTypes.Type.values():
		var path := EnemyTypes.scene_path(type)
		if ResourceLoader.exists(path):
			_enemy_scenes[type] = load(path)


func _preload_boss_scene() -> void:
	var path := "res://scenes/enemies/boss_fracture_titan.tscn"
	if ResourceLoader.exists(path):
		_boss_scene = load(path)


func _spawn_enemies(room: RunData.RoomData) -> void:
	var count := room.enemy_budget
	var is_elite := room.type == RoomDefinitions.RoomType.ELITE
	var composition := EnemyComposition.get_composition(room.type, room.difficulty, count)
	enemies_alive = 0

	for i in composition.size():
		var type := composition[i]
		var scene: PackedScene = _enemy_scenes.get(type, _enemy_scenes.get(EnemyTypes.Type.CHASER))
		if not scene:
			continue

		var instance := scene.instantiate() as CharacterBody3D
		instance.global_position = _get_spawn_position()

		_scale_enemy(instance, room.difficulty, is_elite and i == 0)

		# apply cursed enemy speed bonus
		var speed_bonus: float = room.metadata.get("enemy_speed_bonus", 0.0)
		if speed_bonus > 0 and "move_speed" in instance:
			instance.move_speed *= (1.0 + speed_bonus)

		var health := instance.get_node_or_null("HealthComponent") as HealthComponent
		if health:
			health.died.connect(_on_enemy_died)

		enemy_root.add_child(instance)
		enemies_alive += 1


func _spawn_boss(room: RunData.RoomData) -> void:
	if not _boss_scene:
		return

	active_boss = _boss_scene.instantiate() as BossController
	active_boss.global_position = Vector3(0, 1.0, -15.0)

	# scale boss health by difficulty
	var bh := active_boss.get_node_or_null("HealthComponent") as HealthComponent
	if bh:
		bh.max_health = int(bh.max_health * room.difficulty)
		bh.current_health = bh.max_health
		bh.died.connect(_on_enemy_died)

	active_boss.boss_defeated.connect(_on_boss_defeated)
	enemy_root.add_child(active_boss)
	enemies_alive = 1


func _on_boss_defeated() -> void:
	boss_defeated.emit()


func _scale_enemy(enemy: CharacterBody3D, difficulty: float, is_elite_unit: bool) -> void:
	var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
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
	var mesh := enemy.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not mesh:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.05, 0.05, 1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.1, 0.0)
	mat.emission_energy_multiplier = 1.5
	mesh.set_surface_override_material(0, mat)


func _on_enemy_died() -> void:
	enemies_alive -= 1
	enemy_killed.emit()
	if enemies_alive <= 0 and room_active:
		room_active = false
		all_enemies_dead.emit()


func _get_spawn_position() -> Vector3:
	var angle := randf() * TAU
	var distance := min_spawn_distance + randf() * (spawn_radius - min_spawn_distance)
	return Vector3(cos(angle) * distance, 1.0, sin(angle) * distance)


func _configure_arena(room: RunData.RoomData) -> void:
	_clear_obstacles()
	if room.type == RoomDefinitions.RoomType.RECOVERY or room.type == RoomDefinitions.RoomType.BOSS:
		return

	var obstacle_count := 0
	match room.type:
		RoomDefinitions.RoomType.COMBAT:
			obstacle_count = clampi(int(room.difficulty * 2), 2, 6)
		RoomDefinitions.RoomType.SWARM:
			obstacle_count = clampi(int(room.difficulty), 1, 3)
		RoomDefinitions.RoomType.ELITE:
			obstacle_count = clampi(int(room.difficulty * 1.5), 2, 5)

	for i in obstacle_count:
		_place_obstacle(i, obstacle_count, room)


func _apply_palette() -> void:
	if not current_palette:
		return

	# floor material
	var floor_node := get_node_or_null("/root/Main/Floor/FloorMesh") as MeshInstance3D
	if floor_node:
		var mat := floor_node.get_surface_override_material(0)
		if not mat:
			mat = StandardMaterial3D.new()
			floor_node.set_surface_override_material(0, mat)
		if mat is StandardMaterial3D:
			mat.albedo_color = current_palette.floor_color
			mat.emission_enabled = true
			mat.emission = current_palette.floor_emission
			mat.emission_energy_multiplier = 0.3

	# directional light
	var light := get_node_or_null("/root/Main/DirectionalLight3D") as DirectionalLight3D
	if light:
		light.light_color = current_palette.light_color
		light.light_energy = current_palette.light_energy


func _place_obstacle(index: int, total: int, room: RunData.RoomData) -> void:
	var pillar := StaticBody3D.new()
	var angle := (float(index) / float(total)) * TAU + randf() * 0.5
	var dist := 6.0 + randf() * 10.0
	pillar.position = Vector3(cos(angle) * dist, 0, sin(angle) * dist)

	var height := 1.5 + randf() * 2.0
	var width := 0.8 + randf() * 0.6

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, height, width)
	mesh.mesh = box
	mesh.position.y = height / 2.0

	var mat := StandardMaterial3D.new()
	if current_palette:
		var c := current_palette.obstacle_color
		mat.albedo_color = Color(c.r + randf() * 0.03, c.g + randf() * 0.03, c.b + randf() * 0.03, 1)
	else:
		var shade := 0.08 + room.difficulty * 0.02
		mat.albedo_color = Color(shade, shade, shade + 0.02, 1)
	mesh.material_override = mat

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, width)
	col.shape = shape
	col.position.y = height / 2.0

	pillar.add_child(mesh)
	pillar.add_child(col)
	pillar.collision_layer = 1
	arena_root.add_child(pillar)


func _place_hazards(room: RunData.RoomData) -> void:
	_clear_hazards()
	if room.type == RoomDefinitions.RoomType.RECOVERY or room.type == RoomDefinitions.RoomType.BOSS:
		return

	var hazard_count := 0
	if room.difficulty >= 1.4:
		hazard_count = clampi(int((room.difficulty - 1.2) * 3), 1, 5)

	for i in hazard_count:
		if randf() < 0.6:
			_place_spike_zone(i, hazard_count)
		else:
			_place_damage_tile(i, hazard_count)


func _place_spike_zone(index: int, total: int) -> void:
	var zone := Area3D.new()
	var angle := (float(index) / float(total)) * TAU + randf() * 1.0
	var dist := 4.0 + randf() * 12.0
	zone.position = Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	zone.collision_layer = 0
	zone.collision_mask = 1

	var size := 2.0 + randf() * 2.0

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size, 0.15, size)
	mesh.mesh = box
	mesh.position.y = 0.08

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.08, 0.05, 1)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.1, 0.0, 1)
	mat.emission_energy_multiplier = 0.6
	mesh.material_override = mat

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size, 0.5, size)
	col.shape = shape
	col.position.y = 0.25

	zone.add_child(mesh)
	zone.add_child(col)

	zone.body_entered.connect(func(body):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(8)
	)

	hazard_root.add_child(zone)


func _place_damage_tile(index: int, total: int) -> void:
	var tile := Area3D.new()
	var angle := (float(index) / float(total)) * TAU + randf() * 0.8
	var dist := 5.0 + randf() * 10.0
	tile.position = Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	tile.collision_layer = 0
	tile.collision_mask = 1

	var size := 3.0 + randf() * 2.0

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size, 0.05, size)
	mesh.mesh = box
	mesh.position.y = 0.03

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.3, 0.05, 1)
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.4, 0.0, 1)
	mat.emission_energy_multiplier = 0.3
	mesh.material_override = mat

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size, 0.3, size)
	col.shape = shape
	col.position.y = 0.15

	tile.add_child(mesh)
	tile.add_child(col)

	var damage_timer := 0.0
	tile.body_entered.connect(func(body):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(5)
	)

	hazard_root.add_child(tile)


func _clear_obstacles() -> void:
	if not arena_root:
		return
	for child in arena_root.get_children():
		child.queue_free()


func _clear_hazards() -> void:
	if not hazard_root:
		return
	for child in hazard_root.get_children():
		child.queue_free()


func spawn_duplicate_enemy() -> void:
	if not active_room or enemies_alive <= 0:
		return

	var type := EnemyComposition.get_composition(active_room.type, active_room.difficulty, 1)[0]
	var scene: PackedScene = _enemy_scenes.get(type, _enemy_scenes.get(EnemyTypes.Type.CHASER))
	if not scene:
		return

	var instance := scene.instantiate() as CharacterBody3D
	instance.global_position = _get_spawn_position()
	_scale_enemy(instance, active_room.difficulty, false)

	var health := instance.get_node_or_null("HealthComponent") as HealthComponent
	if health:
		health.died.connect(_on_enemy_died)

	enemy_root.add_child(instance)
	enemies_alive += 1


func clear_current_room() -> void:
	_clear_room()


func _clear_room() -> void:
	_clear_obstacles()
	_clear_hazards()
	if enemy_root:
		for child in enemy_root.get_children():
			child.queue_free()
	enemies_alive = 0
	room_active = false
	active_room = null
	active_boss = null
