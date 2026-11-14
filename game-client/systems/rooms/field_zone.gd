class_name FieldZone
extends Area3D

# a marked patch of floor that changes whoever stands in it: hits harder,
# moves faster, takes less. it does the same to the brood as to you, so a
# field is somewhere to fight from, somewhere to keep them out of, or
# somewhere to drag them into.
#
# every peer builds its own copy from the room seed. each copy changes only
# the player that peer owns, and only the host's copy changes enemies.

const TICK: float = 0.3
const LINGER: float = 0.7
const GROUP: StringName = &"field_zones"

## stat   the player stat the field multiplies (and the enemy stat or status)
## enemy  how the same thing is done to an enemy: [status id, power]
const KINDS: Dictionary = {
	&"surge": {
		"name": "surge field", "text": "+30% damage", "color": Color(1.0, 0.45, 0.2),
		"stat": &"damage", "factor": 1.3, "enemy": [&"empower", 0.3],
	},
	&"damp": {
		"name": "dampening field", "text": "-30% damage", "color": Color(0.6, 0.62, 0.8),
		"stat": &"damage", "factor": 0.7, "enemy": [&"weaken", 0.3],
	},
	&"haste": {
		"name": "slipstream", "text": "+30% speed", "color": Color(0.3, 0.9, 1.0),
		"stat": &"move_speed", "factor": 1.3, "enemy": [&"haste", 0.3],
	},
	&"mire": {
		"name": "mire", "text": "-35% speed", "color": Color(0.7, 0.5, 0.25),
		"stat": &"move_speed", "factor": 0.65, "enemy": [&"slow", 0.35],
	},
	&"ward": {
		"name": "ward", "text": "30% less damage taken", "color": Color(0.9, 0.92, 1.0),
		"stat": &"damage_taken", "factor": 0.7, "enemy": [&"ward", 0.3],
	},
	&"frail": {
		"name": "frail ground", "text": "30% more damage taken", "color": Color(1.0, 0.3, 0.75),
		"stat": &"damage_taken", "factor": 1.3, "enemy": [&"frail", 0.3],
	},
	&"mend": {
		"name": "mending pool", "text": "slowly heals", "color": Color(0.4, 1.0, 0.5),
		"heal": 1, "enemy_heal": 0.007,
	},
}

var kind: StringName = &"surge"
var radius: float = 3.5

var _tick: float = 0.0
var _key: StringName = &""
var _players: Array[CharacterBody3D] = []
var _rim: MeshInstance3D
var _phase: float = 0.0


static func create(p_kind: StringName, p_radius: float) -> FieldZone:
	var z: FieldZone = FieldZone.new()
	z.kind = p_kind if KINDS.has(p_kind) else &"surge"
	z.radius = p_radius
	return z


static func display_name(id: StringName) -> String:
	return KINDS.get(id, {}).get("name", "")


static func effect_text(id: StringName) -> String:
	return KINDS.get(id, {}).get("text", "")


static func color_of(id: StringName) -> Color:
	return KINDS.get(id, {}).get("color", Color.WHITE)


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = 0
	collision_mask = Layers.PLAYER | Layers.ENEMY
	monitorable = false
	_key = StringName("field:%d" % get_instance_id())

	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = radius
	shape.height = 2.4
	col.shape = shape
	col.position.y = 1.2
	add_child(col)

	var tint: Color = color_of(kind)
	# a faint floor, a bright edge and an inner ring: a hazard is a filled
	# pool, a field is an outline you can read through
	var floor_disc: MeshInstance3D = Vfx.make_flat(0.0, Color(tint.r, tint.g, tint.b, 0.1))
	floor_disc.scale = Vector3(radius, 1.0, radius)
	floor_disc.position.y = Vfx.GROUND_Y
	add_child(floor_disc)
	_rim = Vfx.make_flat(0.93, Color(tint.r, tint.g, tint.b, 0.95))
	_rim.scale = Vector3(radius, 1.0, radius)
	_rim.position.y = Vfx.GROUND_Y + 0.01
	add_child(_rim)
	var inner: MeshInstance3D = Vfx.make_flat(0.9, Color(tint.r, tint.g, tint.b, 0.5))
	inner.scale = Vector3(radius * 0.55, 1.0, radius * 0.55)
	inner.position.y = Vfx.GROUND_Y + 0.01
	add_child(inner)

	var tag: Label3D = Label3D.new()
	tag.text = "%s\n%s" % [display_name(kind), effect_text(kind)]
	tag.font = UiKit.font_bold()
	tag.font_size = 44
	tag.pixel_size = 0.009
	tag.outline_size = 10
	tag.modulate = tint.lightened(0.25)
	tag.outline_modulate = Color(0, 0, 0, 0.8)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position.y = 2.7
	add_child(tag)

	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = tint
	light.light_energy = 0.9
	light.omni_range = radius * 1.6
	light.shadow_enabled = false
	light.position.y = 0.9
	add_child(light)

	_tick = randf() * TICK


func _exit_tree() -> void:
	for p: CharacterBody3D in _players:
		_release(p)
	_players.clear()


## true while this peer's own player is standing in the field.
func holds(player: CharacterBody3D) -> bool:
	return _players.has(player)


func _physics_process(delta: float) -> void:
	_phase += delta
	if _rim:
		var pulse: float = 1.0 + 0.025 * sin(_phase * 2.4)
		_rim.scale = Vector3(radius * pulse, 1.0, radius * pulse)

	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK

	var def: Dictionary = KINDS[kind]
	var inside: Array[CharacterBody3D] = []
	for body: Node3D in get_overlapping_bodies():
		if body.is_in_group("player"):
			if body.get("is_dead") == true or (Game.is_online() and not body.is_multiplayer_authority()):
				continue
			inside.append(body as CharacterBody3D)
		elif body is EnemyBase and Game.is_host_or_solo():
			_affect_enemy(body as EnemyBase, def)

	for p: CharacterBody3D in inside:
		if not _players.has(p):
			_players.append(p)
		_affect_player(p, def)
	for p: CharacterBody3D in _players.duplicate():
		if not inside.has(p):
			_players.erase(p)
			_release(p)


func _affect_player(p: CharacterBody3D, def: Dictionary) -> void:
	if def.has("stat") and "stats" in p:
		p.stats.set_mul(def.stat, _key, float(def.factor))
	if def.has("heal") and p.has_method("heal"):
		p.heal(int(def.heal))


func _release(p: CharacterBody3D) -> void:
	if is_instance_valid(p) and "stats" in p:
		p.stats.remove_key(_key)


func _affect_enemy(e: EnemyBase, def: Dictionary) -> void:
	if e.is_dying or e is BossBase:
		return
	if def.has("enemy"):
		# a short status, renewed for as long as it stays in the field
		e.apply_status(def.enemy[0], LINGER, float(def.enemy[1]))
	if def.has("enemy_heal") and e.health and e.health.is_alive():
		e.health.heal(maxi(1, int(e.health.max_health * float(def.enemy_heal))))
