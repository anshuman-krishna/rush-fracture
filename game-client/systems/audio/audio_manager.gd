class_name AudioManager
extends Node

# plays every sound in the game. nothing is loaded from disk: effects come
# from SoundSynth recipes and the soundtrack from MusicSynth. both are
# rendered once on worker threads and then shared by every AudioManager
# (the menu owns one, the run scene owns another).
#
# without an audio device (headless test runs) nothing is rendered or played.
# pass "--audio" after "--" on the command line to force the full path anyway.

enum MusicState { OFF, MENU, CALM, COMBAT, BOSS }

const SFX_BUS: StringName = &"SFX"
const MUSIC_BUS: StringName = &"Music"
const POOL_SIZE: int = 16
const POOL_3D_SIZE: int = 14
## the same sound asked for again within this many msec is dropped. stops
## ten pellets landing on one frame from playing ten stacked hit sounds.
const REPEAT_GAP_MSEC: int = 28

const LAYER_NAMES: Array[StringName] = [&"pad", &"drive", &"lead"]
## loudness of each music layer when fully up
const LAYER_LEVEL: Array[float] = [0.3, 0.45, 0.12]
## how far up each layer sits in each state: pad, drive, lead
const STATE_MIX: Dictionary = {
	MusicState.OFF: [0.0, 0.0, 0.0],
	MusicState.MENU: [1.0, 0.0, 0.5],
	MusicState.CALM: [0.9, 0.0, 0.0],
	MusicState.COMBAT: [0.75, 1.0, 0.0],
	MusicState.BOSS: [0.7, 1.0, 1.0],
}
const FADE_IN: float = 0.9
const FADE_OUT: float = 2.2
const KEY_FADE: float = 0.7

## effects worth having first: the ones a player can trigger straight away
const RENDER_FIRST: PackedStringArray = [
	"ui_hover", "ui_select", "ui_deny", "run_start", "pulse_fire", "scatter_fire", "beam_fire",
	"step", "jump", "land", "dash", "slide", "enemy_hit", "enemy_death", "player_damage",
]

# shared by every instance. _streams and _tracks are written by worker
# threads, so they are only touched with _mutex held until rendering ends.
static var _streams: Dictionary = {}
static var _tracks: Dictionary = {}
static var _track_tasks: Dictionary = {}
static var _queue: PackedStringArray = PackedStringArray()
static var _mutex: Mutex = Mutex.new()
static var _render_group: int = -1
static var _render_started: bool = false
static var _render_done: bool = false
static var _buses_ready: bool = false
static var _silent_checked: bool = false
static var _silent: bool = false

var _pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _pool_3d_index: int = 0
var _last_played: Dictionary = {}

var _layers: Array[AudioStreamPlayer] = []
var _gain: Array[float] = [0.0, 0.0, 0.0]
var _music_state: MusicState = MusicState.OFF
var _loaded_root: int = -1
var _wanted_root: int = -1
var _swap: float = 0.0
var _clock_usec: int = 0


## true when there is nothing to play sound through.
static func is_silent() -> bool:
	if not _silent_checked:
		_silent_checked = true
		var no_device: bool = DisplayServer.get_name() == "headless" or AudioServer.get_driver_name() == "Dummy"
		_silent = no_device and not OS.get_cmdline_user_args().has("--audio")
	return _silent


## makes sure the effect and music buses exist. the project ships no bus
## layout, so they are added the first time anything asks.
static func ensure_buses() -> void:
	if _buses_ready:
		return
	_buses_ready = true
	for bus: StringName in [SFX_BUS, MUSIC_BUS]:
		if AudioServer.get_bus_index(bus) >= 0:
			continue
		AudioServer.add_bus()
		var index: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, &"Master")
	# a busy fight stacks a lot of sounds. catch the peaks instead of clipping.
	var limiter: AudioEffectHardLimiter = AudioEffectHardLimiter.new()
	limiter.ceiling_db = -0.5
	AudioServer.add_bus_effect(0, limiter)


func _ready() -> void:
	# menus and reward screens pause the tree; sound keeps going through them
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_buses()
	if is_silent():
		set_process(false)
		return
	_begin_render()

	for i: int in POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_pool.append(player)
	for i: int in POOL_3D_SIZE:
		var spatial: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		spatial.bus = SFX_BUS
		spatial.unit_size = 9.0
		spatial.max_distance = 70.0
		spatial.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(spatial)
		_pool_3d.append(spatial)
	for i: int in LAYER_NAMES.size():
		var layer: AudioStreamPlayer = AudioStreamPlayer.new()
		layer.bus = MUSIC_BUS
		layer.volume_db = -80.0
		add_child(layer)
		_layers.append(layer)
	_clock_usec = Time.get_ticks_usec()


func _exit_tree() -> void:
	# the engine hangs on quit if a worker is still inside a script, so
	# whoever leaves the tree waits out any render in flight. that is under
	# a second, and only ever happens right after launch.
	_finish_tasks()


func _process(_delta: float) -> void:
	_collect_finished_tasks()
	# fades run on the wall clock so hit-stop and slow motion do not stretch them
	var now: int = Time.get_ticks_usec()
	var delta: float = minf(0.1, float(now - _clock_usec) / 1000000.0)
	_clock_usec = now
	_update_music(delta)


# --- effects --------------------------------------------------------------------

func play(sound: StringName, volume_db: float = 0.0, pitch_variance: float = 0.0) -> void:
	var stream: AudioStream = _take(sound)
	if not stream:
		return
	var player: AudioStreamPlayer = _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = _pitch(pitch_variance)
	player.play()


## plays a sound from a point in the world, so it pans and fades with distance.
func play_at(sound: StringName, world_pos: Vector3, volume_db: float = 0.0, pitch_variance: float = 0.0) -> void:
	var stream: AudioStream = _take(sound)
	if not stream:
		return
	var player: AudioStreamPlayer3D = _pool_3d[_pool_3d_index]
	_pool_3d_index = (_pool_3d_index + 1) % POOL_3D_SIZE
	player.global_position = world_pos
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = _pitch(pitch_variance)
	player.play()


func _pitch(variance: float) -> float:
	return 1.0 + randf_range(-variance, variance) if variance > 0.0 else 1.0


## the stream for a sound, or null when it should not play right now.
func _take(sound: StringName) -> AudioStream:
	if _pool.is_empty():
		return null
	var now: int = Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -1000)) < REPEAT_GAP_MSEC:
		return null
	var stream: AudioStream = _stream_for(sound)
	if stream:
		_last_played[sound] = now
	return stream


static func _stream_for(sound: StringName) -> AudioStream:
	if not _render_done:
		# still rendering: play it if it is ready, stay quiet if it is not.
		# rendering it here instead would stall the frame.
		_mutex.lock()
		var ready: AudioStream = _streams.get(sound)
		_mutex.unlock()
		return ready
	var stream: AudioStream = _streams.get(sound)
	if not stream:
		# a name with no recipe still makes a noise, and says so once
		push_warning("audio: no recipe for sound '%s'" % sound)
		stream = SoundSynth.render(String(sound))
		_streams[sound] = stream
	return stream


# --- music ----------------------------------------------------------------------

## starts rendering the music for a place without switching to it.
func prepare_music(place: StringName) -> void:
	if not is_silent():
		_request_track(MusicSynth.key_for(place))


## switches the soundtrack to a place's key. the change fades through
## silence, and waits for the render if the track is not ready yet.
func play_music(place: StringName) -> void:
	if is_silent():
		return
	_wanted_root = MusicSynth.key_for(place)
	_request_track(_wanted_root)


## how intense the music should be. layers fade in and out to match.
func set_music_state(state: MusicState) -> void:
	_music_state = state


func music_state() -> MusicState:
	return _music_state


func _update_music(delta: float) -> void:
	if _layers.is_empty():
		return
	if _wanted_root != _loaded_root:
		var track: Dictionary = _track_for(_wanted_root)
		if not track.is_empty():
			_swap = move_toward(_swap, 0.0, delta / KEY_FADE) if _loaded_root >= 0 else 0.0
			if _swap <= 0.0:
				# all three start on the same frame and are the same length,
				# so they stay locked together for as long as they loop
				for i: int in _layers.size():
					_layers[i].stream = track[LAYER_NAMES[i]]
					_layers[i].play()
				_loaded_root = _wanted_root
	else:
		_swap = move_toward(_swap, 1.0, delta / KEY_FADE)

	var mix: Array = STATE_MIX[_music_state]
	for i: int in _layers.size():
		var target: float = mix[i]
		_gain[i] = move_toward(_gain[i], target, delta / (FADE_IN if target > _gain[i] else FADE_OUT))
		var level: float = _gain[i] * _swap * LAYER_LEVEL[i]
		_layers[i].volume_db = linear_to_db(level) if level > 0.0005 else -80.0


# --- background rendering -------------------------------------------------------

static func _begin_render() -> void:
	if _render_started:
		return
	_render_started = true
	_queue = RENDER_FIRST.duplicate()
	for sound: String in SoundSynth.names():
		if not _queue.has(sound):
			_queue.append(sound)
	_render_group = WorkerThreadPool.add_group_task(_render_sound, _queue.size(), -1, false, "sound effects")


static func _render_sound(index: int) -> void:
	var sound: String = _queue[index]
	var stream: AudioStreamWAV = SoundSynth.render(sound)
	_mutex.lock()
	_streams[StringName(sound)] = stream
	_mutex.unlock()


static func _request_track(root: int) -> void:
	if _track_tasks.has(root) or not _track_for(root).is_empty():
		return
	_track_tasks[root] = WorkerThreadPool.add_task(_render_track.bind(root), false, "music")


static func _render_track(root: int) -> void:
	var track: Dictionary = MusicSynth.render(root)
	_mutex.lock()
	_tracks[root] = track
	_mutex.unlock()


static func _track_for(root: int) -> Dictionary:
	_mutex.lock()
	var track: Dictionary = _tracks.get(root, {})
	_mutex.unlock()
	return track


static func _finish_tasks() -> void:
	if _render_group >= 0:
		WorkerThreadPool.wait_for_group_task_completion(_render_group)
		_render_group = -1
		_render_done = true
	for root: int in _track_tasks.keys():
		WorkerThreadPool.wait_for_task_completion(_track_tasks[root])
	_track_tasks.clear()


## every worker task has to be waited on once so the pool can release it.
static func _collect_finished_tasks() -> void:
	if _render_group >= 0 and WorkerThreadPool.is_group_task_completed(_render_group):
		WorkerThreadPool.wait_for_group_task_completion(_render_group)
		_render_group = -1
		_render_done = true
	for root: int in _track_tasks.keys():
		if WorkerThreadPool.is_task_completed(_track_tasks[root]):
			WorkerThreadPool.wait_for_task_completion(_track_tasks[root])
			_track_tasks.erase(root)
