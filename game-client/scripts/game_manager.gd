extends Node

# coordinates a run: starts it, moves it from room to room, hands out
# rewards, reacts to combat events, and ends it.
#
# it owns no gameplay rules of its own. each system (rooms, combat, upgrades,
# mutations, fracture, combo) does its job; this script listens to their
# signals and decides what happens next.
#
# multiplayer: the host owns room progression, path choices, fracture events
# and the run's outcome, and broadcasts them. rewards are per player and stay
# local.

const CONTINUE_PROMPT: String = "press %s to continue"
const HEAL_ROOM_RATIO: float = 0.4
const BOSS_HEAL_RATIO: float = 0.3
const READY_TIMEOUT: float = 8.0

const SHOP_PRICES: Dictionary = {
	UpgradeDefinitions.RARITY_COMMON: 35,
	UpgradeDefinitions.RARITY_RARE: 55,
	UpgradeDefinitions.RARITY_EPIC: 85,
	UpgradeDefinitions.RARITY_CURSED: 30,
}

@onready var player_manager: PlayerManager = $"../PlayerManager"
@onready var player_spawner: PlayerSpawner = $"../PlayerSpawner"
@onready var run_manager: RunManager = $"../RunManager"
@onready var room_controller: RoomController = $"../RoomController"
@onready var upgrade_manager: UpgradeManager = $"../UpgradeManager"
@onready var fracture_manager: FractureManager = $"../FractureManager"
@onready var combo_tracker: ComboTracker = $"../ComboTracker"
@onready var mutation_manager: MutationManager = $"../MutationManager"
@onready var difficulty_tracker: DifficultyTracker = $"../DifficultyTracker"
@onready var audio: AudioManager = $"../AudioManager"
@onready var game_feel: GameFeel = $"../GameFeel"
@onready var combat: Combat = $"../Combat"
@onready var damage_vignette: ColorRect = $"../UI/DamageVignette"
@onready var hud: Hud = $"../UI/Hud"
@onready var room_announce: Control = $"../UI/RoomAnnounce"
@onready var upgrade_ui: Control = $"../UI/UpgradeSelection"
@onready var mutation_ui: Control = $"../UI/MutationSelection"
@onready var path_ui: Control = $"../UI/PathChoice"
@onready var shop_ui: Control = $"../UI/Shop"
@onready var summary_ui: Control = $"../UI/RunSummary"
@onready var pause_menu: Control = $"../UI/PauseMenu"

var player: CharacterBody3D
var weapon_manager: WeaponManager
var camera: Camera3D
var network_manager: NetworkManager
var game_mode: GameModeManager
var pvp_manager: PvPManager

# read by the pause menu and the playtest bot
var awaiting_upgrade: bool = false
var awaiting_mutation: bool = false
var awaiting_transition: bool = false
var awaiting_path: bool = false
var awaiting_shop: bool = false

var _profile: PlayerProfile
var _settings: GameSettings
var _run_cfg: Dictionary = {}
var _reward_queue: Array[StringName] = []
var _shop_items: Array[Dictionary] = []
var _shared_enemy_speed_bonus: float = 0.0
var _pvp_active: bool = false
var _match_ended: bool = false
var _onboarding: OnboardingOverlay
var _fracture_delay: float = -1.0
var _head_start: float = 0.0
var _scavenger_used: bool = false
var _momentum_start_used: bool = false
var _room_flawless: bool = true
var _flawless_boss: bool = false
var _bosses_killed: Array[StringName] = []
var _hit_sound_cooldown: float = 0.0
var _down_peers: Dictionary = {}
var _ready_peers: Dictionary = {}
var _waiting_for_peers: float = -1.0
var _death_timer: float = -1.0
var _dash_from: Vector3


# --- setup ----------------------------------------------------------------------

func _enter_tree() -> void:
	# every node's _enter_tree runs before any node's _ready, so by the time
	# anything in the scene starts up, the shared registry is already filled
	var main: Node = get_parent()
	Game.register(self, main.get_node("PlayerManager"), main.get_node("RoomController"), main.get_node("AudioManager"),
		main.get_node("GameFeel"), main.get_node("Combat"), main.get_node("Fx") as Node3D, main.get_node("RunManager"))
	Game.set_projectiles(main.get_node("Projectiles"))
	var net: NetworkManager = get_node_or_null("/root/NetworkManager") as NetworkManager
	if net and net.is_online() and main.has_node("Player"):
		main.get_node("Player").set_multiplayer_authority(net.local_peer_id)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	Game.clear()


func _ready() -> void:
	InputSetup.ensure()
	_profile = PlayerProfile.load_profile()
	_settings = GameSettings.load_settings()
	Game.set_hud(hud)

	_detect_network()
	_detect_game_mode()
	_setup_multiplayer_spawning()

	player = player_manager.get_primary_player()
	weapon_manager = player_manager.get_primary_weapon_manager()
	camera = player_manager.get_primary_camera()
	if not player or not weapon_manager:
		push_error("game manager: no local player in the scene")
		return

	weapon_manager.set_skin(_profile.skin)
	weapon_manager.set_loadout(_profile.loadout)
	_apply_settings()

	player.damaged.connect(_on_player_damaged)
	player.died.connect(_on_player_died)
	player.dashed.connect(_on_player_dashed)
	player.slammed.connect(_on_player_slammed)
	player.death_defied.connect(_on_death_defied)
	player.jumped.connect(func() -> void: Game.sfx(&"jump", -14.0, 0.1))
	player.landed.connect(func(speed: float) -> void:
		if speed > 8.0:
			Game.sfx(&"land", -12.0, 0.1))
	player.slide_started.connect(func() -> void: Game.sfx(&"slide", -10.0, 0.08))

	combat.bind(player)
	combat.pvp_manager = pvp_manager
	combat.enemy_hit.connect(_on_enemy_hit)
	combat.enemy_killed.connect(_on_enemy_killed)
	weapon_manager.weapon_switched.connect(func(_w: BaseWeapon) -> void: pass)

	run_manager.room_entered.connect(_on_room_entered)
	run_manager.room_cleared.connect(_on_room_cleared)
	run_manager.run_failed.connect(_on_run_ended)
	run_manager.run_completed.connect(_on_run_ended)

	room_controller.all_enemies_dead.connect(_on_all_enemies_dead)
	room_controller.enemy_killed.connect(_on_room_enemy_died)
	room_controller.boss_spawned.connect(_on_boss_spawned)
	room_controller.boss_defeated.connect(_on_boss_defeated)
	room_controller.pickup_collected.connect(_on_pickup_collected)
	room_controller.wave_started.connect(_on_wave_started)

	fracture_manager.fracture_started.connect(_on_fracture_started)
	fracture_manager.fracture_ended.connect(_on_fracture_ended)
	combo_tracker.combo_changed.connect(_on_combo_changed)
	combo_tracker.combo_reset.connect(_on_combo_reset)
	upgrade_manager.enemy_speed_bonus_changed.connect(_on_enemy_speed_bonus_changed)

	upgrade_ui.upgrade_selected.connect(_on_upgrade_selected)
	mutation_ui.mutation_selected.connect(_on_mutation_selected)
	mutation_ui.mutation_skipped.connect(_on_mutation_skipped)
	path_ui.path_chosen.connect(_on_path_chosen)
	shop_ui.buy_requested.connect(_on_shop_buy)
	shop_ui.closed.connect(_on_shop_closed)
	summary_ui.restart_requested.connect(_on_restart)
	summary_ui.menu_requested.connect(_on_main_menu)
	pause_menu.restart_requested.connect(_on_restart)
	pause_menu.main_menu_requested.connect(_on_main_menu)

	upgrade_manager.bind(player, weapon_manager)
	mutation_manager.bind(player, weapon_manager)
	fracture_manager.bind(player)
	combo_tracker.bind(player)
	hud.bind(player, weapon_manager, run_manager, combo_tracker, fracture_manager)
	hud.accent = Skins.accent(_profile.skin)
	if network_manager:
		hud.bind_network(network_manager)
	hud.bind_pvp(pvp_manager)

	call_deferred("_deferred_start")


func _deferred_start() -> void:
	if not _settings.has_seen_onboarding:
		_show_onboarding()
	else:
		_begin()


## starts the run, or in multiplayer tells the host this peer is loaded.
func _begin() -> void:
	if not _is_online():
		_start_run()
	elif is_host_or_solo():
		_ready_peers[network_manager.local_peer_id] = true
		_waiting_for_peers = READY_TIMEOUT
		_check_all_ready()
	else:
		_rpc_client_ready.rpc_id(1)


func _apply_settings() -> void:
	var fx: Vfx = Vfx.inst()
	if fx:
		fx.numbers_enabled = _settings.damage_numbers
	game_feel.freeze_strength = _settings.hit_stop
	room_controller.apply_quality(_settings.quality)
	if player and player.has_method("apply_settings"):
		player.apply_settings(_settings)
	hud.ui_scale = _settings.hud_scale


func _detect_network() -> void:
	network_manager = get_node_or_null("/root/NetworkManager") as NetworkManager
	if network_manager:
		network_manager.server_disconnected.connect(_on_server_disconnected)
		network_manager.player_disconnected.connect(_on_peer_disconnected)


func _detect_game_mode() -> void:
	game_mode = get_node_or_null("/root/GameModeManager") as GameModeManager
	if not game_mode:
		# started straight into the run scene (tests, editor): default options
		game_mode = GameModeManager.new()
		game_mode.name = "GameModeManager"
		get_tree().root.add_child.call_deferred(game_mode)

	pvp_manager = PvPManager.new()
	pvp_manager.name = "PvPManager"
	add_child(pvp_manager)
	if _is_online():
		pvp_manager.setup(game_mode, player_manager, network_manager)
		for peer_id: int in network_manager.connected_peers:
			game_mode.ensure_score(peer_id)
			if game_mode.is_race():
				game_mode.register_race_peer(peer_id)
	else:
		game_mode.ensure_score(1)
	pvp_manager.player_eliminated.connect(_on_pvp_player_eliminated)
	pvp_manager.match_over.connect(_on_pvp_match_over)


func _setup_multiplayer_spawning() -> void:
	if not _is_online():
		return
	player_spawner.setup(get_parent(), network_manager)
	var scene_player: CharacterBody3D = get_parent().get_node_or_null("Player") as CharacterBody3D
	if scene_player:
		player_spawner.adopt_player(network_manager.local_peer_id, scene_player)
	for peer_id: int in network_manager.connected_peers:
		if peer_id != network_manager.local_peer_id:
			player_spawner.spawn_for_peer(peer_id)


func is_host_or_solo() -> bool:
	return not _is_online() or network_manager.is_host()


func _is_online() -> bool:
	return network_manager != null and network_manager.is_online()


func _local_peer_id() -> int:
	return network_manager.local_peer_id if _is_online() else 1


# --- per-frame ------------------------------------------------------------------

func _process(delta: float) -> void:
	_hit_sound_cooldown = maxf(0.0, _hit_sound_cooldown - delta)

	if _waiting_for_peers >= 0.0:
		_waiting_for_peers -= delta
		if _waiting_for_peers < 0.0:
			_start_run()

	if _death_timer >= 0.0:
		_death_timer -= delta
		if _death_timer < 0.0:
			_resolve_death()

	if not run_manager.is_active or not is_instance_valid(player):
		return

	if _head_start > 0.0:
		_head_start -= delta
		if _head_start <= 0.0:
			player.stats.set_mul(&"move_speed", &"perk:head_start", 1.0)

	if _profile.has_unlock("last_stand"):
		var low: bool = float(player.health) / float(player.max_health) <= 0.2 and not player.is_dead
		player.stats.set_mul(&"damage", &"perk:last_stand", 1.4 if low else 1.0)
		player.stats.set_mul(&"move_speed", &"perk:last_stand", 1.2 if low else 1.0)

	if _fracture_delay >= 0.0:
		_fracture_delay -= delta
		if _fracture_delay < 0.0:
			_try_start_fracture()


func _unhandled_input(event: InputEvent) -> void:
	if awaiting_transition and event.is_action_pressed("jump"):
		awaiting_transition = false
		hud.hide_prompt()
		if is_host_or_solo():
			_advance_room(0)
		else:
			_rpc_request_advance_room.rpc_id(1)


# --- run lifecycle ---------------------------------------------------------------

func _start_run() -> void:
	_waiting_for_peers = -1.0
	var cfg: Dictionary = _build_run_config()
	_do_start_run(cfg)
	if _is_online():
		_rpc_start_run.rpc(cfg)


func _build_run_config() -> Dictionary:
	var mode: StringName = game_mode.run_mode
	if game_mode.is_versus():
		mode = RunData.MODE_VERSUS
	var seed_value: int = game_mode.custom_seed
	if mode == RunData.MODE_DAILY:
		seed_value = GameModeManager.daily_seed()
	elif seed_value == 0:
		seed_value = randi() % 2000000000 + 1
	return {
		"mode": mode,
		"seed": seed_value,
		"ascension": game_mode.ascension if mode != RunData.MODE_VERSUS else 0,
		"players": maxi(1, player_manager.get_player_count()),
	}


func _do_start_run(cfg: Dictionary) -> void:
	_run_cfg = cfg
	awaiting_upgrade = false
	awaiting_mutation = false
	awaiting_transition = false
	awaiting_path = false
	awaiting_shop = false
	_reward_queue.clear()
	_shared_enemy_speed_bonus = 0.0
	_pvp_active = false
	_match_ended = false
	_bosses_killed.clear()
	_flawless_boss = false
	_down_peers.clear()
	_death_timer = -1.0
	_fracture_delay = -1.0
	_hide_all_panels()

	game_feel.reset()
	fracture_manager.end_fracture()
	upgrade_manager.reset()
	mutation_manager.reset()
	combo_tracker.reset_run()
	difficulty_tracker.reset()
	combat.reset_totals()
	weapon_manager.reset_for_run()
	room_controller.set_enemy_speed_mod(&"cursed", 1.0)
	room_controller.player_count = int(cfg.get("players", 1))

	player.stats.clear_modifiers()
	_apply_profile_bonuses()
	player.reset_for_run(Vector3(0, 2, 0))

	if cfg.get("mode", RunData.MODE_STANDARD) == RunData.MODE_DAILY:
		_profile.daily_last_played = GameModeManager.daily_key()

	Game.sfx(&"run_start", -3.0)
	if cfg.mode == RunData.MODE_VERSUS:
		run_manager.start_run_with_floors(RaceGenerator.generate(int(cfg.seed), int(cfg.players)), cfg)
	else:
		run_manager.start_run(cfg)


@rpc("authority", "call_remote", "reliable")
func _rpc_start_run(cfg: Dictionary) -> void:
	_do_start_run(cfg)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_ready() -> void:
	if not is_host_or_solo():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	_ready_peers[sender] = true
	if run_manager.is_active:
		# the run already started without them (they loaded late): send it over
		_rpc_start_run.rpc_id(sender, _run_cfg)
	else:
		_check_all_ready()


func _check_all_ready() -> void:
	for peer_id: int in network_manager.connected_peers:
		if not _ready_peers.has(peer_id):
			return
	_start_run()


func _advance_room(option_index: int) -> void:
	run_manager.advance_to_next_room(option_index)
	if _is_online():
		_rpc_advance_room.rpc(option_index)


@rpc("authority", "call_remote", "reliable")
func _rpc_advance_room(option_index: int) -> void:
	awaiting_transition = false
	awaiting_path = false
	hud.hide_prompt()
	path_ui.hide_panel()
	run_manager.advance_to_next_room(option_index)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_advance_room() -> void:
	# only honoured when there is exactly one way forward; a real choice is the host's
	if is_host_or_solo() and run_manager.data and run_manager.data.next_options().size() <= 1:
		var room: RunData.RoomData = run_manager.data.current_room()
		if room and room.status == RoomDefinitions.RoomStatus.CLEARED:
			_advance_room(0)


func _complete_run() -> void:
	if not is_host_or_solo():
		_rpc_request_complete_run.rpc_id(1)
		return
	run_manager.complete_run()
	if _is_online():
		_rpc_complete_run.rpc()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_complete_run() -> void:
	if is_host_or_solo() and run_manager.data and run_manager.data.is_final_room():
		_complete_run()


@rpc("authority", "call_remote", "reliable")
func _rpc_complete_run() -> void:
	run_manager.complete_run()


@rpc("authority", "call_remote", "reliable")
func _rpc_fail_run() -> void:
	run_manager.fail_run()


# --- rooms ----------------------------------------------------------------------

func _on_room_entered(room: RunData.RoomData) -> void:
	var data: RunData = run_manager.data
	awaiting_transition = false
	awaiting_path = false
	_hide_all_panels()
	_scavenger_used = false
	_momentum_start_used = false
	_room_flawless = true
	_fracture_delay = -1.0
	_down_peers.clear()

	# solo only: nudge the room toward how the run has been going. in co-op
	# every peer must build the same room, so the budget is left alone.
	if not _is_online() and not room.metadata.has("tuned") and room.enemy_budget > 0.0:
		room.metadata["tuned"] = true
		room.enemy_budget *= difficulty_tracker.get_difficulty_modifier()

	room_controller.collect_all_pickups()
	room_controller.set_enemy_speed_mod(&"cursed", 1.0 + _shared_enemy_speed_bonus)
	room_controller.enter_room(room)

	if player.is_dead:
		# a downed co-op player gets back up for the next room
		player.is_dead = false
		player.health = maxi(1, int(player.max_health * 0.5))
	var index: int = maxi(0, player_manager.get_all_players().find(player))
	player.teleport(room_controller.player_spawn_point(index))

	hud.set_boss(null)
	if room.is_boss():
		Game.sfx(&"boss_warning", 0.0)
		room_announce.show_boss_intro(BossDefs.display_name(room.boss_id), BossDefs.intro(room.boss_id))
	else:
		room_announce.show_room_enter(room, data.current_room_index + 1, data.total_rooms())
		if data.current_room_index == 0 or data.room_sequence[data.current_room_index - 1].act != room.act:
			room_announce.show_subtitle("act %d: %s" % [room.act + 1, Biome.display_name(room.biome)])

	if not room.is_boss() and not room.is_peaceful():
		_fracture_delay = randf_range(4.0, 8.0)
	difficulty_tracker.on_room_entered()


func _on_all_enemies_dead() -> void:
	if not is_host_or_solo():
		return
	run_manager.on_room_enemies_cleared()
	if _is_online():
		_rpc_room_cleared.rpc()


@rpc("authority", "call_remote", "reliable")
func _rpc_room_cleared() -> void:
	run_manager.on_room_enemies_cleared()


func _on_room_cleared(room: RunData.RoomData) -> void:
	fracture_manager.end_fracture()
	_fracture_delay = -1.0
	difficulty_tracker.on_room_cleared()
	if not room.is_peaceful():
		room_announce.show_room_clear()
		Game.sfx(&"room_clear", -3.0)
	if room.is_boss() and _room_flawless:
		_flawless_boss = true

	if game_mode.is_race():
		game_mode.on_race_room_cleared(_local_peer_id())
		if is_host_or_solo() and game_mode.should_start_encounter():
			_transition_to_pvp()
			return
	elif game_mode.is_pvp_mode() and run_manager.data.is_final_room():
		if is_host_or_solo():
			_transition_to_pvp()
		return

	_reward_queue = _rewards_for(room)
	_next_reward()


func _rewards_for(room: RunData.RoomData) -> Array[StringName]:
	var q: Array[StringName] = []
	match room.reward:
		RoomDefinitions.REWARD_UPGRADE:
			q.append(&"upgrade")
		RoomDefinitions.REWARD_RARE:
			q.append(&"rare")
		RoomDefinitions.REWARD_MUTATION:
			q.append(&"upgrade")
			q.append(&"mutation")
		RoomDefinitions.REWARD_HEAL:
			q.append(&"heal")
		RoomDefinitions.REWARD_ESSENCE:
			q.append(&"essence")
		RoomDefinitions.REWARD_SHOP:
			q.append(&"shop")
		RoomDefinitions.REWARD_BOSS:
			q.append(&"boss_heal")
			q.append(&"rare")
			q.append(&"mutation")
	if room.metadata.get("double_reward", false) and not q.is_empty():
		q.append(q[0])
	return q


func _next_reward() -> void:
	if not run_manager.is_active:
		return
	if _reward_queue.is_empty():
		_after_rewards()
		return
	var kind: StringName = _reward_queue.pop_front()
	match kind:
		&"upgrade", &"rare":
			var choices: Array[Dictionary] = UpgradeDefinitions.pick_choices(3, upgrade_manager.owned, _loadout_ids(), kind == &"rare")
			if choices.is_empty():
				_next_reward()
				return
			awaiting_upgrade = true
			upgrade_ui.show_choices(choices, "rare upgrade" if kind == &"rare" else "choose an upgrade")
		&"mutation":
			var options: Array[Dictionary] = MutationDefinitions.pick_choices(2, mutation_manager.owned_types())
			if options.is_empty():
				_next_reward()
				return
			awaiting_mutation = true
			mutation_ui.show_choices(options)
		&"heal":
			var healed: int = player.heal(int(player.max_health * HEAL_ROOM_RATIO))
			room_announce.show_text("restored %d health" % healed, Color(0.4, 1.0, 0.5))
			Game.sfx(&"heal", -4.0)
			_next_reward()
		&"boss_heal":
			player.heal(int(player.max_health * BOSS_HEAL_RATIO))
			_next_reward()
		&"essence":
			var room: RunData.RoomData = run_manager.data.current_room()
			var amount: int = 18 + (room.act if room else 0) * 8 + randi() % 10
			var at: Vector3 = player.global_position + Vector3(0, 1.0, 0) - player.global_transform.basis.z * 3.0
			for i: int in 6:
				room_controller.drop_pickup(Pickup.KIND_ESSENCE, maxi(1, amount / 6), at)
			room_announce.show_text("essence cache", Color(0.62, 1.0, 0.36))
			_next_reward()
		&"shop":
			_open_shop()
		_:
			_next_reward()


func _after_rewards() -> void:
	var data: RunData = run_manager.data
	if not data or not run_manager.is_active:
		return
	if data.is_final_room():
		_complete_run()
		return
	var options: Array = data.next_options()
	if options.size() <= 1:
		awaiting_transition = true
		hud.show_prompt(CONTINUE_PROMPT % InputSetup.key_label("jump").to_lower())
	elif is_host_or_solo():
		awaiting_path = true
		path_ui.show_options(options, data.current_room_index + 2, data.total_rooms())
	else:
		hud.show_prompt("the host is choosing the path")


func _on_path_chosen(index: int) -> void:
	if not awaiting_path:
		return
	awaiting_path = false
	Game.sfx(&"ui_select", -6.0)
	_advance_room(index)


func _loadout_ids() -> Array:
	var ids: Array = []
	for w: BaseWeapon in weapon_manager.weapons:
		ids.append(w.weapon_id)
	return ids


func _on_wave_started(index: int, total: int) -> void:
	if total > 1 and index > 1:
		room_announce.show_text("wave %d of %d" % [index, total], Color(1.0, 0.5, 0.2))


# --- rewards ---------------------------------------------------------------------

func _on_upgrade_selected(upgrade: Dictionary) -> void:
	if not awaiting_upgrade:
		return
	awaiting_upgrade = false
	upgrade_manager.apply(upgrade)
	run_manager.apply_upgrade(upgrade)
	Game.sfx(&"upgrade_pick", -3.0)
	_next_reward()


func _on_mutation_selected(mutation: Dictionary) -> void:
	if not awaiting_mutation:
		return
	awaiting_mutation = false
	mutation_manager.apply(mutation)
	run_manager.data.chosen_mutations.append(mutation)
	Game.sfx(&"mutation_pick", -3.0)
	_next_reward()


func _on_mutation_skipped() -> void:
	if not awaiting_mutation:
		return
	awaiting_mutation = false
	_next_reward()


func _on_enemy_speed_bonus_changed(total: float) -> void:
	# a cursed pick makes enemies faster for everyone. only the host's
	# simulation moves enemies, so clients send their share up.
	if is_host_or_solo():
		_shared_enemy_speed_bonus = total + _client_speed_bonus()
		room_controller.set_enemy_speed_mod(&"cursed", 1.0 + _shared_enemy_speed_bonus)
	elif _is_online():
		_rpc_report_speed_bonus.rpc_id(1, total)


var _peer_speed_bonus: Dictionary = {}


func _client_speed_bonus() -> float:
	var sum: float = 0.0
	for peer: Variant in _peer_speed_bonus:
		sum += _peer_speed_bonus[peer]
	return sum


@rpc("any_peer", "call_remote", "reliable")
func _rpc_report_speed_bonus(total: float) -> void:
	if not is_host_or_solo():
		return
	_peer_speed_bonus[multiplayer.get_remote_sender_id()] = clampf(total, 0.0, 2.0)
	_shared_enemy_speed_bonus = upgrade_manager.enemy_speed_bonus + _client_speed_bonus()
	room_controller.set_enemy_speed_mod(&"cursed", 1.0 + _shared_enemy_speed_bonus)


# --- shop ------------------------------------------------------------------------

func _open_shop() -> void:
	_shop_items.clear()
	_shop_items.append({"kind": "heal", "name": "mend", "description": "restore 35% of your health", "cost": 25, "sold": false})
	_shop_items.append({"kind": "graft", "name": "graft", "description": "+15 max health for this run", "cost": 40, "sold": false})
	for u: Dictionary in UpgradeDefinitions.pick_choices(3, upgrade_manager.owned, _loadout_ids(), false):
		_shop_items.append({
			"kind": "upgrade", "name": u.name, "description": u.description, "upgrade": u,
			"cost": SHOP_PRICES.get(u.get("rarity", UpgradeDefinitions.RARITY_COMMON), 40), "sold": false,
		})
	_shop_items.append({"kind": "reroll", "name": "reroll", "description": "replace the upgrades on offer", "cost": 15, "sold": false})
	awaiting_shop = true
	shop_ui.show_shop(_shop_items, run_manager.data.essence)


func _on_shop_buy(index: int) -> void:
	if not awaiting_shop or index < 0 or index >= _shop_items.size():
		return
	var item: Dictionary = _shop_items[index]
	var data: RunData = run_manager.data
	if item.sold or data.essence < int(item.cost):
		Game.sfx(&"ui_deny", -8.0)
		return
	run_manager.add_essence(-int(item.cost))
	match item.kind:
		"heal":
			player.heal(int(player.max_health * 0.35))
			item.sold = true
		"graft":
			player.stats.stack_add(&"max_health", &"shop:graft", 15.0)
			player.heal(15)
			item.cost = int(item.cost) + 20
		"upgrade":
			upgrade_manager.apply(item.upgrade)
			run_manager.apply_upgrade(item.upgrade)
			item.sold = true
		"reroll":
			var fresh: Array[Dictionary] = UpgradeDefinitions.pick_choices(3, upgrade_manager.owned, _loadout_ids(), false)
			var slot: int = 0
			for i: int in _shop_items.size():
				if _shop_items[i].kind == "upgrade" and slot < fresh.size():
					var u: Dictionary = fresh[slot]
					slot += 1
					_shop_items[i] = {
						"kind": "upgrade", "name": u.name, "description": u.description, "upgrade": u,
						"cost": SHOP_PRICES.get(u.get("rarity", UpgradeDefinitions.RARITY_COMMON), 40), "sold": false,
					}
			item.cost = int(item.cost) + 10
	Game.sfx(&"upgrade_pick", -5.0)
	shop_ui.show_shop(_shop_items, data.essence)


func _on_shop_closed() -> void:
	if not awaiting_shop:
		return
	awaiting_shop = false
	_next_reward()


func _on_pickup_collected(kind: StringName, value: int) -> void:
	if not is_instance_valid(player):
		return
	if kind == Pickup.KIND_ESSENCE:
		run_manager.add_essence(maxi(1, int(round(value * player.stats.value(&"essence_gain")))))
		Game.sfx(&"pickup", -12.0, 0.2)
	elif kind == Pickup.KIND_HEALTH:
		player.heal(value)
		Game.sfx(&"heal", -8.0, 0.1)


# --- combat events ---------------------------------------------------------------

func _on_enemy_hit(enemy: Node3D, info: DamageInfo) -> void:
	upgrade_manager.on_enemy_hit(enemy, info)
	mutation_manager.on_enemy_hit(enemy, info)
	game_mode.register_damage_dealt(_local_peer_id(), info.amount)
	hud.show_hit(info.crit, info.weak)
	if _hit_sound_cooldown <= 0.0 and info.kind != DamageInfo.KIND_DOT:
		_hit_sound_cooldown = 0.05
		Game.sfx(&"enemy_hit_crit" if info.crit else &"enemy_hit", -10.0 if not info.crit else -5.0, 0.15)
	if info.crit:
		game_feel.hit_pause(0.03)


func _on_enemy_killed(enemy: Node3D, info: DamageInfo) -> void:
	run_manager.register_kill()
	var data: RunData = run_manager.data
	if data and enemy.get("is_elite") == true:
		data.elites_killed += 1
	upgrade_manager.on_enemy_killed(enemy, info)
	mutation_manager.on_enemy_killed(enemy, info)
	combo_tracker.register_kill()
	game_mode.register_kill(_local_peer_id())

	var meta_heal: int = MetaProgression.get_kill_heal_bonus(_profile)
	if meta_heal > 0:
		player.heal(meta_heal)
	if not _scavenger_used and _profile.has_unlock("scavenger"):
		_scavenger_used = true
		player.heal(10)
	if _profile.has_unlock("kill_pulse") and is_instance_valid(enemy):
		Vfx.ring(enemy.global_position, 3.5, Skins.accent(_profile.skin), 0.35, 0.4, 0.2)

	game_feel.kill_freeze()
	hud.show_kill()


## any enemy death in the room, whoever caused it.
func _on_room_enemy_died(enemy: Node3D, _info: DamageInfo) -> void:
	if enemy is BossBase:
		_bosses_killed.append((enemy as BossBase).boss_id)
	if not is_host_or_solo():
		return
	if fracture_manager.is_active and fracture_manager.active_fracture == FractureDefinitions.FractureType.ENEMY_DUPLICATION:
		if enemy.get("counts_for_room") == true and randf() < 0.3:
			room_controller.spawn_duplicate_enemy()


func _on_player_dashed() -> void:
	upgrade_manager.on_player_dashed()
	Game.sfx(&"dash", -5.0, 0.1)
	if not _momentum_start_used and _profile.has_unlock("momentum_start"):
		_momentum_start_used = true
		player.grant_invulnerability(3.0)
		room_announce.show_text("untouchable", Skins.accent(_profile.skin))
	if _profile.has_unlock("trail_fracture"):
		var from: Vector3 = player.global_position
		var color: Color = Skins.accent(_profile.skin)
		get_tree().create_timer(0.16).timeout.connect(func() -> void:
			if is_instance_valid(player):
				Vfx.tracer(from, player.global_position, color, 0.45, 0.12, 0.02)
		)


func _on_player_slammed(at: Vector3, fall_speed: float) -> void:
	upgrade_manager.on_player_slammed(at, fall_speed)
	Vfx.ring(at, 4.0, Skins.accent(_profile.skin), 0.3, 0.5, 0.25)
	Game.sfx(&"thud", -4.0, 0.08)
	Game.shake(clampf(fall_speed * 0.12, 2.0, 7.0))
	# the slam always shoves nearby enemies back, upgrade or not
	for e: Node3D in Combat.enemies_in_radius(get_tree(), at, 4.0):
		if e.has_method("apply_knockback"):
			e.apply_knockback(e.global_position - at, 7.0)


func _on_player_damaged(amount: int, info: DamageInfo) -> void:
	if amount <= 0:
		return
	_room_flawless = false
	if run_manager.data:
		run_manager.data.damage_taken += amount
	difficulty_tracker.on_player_damaged(amount)
	mutation_manager.on_player_damaged(amount, info)
	Game.sfx(&"player_damage", -2.0, 0.1)
	damage_vignette.flash(clampf(float(amount) / 25.0, 0.5, 2.0))
	Game.shake(clampf(amount * 0.3, 1.5, 8.0))
	if info and is_instance_valid(info.source) and info.source is Node3D and info.source != player:
		hud.show_damage_from((info.source as Node3D).global_position)
	elif info and info.position != Vector3.ZERO:
		hud.show_damage_from(info.position)


func _on_death_defied() -> void:
	room_announce.show_text("second wind", Color(1.0, 0.9, 0.4))
	Game.sfx(&"upgrade_pick", 0.0)
	game_feel.request(&"defied", 0.3, 0.5, GameFeel.PRIORITY_DEATH, 0.15)
	Vfx.ring(player.global_position, 8.0, Color(1.0, 0.9, 0.4), 0.5)


func _on_player_died() -> void:
	damage_vignette.flash(3.0)
	Game.shake(12.0)
	game_feel.player_death_slowmo()
	_dismiss_reward_panels()

	if _pvp_active:
		# pvp eliminations are tracked by the pvp manager's own health pool
		player.is_dead = false
		player.health = 1
		return
	_death_timer = 0.6


func _resolve_death() -> void:
	if not run_manager.is_active:
		return
	if not _is_online():
		run_manager.fail_run()
		return
	room_announce.show_text("you are down", Color(1.0, 0.2, 0.15))
	if is_host_or_solo():
		_register_down(_local_peer_id())
	else:
		_rpc_report_down.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_report_down() -> void:
	if is_host_or_solo():
		_register_down(multiplayer.get_remote_sender_id())


## co-op: the run only ends when everyone is down in the same room.
func _register_down(peer_id: int) -> void:
	_down_peers[peer_id] = true
	for id: int in network_manager.connected_peers:
		if not _down_peers.has(id):
			return
	run_manager.fail_run()
	_rpc_fail_run.rpc()


func _dismiss_reward_panels() -> void:
	awaiting_upgrade = false
	awaiting_mutation = false
	awaiting_transition = false
	awaiting_path = false
	awaiting_shop = false
	_reward_queue.clear()
	_hide_all_panels()


func _hide_all_panels() -> void:
	upgrade_ui.hide_panel()
	mutation_ui.hide_panel()
	path_ui.hide_panel()
	shop_ui.hide_panel()
	hud.hide_prompt()


# --- bosses ----------------------------------------------------------------------

func _on_boss_spawned(boss: BossBase) -> void:
	hud.set_boss(boss)
	boss.phase_changed.connect(_on_boss_phase_changed)


func _on_boss_phase_changed(_phase: int) -> void:
	game_feel.boss_phase_slowmo()
	Game.shake(8.0)


func _on_boss_defeated() -> void:
	room_announce.show_boss_defeated()
	game_feel.boss_death_slowmo()


# --- fracture and combo ------------------------------------------------------------

func _try_start_fracture() -> void:
	if not is_host_or_solo() or not room_controller.room_active:
		return
	var room: RunData.RoomData = run_manager.data.current_room() if run_manager.data else null
	if not room:
		return
	var type: int = fracture_manager.try_trigger(room.difficulty)
	if type >= 0 and _is_online():
		_rpc_start_fracture.rpc(type)


@rpc("authority", "call_remote", "reliable")
func _rpc_start_fracture(type: int) -> void:
	fracture_manager.start_fracture(type)


func _on_fracture_started(type: int) -> void:
	room_announce.show_fracture(FractureDefinitions.get_event_name(type), FractureDefinitions.get_description(type))
	Game.sfx(&"fracture", -2.0)
	mutation_manager.on_fracture_started()


func _on_fracture_ended(_type: int) -> void:
	mutation_manager.on_fracture_ended()


func _on_combo_changed(multiplier: int, _kill_count: int) -> void:
	upgrade_manager.on_combo_changed(multiplier)


func _on_combo_reset() -> void:
	upgrade_manager.on_combo_reset()


# --- profile ---------------------------------------------------------------------

func _apply_profile_bonuses() -> void:
	var s: StatBlock = player.stats
	MetaProgression.apply_to_stats(_profile, s)

	combo_tracker.combo_window = ComboTracker.COMBO_WINDOW + (1.0 if _profile.has_unlock("adrenaline_junkie") else 0.0)
	_head_start = 0.0
	if _profile.has_unlock("head_start"):
		s.set_mul(&"move_speed", &"perk:head_start", 1.15)
		_head_start = 30.0
	if _profile.has_unlock("glass_cannon"):
		s.set_mul(&"damage", &"perk:sharpened", 1.2)
		s.set_add(&"max_health", &"perk:sharpened", -20.0)
	if _profile.has_unlock("shard_hunger"):
		s.set_add(&"max_health", &"perk:shard_hunger", -10.0)

	# weapon variants are flags on the weapon, set after the per-run reset
	var variants: Dictionary = {
		"rapid_beam": [&"beam_emitter", &"rapid"],
		"charged_beam": [&"beam_emitter", &"capacity"],
		"wide_scatter": [&"scatter_cannon", &"wide"],
		"incendiary_scatter": [&"scatter_cannon", &"incendiary"],
		"marksman_rifle": [&"pulse_rifle", &"marksman"],
		"ricochet_rifle": [&"pulse_rifle", &"ricochet"],
	}
	for unlock_id: String in variants:
		if _profile.has_unlock(unlock_id):
			weapon_manager.set_weapon_flag(variants[unlock_id][0], variants[unlock_id][1], true)


# --- run end ---------------------------------------------------------------------

func _on_run_ended(data: RunData) -> void:
	_dismiss_reward_panels()
	fracture_manager.end_fracture()
	_fracture_delay = -1.0
	var best: int = combo_tracker.best_combo
	combo_tracker.reset()
	data.run_tags = RunTags.generate(data, best)
	_show_summary(data, best, false)


func _show_summary(data: RunData, combo_best: int, pvp_won: bool) -> void:
	var extras: Dictionary = {
		"prev_best_kills": _profile.best_kills_single_run,
		"prev_best_combo": _profile.best_combo,
		"best_combo": combo_best,
		"damage_dealt": combat.total_damage,
		"crits": combat.crit_hits,
		"weak_hits": combat.weak_hits,
		"mode_name": GameModeManager.run_mode_name(data.mode),
	}
	var was_unlocked: int = _profile.ascension_unlocked
	_profile.update_from_run(data, combo_best, pvp_won)

	var shard_data: Dictionary = MetaProgression.calculate_shards(data, combo_best, pvp_won)
	var total_shards: int = int(shard_data.total * MetaProgression.get_shard_multiplier(_profile))
	_profile.fracture_shards += total_shards
	var earned: Array[Dictionary] = MetaProgression.check_achievements(_profile, data, combo_best,
		{"bosses_killed": _bosses_killed, "flawless_boss": _flawless_boss})
	_profile.save()

	extras["shards_earned"] = total_shards
	extras["shard_breakdown"] = shard_data
	extras["achievements"] = earned
	extras["ascension_unlocked"] = _profile.ascension_unlocked if _profile.ascension_unlocked > was_unlocked else -1
	data.metadata["shards_earned"] = total_shards
	summary_ui.show_summary(data, extras)


func _on_restart() -> void:
	game_feel.reset()
	_dismiss_reward_panels()
	summary_ui.hide_panel()
	if pvp_manager.is_active():
		pvp_manager.stop_pvp()
	_set_pvp_on_weapons(false)
	room_controller.clear_current_room()
	_profile = PlayerProfile.load_profile()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if is_host_or_solo():
		_start_run()


func _on_main_menu() -> void:
	_leave_to_menu()


func _leave_to_menu() -> void:
	game_feel.reset()
	get_tree().paused = false
	fracture_manager.end_fracture()
	if pvp_manager.is_active():
		pvp_manager.stop_pvp()
	room_controller.clear_current_room()
	if network_manager:
		network_manager.disconnect_game()
	var err: Error = get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	if err != OK:
		push_error("failed to change scene to main_menu: %s" % error_string(err))


func _on_server_disconnected() -> void:
	_leave_to_menu()


func _on_peer_disconnected(peer_id: int) -> void:
	# a player who left can no longer hold up "everyone is down" or "everyone is ready"
	_down_peers.erase(peer_id)
	_ready_peers.erase(peer_id)
	_peer_speed_bonus.erase(peer_id)


# --- versus ----------------------------------------------------------------------

func _transition_to_pvp() -> void:
	room_controller.clear_current_room()
	fracture_manager.end_fracture()
	if not _is_online():
		# nobody to fight: treat the gauntlet as won
		room_announce.show_text("run complete", Color(0.4, 1.0, 0.5))
		_complete_run()
		return
	_begin_pvp()
	_rpc_start_pvp.rpc()


@rpc("authority", "call_remote", "reliable")
func _rpc_start_pvp() -> void:
	room_controller.clear_current_room()
	_begin_pvp()


func _begin_pvp() -> void:
	_pvp_active = true
	_dismiss_reward_panels()
	room_announce.show_fracture("pvp encounter", "last one standing")
	Game.sfx(&"boss_warning", 0.0)
	var players: Array[CharacterBody3D] = player_manager.get_all_players()
	for i: int in players.size():
		var p: CharacterBody3D = players[i]
		if not is_instance_valid(p) or not p.is_multiplayer_authority():
			continue
		var angle: float = TAU * float(i) / float(maxi(players.size(), 1))
		p.is_dead = false
		p.health = p.max_health
		p.teleport(Vector3(cos(angle) * 10.0, 2.0, sin(angle) * 10.0))
	pvp_manager.start_pvp()
	game_mode.start_pvp()
	_set_pvp_on_weapons(true)


func _set_pvp_on_weapons(active: bool) -> void:
	combat.pvp_manager = pvp_manager if active else null


func _on_pvp_player_eliminated(peer_id: int) -> void:
	if peer_id == _local_peer_id():
		room_announce.show_text("eliminated", Color(1.0, 0.2, 0.15))
	else:
		room_announce.show_text("opponent down", Color(0.4, 1.0, 0.5))


func _on_pvp_match_over(winner_peer_id: int) -> void:
	_pvp_active = false
	_match_ended = true
	pvp_manager.stop_pvp()
	_set_pvp_on_weapons(false)
	game_mode.end_pvp(winner_peer_id)
	var won: bool = winner_peer_id == _local_peer_id()
	room_announce.show_text("victory" if won else "defeated", Color(0.4, 1.0, 0.5) if won else Color(1.0, 0.2, 0.15))
	Game.sfx(&"boss_death" if won else &"player_damage", 0.0)

	var data: RunData = run_manager.data
	if not data:
		return
	data.status = RunData.RunStatus.COMPLETED if won else RunData.RunStatus.FAILED
	run_manager.is_active = false
	var best: int = combo_tracker.best_combo
	data.run_tags = PackedStringArray(["mode: %s" % game_mode.get_mode_name(), "victory" if won else "defeat"])
	var scores: Dictionary = game_mode.get_score_summary()
	for peer_id: int in scores:
		data.run_tags.append("%s: %d pts" % ["you" if peer_id == _local_peer_id() else "p%d" % peer_id, scores[peer_id].total])
	_show_summary(data, best, won)


# --- onboarding --------------------------------------------------------------------

func _show_onboarding() -> void:
	var scene: PackedScene = load("res://scenes/onboarding_overlay.tscn") as PackedScene
	if not scene:
		_begin()
		return
	_onboarding = scene.instantiate() as OnboardingOverlay
	get_node("../UI").add_child(_onboarding)
	_onboarding.show_onboarding()
	_onboarding.dismissed.connect(_begin)
