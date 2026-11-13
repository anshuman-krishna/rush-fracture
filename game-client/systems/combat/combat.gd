class_name Combat
extends Node

# everything the local player does to an enemy goes through here: weapons,
# projectiles, explosions, damage-over-time, dash and aura effects.
#
# one place turns a base amount into a final hit (damage stat, crits, weak
# points), applies it, shows the feedback, and announces hits and kills. kill
# credit, combo, lifesteal and on-hit upgrades all listen to these signals, so
# a new damage source gets every one of those behaviours for free.

signal enemy_hit(enemy: Node3D, info: DamageInfo)
signal enemy_killed(enemy: Node3D, info: DamageInfo)

const COLOR_NORMAL: Color = Color(1.0, 0.95, 0.85)
const COLOR_WEAK: Color = Color(1.0, 0.8, 0.2)
const COLOR_CRIT: Color = Color(1.0, 0.35, 0.2)
const COLOR_DOT: Color = Color(0.7, 1.0, 0.5)
const COLOR_SHIELD: Color = Color(0.5, 0.8, 1.0)

var player: CharacterBody3D
var pvp_manager: PvPManager
## callables (target, info, amount) -> float, run on every hit before it
## lands. for effects that depend on the target (execute thresholds, marks).
var pre_damage_hooks: Array[Callable] = []

## running totals for the summary screen
var total_damage: int = 0
var crit_hits: int = 0
var weak_hits: int = 0
var shots_landed: int = 0


func bind(p_player: CharacterBody3D) -> void:
	player = p_player


func reset_totals() -> void:
	total_damage = 0
	crit_hits = 0
	weak_hits = 0
	shots_landed = 0


## deals `base` damage to one target.
##
## opts (all optional):
##   kind       DamageInfo.KIND_* (default bullet)
##   position   world hit position (default: target centre)
##   direction  travel direction of the hit, for knockback
##   weapon     weapon id, for per-weapon effects
##   weak       true if the hit landed on a weak point
##   weak_mult  weak point multiplier (default 1.5)
##   mult       extra multiplier from the caller
##   can_crit   default true
##   can_proc   default true; false for damage caused by an on-hit effect
##   knockback  impulse applied to the target
##   quiet      skip floating number and hit sound
##
## returns the DamageInfo that was applied, or null if nothing was hit.
func deal(target: Node, base: float, opts: Dictionary = {}) -> DamageInfo:
	if not is_instance_valid(target) or not target is Node3D:
		return null

	if target.is_in_group("player"):
		_deal_pvp(target as CharacterBody3D, base)
		return null

	var health: HealthComponent = target.get_node_or_null("HealthComponent") as HealthComponent
	if not health or not health.is_alive():
		return null
	# spawning in or changing phase: the hit does nothing, so it shows nothing
	if health.invulnerable:
		return null

	var stats: StatBlock = player.stats if is_instance_valid(player) and "stats" in player else null
	var info: DamageInfo = DamageInfo.new()
	info.kind = opts.get("kind", DamageInfo.KIND_BULLET)
	info.source = player
	info.weapon = opts.get("weapon", &"")
	info.can_proc = opts.get("can_proc", true)
	info.knockback = opts.get("knockback", 0.0)
	info.direction = opts.get("direction", Vector3.ZERO)
	info.position = opts.get("position", _centre_of(target as Node3D))
	info.weak = opts.get("weak", false)

	var amount: float = base * float(opts.get("mult", 1.0))
	if stats:
		amount *= stats.value(&"damage")
		if info.kind == DamageInfo.KIND_BLAST:
			amount *= stats.value(&"blast_damage")
		elif info.kind == DamageInfo.KIND_DOT:
			amount *= stats.value(&"dot_damage")
		if info.weak:
			amount *= float(opts.get("weak_mult", 1.5)) * stats.value(&"weak_damage")
		if opts.get("can_crit", true) and randf() < stats.value(&"crit_chance"):
			info.crit = true
			amount *= stats.value(&"crit_mult")
	elif info.weak:
		amount *= float(opts.get("weak_mult", 1.5))

	for hook: Callable in pre_damage_hooks:
		if hook.is_valid():
			amount = float(hook.call(target, info, amount))

	if target.has_method("modify_incoming"):
		amount = target.modify_incoming(amount, info)
		if amount <= 0.0:
			if not opts.get("quiet", false):
				Vfx.text(info.position, "blocked", COLOR_SHIELD)
			return null

	info.amount = maxi(1, int(round(amount)))
	var had_shield: bool = health.shield > 0
	var killed: bool = health.take_damage(info.amount, info)

	total_damage += info.amount
	shots_landed += 1
	if info.crit:
		crit_hits += 1
	if info.weak:
		weak_hits += 1

	if not opts.get("quiet", false):
		var color: Color = COLOR_NORMAL
		if had_shield:
			color = COLOR_SHIELD
		elif info.crit:
			color = COLOR_CRIT
		elif info.weak:
			color = COLOR_WEAK
		elif info.kind == DamageInfo.KIND_DOT:
			color = COLOR_DOT
		Vfx.number(info.position, info.amount, color, info.crit)

	if info.knockback > 0.0 and target.has_method("apply_knockback"):
		var dir: Vector3 = info.direction
		if dir.length() < 0.01 and is_instance_valid(player):
			dir = (target as Node3D).global_position - player.global_position
		target.apply_knockback(dir, info.knockback)

	enemy_hit.emit(target, info)
	if killed:
		enemy_killed.emit(target, info)
	return info


## multiplayer: the host says this peer landed the killing blow on `target`.
## a client cannot see that for itself, since it never changes enemy health.
func credit_kill(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	var info: DamageInfo = DamageInfo.new()
	info.source = player
	info.position = _centre_of(target)
	enemy_killed.emit(target, info)


## damages every enemy inside a sphere, with linear falloff to `min_ratio` at
## the edge. returns how many enemies were hit.
func blast(centre: Vector3, radius: float, base: float, opts: Dictionary = {}) -> int:
	var hits: int = 0
	var min_ratio: float = opts.get("min_ratio", 0.35)
	var o: Dictionary = opts.duplicate()
	o["kind"] = opts.get("kind", DamageInfo.KIND_BLAST)
	o["can_proc"] = opts.get("can_proc", false)
	if not o.has("knockback"):
		o["knockback"] = 6.0
	for enemy: Node3D in enemies_in_radius(get_tree(), centre, radius):
		var d: float = _centre_of(enemy).distance_to(centre)
		var falloff: float = lerpf(1.0, min_ratio, clampf(d / radius, 0.0, 1.0))
		o["position"] = _centre_of(enemy)
		o["direction"] = enemy.global_position - centre
		if deal(enemy, base * falloff, o):
			hits += 1
	var rooms: RoomController = Game.rooms()
	if rooms:
		rooms.damage_breakables_in_radius(centre, radius)
	return hits


func _deal_pvp(target: CharacterBody3D, base: float) -> void:
	if not pvp_manager or not pvp_manager.is_active() or not is_instance_valid(player) or target == player:
		return
	var amount: float = base
	if "stats" in player:
		amount *= player.stats.value(&"damage")
	pvp_manager.try_pvp_damage(player, target, int(round(amount)))


static func _centre_of(node: Node3D) -> Vector3:
	if node.has_method("aim_point"):
		return node.aim_point()
	return node.global_position + Vector3(0, 0.8, 0)


# --- queries ---------------------------------------------------------------

static func living_enemies(tree: SceneTree) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for e: Node in tree.get_nodes_in_group("enemies"):
		if not e is Node3D or not is_instance_valid(e):
			continue
		if e.get("is_dying"):
			continue
		var hc: HealthComponent = e.get_node_or_null("HealthComponent") as HealthComponent
		if hc and not hc.is_alive():
			continue
		out.append(e)
	return out


static func enemies_in_radius(tree: SceneTree, centre: Vector3, radius: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var r2: float = radius * radius
	for e: Node3D in living_enemies(tree):
		# measure to the body centre, padded by the body radius, so large
		# enemies are caught when the blast touches their edge
		var pad: float = e.get("body_radius") if e.get("body_radius") != null else 0.4
		var d2: float = _centre_of(e).distance_squared_to(centre)
		if d2 <= (radius + pad) * (radius + pad) or d2 <= r2:
			out.append(e)
	return out


static func nearest_enemy(tree: SceneTree, from: Vector3, max_distance: float, exclude: Array = []) -> Node3D:
	var best: Node3D = null
	var best_d: float = max_distance * max_distance
	for e: Node3D in living_enemies(tree):
		if e in exclude:
			continue
		var d: float = _centre_of(e).distance_squared_to(from)
		if d < best_d:
			best_d = d
			best = e
	return best
