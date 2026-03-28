class_name WeaponManager
extends Node3D

# manages weapon inventory, switching, and stat multipliers.
# forwards signals from active weapon to external systems.
# preserves upgrade multipliers across weapon switches.

signal enemy_killed
signal enemy_hit(position: Vector3)
signal weapon_switched(weapon_name: String)

enum WeaponSlot { PULSE_RIFLE, SCATTER_CANNON, BEAM_EMITTER }

var active_slot: WeaponSlot = WeaponSlot.PULSE_RIFLE
var weapons: Array[Node3D] = []

# global multipliers applied by upgrades — persist across switches
var damage_multiplier := 1.0
var fire_rate_multiplier := 1.0
var shake_multiplier := 1.0

# proxy properties for upgrade_manager compatibility
var damage: int:
	get: return int(_active().base_damage * damage_multiplier)
	set(value):
		if _active().base_damage > 0:
			damage_multiplier = float(value) / float(_active().base_damage)

var fire_rate: float:
	get: return _active().base_fire_rate * fire_rate_multiplier
	set(value):
		if _active().base_fire_rate > 0:
			fire_rate_multiplier = value / _active().base_fire_rate

var shake_on_fire: float:
	get: return _active().shake_on_fire * shake_multiplier
	set(value):
		if _active().shake_on_fire > 0:
			shake_multiplier = value / _active().shake_on_fire


func _ready() -> void:
	_init_weapons()
	_activate(active_slot)


func _process(_delta: float) -> void:
	if Input.is_action_pressed("shoot"):
		_try_fire()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("weapon_1"):
		switch_to(WeaponSlot.PULSE_RIFLE)
	elif event.is_action_pressed("weapon_2"):
		switch_to(WeaponSlot.SCATTER_CANNON)
	elif event.is_action_pressed("weapon_3"):
		switch_to(WeaponSlot.BEAM_EMITTER)


func switch_to(slot: WeaponSlot) -> void:
	if slot == active_slot:
		return
	_deactivate(active_slot)
	active_slot = slot
	_activate(slot)
	weapon_switched.emit(get_weapon_name())


func get_weapon_name() -> String:
	return _active().get_weapon_name()


func get_active_weapon() -> Node3D:
	return _active()


func get_beam_heat_ratio() -> float:
	var beam := weapons[WeaponSlot.BEAM_EMITTER] as BeamEmitter
	return beam.get_heat_ratio()


func is_beam_overheated() -> bool:
	var beam := weapons[WeaponSlot.BEAM_EMITTER] as BeamEmitter
	return beam.is_overheated()


func reset_multipliers() -> void:
	damage_multiplier = 1.0
	fire_rate_multiplier = 1.0
	shake_multiplier = 1.0


func _init_weapons() -> void:
	var pulse := PulseRifle.new()
	pulse.name = "PulseRifle"
	add_child(pulse)

	var scatter := ScatterCannon.new()
	scatter.name = "ScatterCannon"
	add_child(scatter)

	var beam := BeamEmitter.new()
	beam.name = "BeamEmitter"
	add_child(beam)

	weapons = [pulse, scatter, beam]

	for w in weapons:
		w.enemy_killed.connect(func(): enemy_killed.emit())
		w.enemy_hit.connect(func(pos: Vector3): enemy_hit.emit(pos))
		w.visible = false
		w.set_process(false)


func _activate(slot: WeaponSlot) -> void:
	var w := weapons[slot]
	w.visible = true
	w.set_process(true)


func _deactivate(slot: WeaponSlot) -> void:
	var w := weapons[slot]
	w.visible = false
	w.set_process(false)


func _try_fire() -> void:
	var w := _active()
	var eff_damage := int(w.base_damage * damage_multiplier)
	var eff_rate := w.base_fire_rate * fire_rate_multiplier
	w.try_fire(eff_damage, eff_rate)


func _active() -> Node3D:
	return weapons[active_slot]
