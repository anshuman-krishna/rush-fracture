class_name MutationManager
extends Node

# applies and tracks mutations — powerful modifiers with downsides.
# mutations are offered at specific points during a run.

signal mutation_applied(mutation: Dictionary)

var active_mutations: Array[Dictionary] = []
var _player: CharacterBody3D
var _weapon_manager: WeaponManager

# blood pact state
var _blood_pact_active: bool = false
var _blood_pact_timer: float = 0.0
var _blood_pact_interval: float = 1.0

# unstable core state
var _unstable_core_active: bool = false

# momentum shield state
var _momentum_shield_active: bool = false

# fracture echo state
var _fracture_echo_active: bool = false
var _fracture_echo_base_multiplier: float = 0.0
var _fracture_echo_in_fracture: bool = false


func bind(player: CharacterBody3D, weapon_manager: WeaponManager) -> void:
	_player = player
	_weapon_manager = weapon_manager


func _process(delta: float) -> void:
	if _blood_pact_active and _player:
		_blood_pact_timer += delta
		if _blood_pact_timer >= _blood_pact_interval:
			_blood_pact_timer -= _blood_pact_interval
			_player.take_damage(2)


func apply(mutation: Dictionary) -> void:
	var type: MutationDefinitions.MutationType = mutation.get("type")
	active_mutations.append(mutation)

	match type:
		MutationDefinitions.MutationType.GLASS_CANNON:
			_apply_glass_cannon()
		MutationDefinitions.MutationType.OVERCLOCK:
			_apply_overclock()
		MutationDefinitions.MutationType.BLOOD_PACT:
			_apply_blood_pact()
		MutationDefinitions.MutationType.UNSTABLE_CORE:
			_apply_unstable_core()
		MutationDefinitions.MutationType.VELOCITY_ADDICT:
			_apply_velocity_addict()
		MutationDefinitions.MutationType.TEMPORAL_DISTORTION:
			_apply_temporal_distortion()
		MutationDefinitions.MutationType.MOMENTUM_SHIELD:
			_momentum_shield_active = true
		MutationDefinitions.MutationType.FRACTURE_ECHO:
			_fracture_echo_active = true
			if _weapon_manager:
				_fracture_echo_base_multiplier = _weapon_manager.damage_multiplier
				_weapon_manager.damage_multiplier = _fracture_echo_base_multiplier * 0.8

	mutation_applied.emit(mutation)


func on_enemy_killed() -> void:
	if _blood_pact_active and _player:
		_player.health = mini(_player.health + 8, _player.max_health)

	for m in active_mutations:
		if m.get("type") == MutationDefinitions.MutationType.TEMPORAL_DISTORTION:
			_trigger_time_slow()
			break


func on_enemy_hit(hit_position: Vector3) -> void:
	if not _unstable_core_active:
		return

	# 20% chance to explode nearby enemies
	if randf() < 0.2:
		_core_explosion(hit_position)

	# 10% chance to self-damage
	if randf() < 0.1 and _player:
		_player.take_damage(5)


func has_mutation(type: MutationDefinitions.MutationType) -> bool:
	for m in active_mutations:
		if m.get("type") == type:
			return true
	return false


func get_mutation_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for m in active_mutations:
		names.append(m.get("name", ""))
	return names


func get_damage_multiplier() -> float:
	# momentum shield: moving fast = less damage, standing still = more
	if _momentum_shield_active and _player:
		var speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
		if speed > 8.0:
			return 0.6
		elif speed < 2.0:
			return 1.4
	return 1.0


func on_fracture_started() -> void:
	if _fracture_echo_active and _weapon_manager:
		_fracture_echo_in_fracture = true
		_weapon_manager.damage_multiplier = _fracture_echo_base_multiplier * 1.35


func on_fracture_ended() -> void:
	if _fracture_echo_active and _weapon_manager:
		_fracture_echo_in_fracture = false
		_weapon_manager.damage_multiplier = _fracture_echo_base_multiplier * 0.8


func reset() -> void:
	active_mutations.clear()
	_blood_pact_active = false
	_blood_pact_timer = 0.0
	_unstable_core_active = false
	_momentum_shield_active = false
	_fracture_echo_active = false
	_fracture_echo_base_multiplier = 0.0
	_fracture_echo_in_fracture = false


func _apply_glass_cannon() -> void:
	if _weapon_manager:
		_weapon_manager.damage_multiplier *= 1.5
	if _player:
		_player.max_health = int(_player.max_health * 0.6)
		_player.health = mini(_player.health, _player.max_health)


func _apply_overclock() -> void:
	if _weapon_manager:
		_weapon_manager.fire_rate_multiplier *= 0.6
	var beam: BeamEmitter = _weapon_manager.get_node_or_null("BeamEmitter") as BeamEmitter
	if beam:
		beam.heat_per_tick *= 2.0


func _apply_blood_pact() -> void:
	_blood_pact_active = true
	_blood_pact_timer = 0.0


func _apply_unstable_core() -> void:
	_unstable_core_active = true


func _apply_velocity_addict() -> void:
	if _player:
		_player.move_speed *= 1.4
		_player.air_friction *= 0.5
		_player.friction *= 0.75


func _apply_temporal_distortion() -> void:
	if _player:
		_player.move_speed *= 0.8


func _trigger_time_slow() -> void:
	Engine.time_scale = 0.35
	get_tree().create_timer(0.5, true, false, true).timeout.connect(func():
		Engine.time_scale = 1.0
	)


func _core_explosion(position: Vector3) -> void:
	var radius: float = 4.0
	var damage: int = 15
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not enemy is Node3D:
			continue
		if enemy.global_position.distance_to(position) < radius:
			var health: HealthComponent = enemy.get_node_or_null("HealthComponent") as HealthComponent
			if health and health.is_alive():
				health.take_damage(damage)
