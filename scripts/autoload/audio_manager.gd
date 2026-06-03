extends Node
# AudioManager — central sound system for Drain The Swamp.
#
# All SFX are synthesized procedurally at boot (no audio asset files), so the
# game ships identically on desktop/Steam and web with zero load cost.
#
# Wiring is centralized here: AudioManager listens to GameManager's existing
# signals (scoop_performed, water_sold, swamp_completed, tool_upgraded, ...) and
# auto-attaches a click to every Button via SceneTree.node_added, so almost no
# other file needs to know audio exists.

const MIX_RATE: int = 44100
const SFX_VOICES: int = 10

# Bus indices (resolved in _ready)
var _bus_sfx: int = 0
var _bus_music: int = 0
var _bus_ambient: int = 0

# Linear volumes 0..1 (persisted to user://settings.cfg)
var vol_master: float = 1.0
var vol_sfx: float = 0.75
var vol_music: float = 0.8
var vol_ambient: float = 0.45

var _streams: Dictionary = {}          # name -> AudioStreamWAV
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _ambient_player: AudioStreamPlayer = null
var _music_player: AudioStreamPlayer = null

var _last_click_ms: int = 0

const SETTINGS_PATH: String = "user://settings.cfg"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep audio alive while the game is paused (menus)
	_setup_buses()
	_load_settings()
	_apply_video_settings()
	_build_streams()
	_setup_players()
	_apply_all_volumes()
	_connect_game_signals()
	# Auto-attach a UI click to every button created anywhere in the game.
	get_tree().node_added.connect(_on_node_added)
	# Background music: the Music bus + _music_player are ready for user-provided
	# songs (TODO). No procedural ambient bed — it read as a "weird bass" drone.

# =============================================================================
# Bus / player setup
# =============================================================================
func _setup_buses() -> void:
	_bus_sfx = _ensure_bus("SFX")
	_bus_music = _ensure_bus("Music")
	_bus_ambient = _ensure_bus("Ambient")

func _ensure_bus(bus_name: String) -> int:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
	return idx

func _setup_players() -> void:
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_sfx_players.append(p)
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = "Ambient"
	_ambient_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ambient_player)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player)

# =============================================================================
# Volume control (used by the settings menu)
# =============================================================================
func set_volume(channel: String, v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	match channel:
		"master": vol_master = v
		"sfx": vol_sfx = v
		"music": vol_music = v
		"ambient": vol_ambient = v
	_apply_all_volumes()
	_save_settings()

func get_volume(channel: String) -> float:
	match channel:
		"master": return vol_master
		"sfx": return vol_sfx
		"music": return vol_music
		"ambient": return vol_ambient
	return 1.0

func _apply_all_volumes() -> void:
	_apply_bus_volume(AudioServer.get_bus_index("Master"), vol_master)
	_apply_bus_volume(_bus_sfx, vol_sfx)
	_apply_bus_volume(_bus_music, vol_music)
	_apply_bus_volume(_bus_ambient, vol_ambient)

func _apply_bus_volume(idx: int, v: float) -> void:
	if idx < 0:
		return
	if v <= 0.001:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(v))

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	vol_master = float(cfg.get_value("audio", "master", vol_master))
	vol_sfx = float(cfg.get_value("audio", "sfx", vol_sfx))
	vol_music = float(cfg.get_value("audio", "music", vol_music))
	vol_ambient = float(cfg.get_value("audio", "ambient", vol_ambient))

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # keep other sections (e.g. video)
	cfg.set_value("audio", "master", vol_master)
	cfg.set_value("audio", "sfx", vol_sfx)
	cfg.set_value("audio", "music", vol_music)
	cfg.set_value("audio", "ambient", vol_ambient)
	cfg.save(SETTINGS_PATH)

# =============================================================================
# Video settings (kept here as the early-boot settings owner)
# =============================================================================
func _apply_video_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	_set_window_fullscreen(bool(cfg.get_value("video", "fullscreen", false)))

func is_fullscreen() -> bool:
	var m: int = DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func set_fullscreen(enabled: bool) -> void:
	_set_window_fullscreen(enabled)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("video", "fullscreen", enabled)
	cfg.save(SETTINGS_PATH)

func _set_window_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	)

# =============================================================================
# Playback API
# =============================================================================
func play(sound_name: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	var st: AudioStreamWAV = _streams.get(sound_name)
	if st == null:
		return
	var p: AudioStreamPlayer = _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	p.stream = st
	p.pitch_scale = pitch
	p.volume_db = vol_db
	p.play()

func play_scoop(tool_id: String) -> void:
	# Bigger tools = lower, beefier splash; small random for variety.
	var order: int = 0
	if GameManager.tool_definitions.has(tool_id):
		order = int(GameManager.tool_definitions[tool_id].get("order", 0))
	var t: float = clampf(float(order) / 8.0, 0.0, 1.0)
	var pitch: float = lerpf(1.12, 0.82, t) * randf_range(0.94, 1.05)
	var vol: float = lerpf(-13.0, -5.0, t)
	play("scoop", pitch, vol)

func play_sell(amount: float) -> void:
	# Slightly brighter chime for bigger sales.
	var pitch: float = clampf(0.98 + log(maxf(amount, 1.0)) * 0.012, 0.98, 1.18)
	play("sell", pitch, 0.0)

func play_ui_click() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_click_ms < 45:
		return
	_last_click_ms = now
	play("ui_click", randf_range(0.97, 1.04), -8.0)

func play_footstep() -> void:
	play("footstep", randf_range(0.9, 1.12), -17.0)

# =============================================================================
# Signal wiring
# =============================================================================
func _connect_game_signals() -> void:
	GameManager.scoop_performed.connect(_on_scoop_performed)
	GameManager.water_sold.connect(play_sell)
	GameManager.swamp_completed.connect(func(_i: int, _r: float) -> void: play("pool_complete", 1.0, 1.0))
	GameManager.tool_upgraded.connect(func(_t: String, _l: int) -> void: play("upgrade", 1.0, -1.0))
	GameManager.stat_upgraded.connect(func(_s: String, _l: int) -> void: play("upgrade", 1.06, -1.0))
	GameManager.cave_unlocked.connect(func(_c: String) -> void: play("discovery", 1.0, 0.0))
	GameManager.loot_collected.connect(func(_c: String, _l: String, _r: String) -> void: play("loot", 1.0, 0.0))

func _on_scoop_performed(_swamp_index: int, _gallons: float, _money: float) -> void:
	play_scoop(GameManager.current_tool_id)

func play_error() -> void:
	play("error", 1.0, -2.0)

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var b: BaseButton = node
		if not b.pressed.is_connected(play_ui_click):
			b.pressed.connect(play_ui_click)

# =============================================================================
# Procedural SFX synthesis
# =============================================================================
func _build_streams() -> void:
	_streams["scoop"] = _make_wav(_synth_scoop())
	_streams["sell"] = _make_wav(_synth_sell())
	_streams["pool_complete"] = _make_wav(_synth_pool_complete())
	_streams["upgrade"] = _make_wav(_synth_upgrade())
	_streams["ui_click"] = _make_wav(_synth_ui_click())
	_streams["error"] = _make_wav(_synth_error())
	_streams["discovery"] = _make_wav(_synth_discovery())
	_streams["loot"] = _make_wav(_synth_loot())
	_streams["footstep"] = _make_wav(_synth_footstep())

func _make_wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var n: int = samples.size()
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var v: float = clampf(samples[i], -1.0, 1.0)
		bytes.encode_s16(i * 2, int(v * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = n
	return wav

# A pitch-sweeping sine (gentle "bloop"/water drop).
func _sweep(f0: float, f1: float, dur: float, amp: float, decay: float) -> PackedFloat32Array:
	var n: int = int(dur * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	for i in n:
		var t: float = float(i) / MIX_RATE
		var f: float = lerpf(f0, f1, t / dur)
		phase += f / MIX_RATE
		var env: float = exp(-decay * t)
		var atk: float = clampf(t / 0.006, 0.0, 1.0)
		out[i] = sin(phase * TAU) * env * atk * amp
	return out

# A single decaying tone. wave: "sine" | "tri" | "square" | "saw".
func _blip(freq: float, dur: float, amp: float, decay: float, wave: String = "sine") -> PackedFloat32Array:
	var n: int = int(dur * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	var pstep: float = freq / MIX_RATE
	for i in n:
		var t: float = float(i) / MIX_RATE
		var env: float = exp(-decay * t)
		var atk: float = clampf(t / 0.004, 0.0, 1.0)
		var ph: float = phase * TAU
		var s: float = 0.0
		match wave:
			"sine": s = sin(ph)
			"tri": s = asin(sin(ph)) * (2.0 / PI)
			"square": s = 1.0 if sin(ph) >= 0.0 else -1.0
			"saw": s = 2.0 * (phase - floor(phase + 0.5))
		out[i] = s * env * atk * amp
		phase += pstep
	return out

# Mix `add` into `buf` starting at sample offset, growing buf as needed.
func _mix_into(buf: PackedFloat32Array, add: PackedFloat32Array, start: int) -> PackedFloat32Array:
	var need: int = start + add.size()
	if buf.size() < need:
		buf.resize(need)
	for i in add.size():
		buf[start + i] += add[i]
	return buf

func _noise_burst(dur: float, amp: float, decay: float, lp: float) -> PackedFloat32Array:
	# lp = one-pole low-pass coefficient (0..1); lower = more muffled.
	var n: int = int(dur * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y: float = 0.0
	for i in n:
		var t: float = float(i) / MIX_RATE
		var env: float = exp(-decay * t)
		var x: float = randf_range(-1.0, 1.0)
		y += (x - y) * lp
		out[i] = y * env * amp
	return out

func _synth_scoop() -> PackedFloat32Array:
	# Gentle water "bloop": soft descending sine + a quiet, heavily muffled splash tail.
	var buf := PackedFloat32Array()
	buf = _mix_into(buf, _sweep(540.0, 280.0, 0.13, 0.32, 11.0), 0)
	buf = _mix_into(buf, _noise_burst(0.09, 0.10, 26.0, 0.06), int(0.015 * MIX_RATE))
	return buf

func _synth_footstep() -> PackedFloat32Array:
	# Soft muffled tap: heavily low-passed short noise + faint low thud.
	var buf := PackedFloat32Array()
	buf = _mix_into(buf, _noise_burst(0.055, 0.16, 42.0, 0.05), 0)
	buf = _mix_into(buf, _blip(95.0, 0.05, 0.10, 32.0, "sine"), 0)
	return buf

func _synth_sell() -> PackedFloat32Array:
	# Warm two-note coin chime (no harsh highs).
	var buf := PackedFloat32Array()
	buf = _mix_into(buf, _blip(880.0, 0.16, 0.24, 9.5, "sine"), 0)
	buf = _mix_into(buf, _blip(1318.5, 0.22, 0.26, 7.5, "sine"), int(0.06 * MIX_RATE))
	return buf

func _synth_pool_complete() -> PackedFloat32Array:
	# Ascending C-major arpeggio fanfare.
	var notes: Array = [523.25, 659.25, 783.99, 1046.5]
	var buf := PackedFloat32Array()
	for i in notes.size():
		var start: int = int(i * 0.11 * MIX_RATE)
		buf = _mix_into(buf, _blip(notes[i], 0.32, 0.22, 5.0, "sine"), start)
	return buf

func _synth_upgrade() -> PackedFloat32Array:
	# Soft confirming ding (root + fifth).
	var buf := PackedFloat32Array()
	buf = _mix_into(buf, _blip(880.0, 0.22, 0.22, 7.0, "sine"), 0)
	buf = _mix_into(buf, _blip(1318.5, 0.18, 0.10, 8.0, "sine"), int(0.01 * MIX_RATE))
	return buf

func _synth_ui_click() -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf = _mix_into(buf, _noise_burst(0.018, 0.12, 95.0, 0.45), 0)
	buf = _mix_into(buf, _blip(820.0, 0.03, 0.09, 50.0, "sine"), 0)
	return buf

func _synth_error() -> PackedFloat32Array:
	# Soft low "nope" — two muted descending tones.
	var buf := PackedFloat32Array()
	buf = _mix_into(buf, _blip(220.0, 0.10, 0.16, 13.0, "tri"), 0)
	buf = _mix_into(buf, _blip(165.0, 0.13, 0.15, 12.0, "tri"), int(0.07 * MIX_RATE))
	return buf

func _synth_discovery() -> PackedFloat32Array:
	# Mysterious rising two-note (minor flavor).
	var buf := PackedFloat32Array()
	buf = _mix_into(buf, _blip(392.0, 0.32, 0.26, 4.0, "tri"), 0)
	buf = _mix_into(buf, _blip(466.16, 0.40, 0.26, 3.4, "tri"), int(0.16 * MIX_RATE))
	buf = _mix_into(buf, _blip(932.0, 0.30, 0.06, 4.0, "sine"), int(0.16 * MIX_RATE))
	return buf

func _synth_loot() -> PackedFloat32Array:
	# Quick rising pickup.
	var buf := PackedFloat32Array()
	buf = _mix_into(buf, _blip(783.99, 0.11, 0.30, 9.0, "sine"), 0)
	buf = _mix_into(buf, _blip(1046.5, 0.14, 0.32, 8.0, "sine"), int(0.07 * MIX_RATE))
	return buf

# (Procedural ambient bed removed — it read as a "weird bass" drone. Background
# music will come from user-provided songs on the Music bus. Any future ambient
# should be sparse/occasional with variety, not a constant loop.)
