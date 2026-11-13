class_name WeaponManager
extends Node3D

# the player's loadout: builds the equipped weapons, routes trigger input to
# the held one, and handles switching. weapon damage and fire rate scale off
# the owning player's stats, so nothing here stores multipliers of its own.

signal weapon_switched(weapon: BaseWeapon)
signal weapon_fired(weapon: BaseWeapon)
signal loadout_changed

var weapons: Array[BaseWeapon] = []
var active_index: int = 0
var skin_id: StringName = &"default"

var _player: CharacterBody3D
var _camera: Camera3D
var _was_held: bool = false


func _ready() -> void:
	_player = get_parent().get_parent() as CharacterBody3D
	_camera = get_node_or_null("../Camera3D") as Camera3D
	if weapons.is_empty():
		set_loadout(WeaponDefs.DEFAULT_LOADOUT)
	# a puppet of another player shows their body, not a floating gun
	if not _is_local_authority():
		visible = false


func _process(delta: float) -> void:
	if weapons.is_empty() or not _is_local_authority():
		return

	var provider: InputProvider = _input_provider()
	var locked: bool = not is_instance_valid(_player) or _player.get("is_dead") == true or _player.get("controls_locked") == true
	var held: bool = provider.is_shoot_held() if provider and not locked else false
	var pressed: bool = held and not _was_held
	var released: bool = _was_held and not held
	_was_held = held

	if provider and not locked:
		if provider.is_weapon_1_pressed():
			switch_to(0)
		elif provider.is_weapon_2_pressed():
			switch_to(1)
		elif provider.is_weapon_3_pressed():
			switch_to(2)
		else:
			var step: int = provider.get_weapon_cycle()
			if step != 0:
				switch_to(posmod(active_index + step, weapons.size()))

	for i: int in weapons.size():
		if i == active_index:
			weapons[i].tick(delta, held, pressed, released)
		else:
			weapons[i].tick_holstered(delta)


## replaces the whole loadout. unknown ids are skipped.
func set_loadout(ids: Array) -> void:
	for w: BaseWeapon in weapons:
		if is_instance_valid(w):
			remove_child(w)
			w.queue_free()
	weapons.clear()

	for raw: Variant in ids:
		var weapon: BaseWeapon = WeaponDefs.create(StringName(String(raw)))
		if not weapon:
			continue
		add_child(weapon)
		weapon.setup(_player, _camera)
		weapon.set_skin(skin_id)
		weapon.fired.connect(_on_weapon_fired.bind(weapon))
		weapons.append(weapon)

	active_index = 0
	if not weapons.is_empty():
		weapons[0].set_active(true)
		weapon_switched.emit(weapons[0])
	loadout_changed.emit()


func set_skin(id: StringName) -> void:
	skin_id = id
	for w: BaseWeapon in weapons:
		w.set_skin(id)


func switch_to(index: int) -> void:
	if index < 0 or index >= weapons.size() or index == active_index:
		return
	weapons[active_index].set_active(false)
	active_index = index
	weapons[active_index].set_active(true)
	Game.sfx(&"weapon_swap", -10.0, 0.05)
	weapon_switched.emit(weapons[active_index])


func get_active_weapon() -> BaseWeapon:
	if weapons.is_empty():
		return null
	return weapons[active_index]


func get_weapon(id: StringName) -> BaseWeapon:
	for w: BaseWeapon in weapons:
		if w.weapon_id == id:
			return w
	return null


func get_weapon_name() -> String:
	var w: BaseWeapon = get_active_weapon()
	return w.display_name if w else ""


## clears every weapon's per-run state and upgrade flags.
func reset_for_run() -> void:
	for w: BaseWeapon in weapons:
		w.clear_flags()
		w.reset_state()
	if not weapons.is_empty() and active_index != 0:
		switch_to(0)


## sets an upgrade flag on one weapon id, or on every weapon when id is empty.
func set_weapon_flag(id: StringName, flag: StringName, value: Variant = true) -> void:
	for w: BaseWeapon in weapons:
		if id == &"" or w.weapon_id == id:
			w.set_flag(flag, value)


func has_weapon(id: StringName) -> bool:
	return get_weapon(id) != null


func _on_weapon_fired(weapon: BaseWeapon) -> void:
	weapon_fired.emit(weapon)


func _input_provider() -> InputProvider:
	if is_instance_valid(_player) and "input" in _player:
		return _player.input
	return null


func _is_local_authority() -> bool:
	if not is_instance_valid(_player) or not Game.is_online():
		return true
	return _player.is_multiplayer_authority()
