class_name HorrorAmbience
extends Node
## Original, procedural coastal soundscape. No recorded or downloaded assets.

const SAMPLE_RATE: int = 22050
const LOOP_SECONDS: float = 4.0
const MAX_CUES: int = 10

var _ocean: AudioStreamPlayer
var _drone: AudioStreamPlayer
var _tension: float = 0.0
var _target_tension: float = 0.0
var _sea_silent := false
var _cue_cache: Dictionary = {}
var _cue_players: Array[AudioStreamPlayer] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 317
	_prepare_players()


func _prepare_players() -> void:
	if is_instance_valid(_ocean):
		if _ocean.stream == null:
			_ocean.stream = _make_loop(false)
		if _drone.stream == null:
			_drone.stream = _make_loop(true)
		return
	_ocean = AudioStreamPlayer.new()
	_ocean.name = "BlackSea"
	_ocean.volume_db = -22.0
	_ocean.stream = _make_loop(false)
	add_child(_ocean)
	_drone = AudioStreamPlayer.new()
	_drone.name = "DistantMachinery"
	_drone.volume_db = -32.0
	_drone.stream = _make_loop(true)
	add_child(_drone)


func start_ambience() -> void:
	_prepare_players()
	if not _ocean.playing:
		_ocean.play()
	if not _drone.playing:
		_drone.play()


func stop_ambience() -> void:
	if is_instance_valid(_ocean):
		_ocean.stop()
	if is_instance_valid(_drone):
		_drone.stop()


func stop_all() -> void:
	# Release playback before the scene disappears. The audio server processes
	# these stop commands on its next mix, so callers quitting immediately should
	# allow a few process frames after this method before closing the tree.
	stop_ambience()
	if is_instance_valid(_ocean):
		_ocean.stream = null
	if is_instance_valid(_drone):
		_drone.stream = null
	for voice in _cue_players:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null
			if not voice.is_queued_for_deletion():
				voice.queue_free()
	_cue_players.clear()
	_cue_cache.clear()


func shutdown() -> void:
	stop_all()


func _exit_tree() -> void:
	stop_all()


func set_tension(value: float) -> void:
	_target_tension = clampf(value, 0.0, 1.0)


func set_sea_silent(silent: bool) -> void:
	_sea_silent = silent


func _process(delta: float) -> void:
	_tension = move_toward(_tension, _target_tension, delta * 0.6)
	if is_instance_valid(_drone):
		_drone.volume_db = lerpf(-32.0, -19.0, _tension)
		_drone.pitch_scale = lerpf(0.96, 1.035, _tension)
	if is_instance_valid(_ocean):
		var target_db := -80.0 if _sea_silent else lerpf(-22.0, -20.0, _tension)
		_ocean.volume_db = move_toward(_ocean.volume_db, target_db, delta * 65.0)


func play_cue(kind: String) -> void:
	# A bounded pool keeps repeated footsteps and combat from accumulating nodes.
	for index in range(_cue_players.size() - 1, -1, -1):
		if not is_instance_valid(_cue_players[index]):
			_cue_players.remove_at(index)
	if _cue_players.size() >= MAX_CUES:
		return
	if not _cue_cache.has(kind):
		_cue_cache[kind] = _make_cue(kind)
	var sound: AudioStreamWAV = _cue_cache[kind] as AudioStreamWAV
	if sound == null:
		return
	var voice: AudioStreamPlayer = AudioStreamPlayer.new()
	voice.stream = sound
	voice.volume_db = -13.0 if kind != "step" else -21.0
	if kind == "phone":
		voice.volume_db = -17.0
	if kind == "step":
		voice.pitch_scale = _rng.randf_range(0.93, 1.08)
	add_child(voice)
	_cue_players.append(voice)
	voice.finished.connect(_release_voice.bind(voice))
	voice.play()


func _release_voice(voice: AudioStreamPlayer) -> void:
	_cue_players.erase(voice)
	voice.stop()
	voice.stream = null
	voice.queue_free()


func _make_loop(drone: bool) -> AudioStreamWAV:
	var count: int = int(LOOP_SECONDS * SAMPLE_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(count * 2)
	var low_noise: float = 0.0
	var softer_noise: float = 0.0
	for index in range(count):
		var time: float = float(index) / SAMPLE_RATE
		var sample: float
		if drone:
			# All oscillators complete whole cycles over the four second loop.
			var pulse: float = 0.76 + 0.24 * sin(TAU * time * 0.25)
			sample = (sin(TAU * 43.0 * time) * 0.24
				+ sin(TAU * 64.5 * time) * 0.11
				+ sin(TAU * 86.25 * time) * 0.055
				+ sin(TAU * 171.75 * time) * 0.025) * pulse
		else:
			low_noise = lerpf(low_noise, _rng.randf_range(-1.0, 1.0), 0.13)
			softer_noise = lerpf(softer_noise, low_noise, 0.025)
			var surf: float = 0.38 + 0.30 * (sin(TAU * time * 0.25 - 0.7) * 0.5 + 0.5)
			sample = (low_noise * 0.45 + softer_noise * 1.3) * surf
			# A short seam envelope avoids a crack at the random waveform wrap.
			var seam: float = minf(1.0, minf(time, LOOP_SECONDS - time) / 0.025)
			sample *= seam
		bytes.encode_s16(index * 2, int(clampf(sample, -0.95, 0.95) * 32767.0))
	var stream: AudioStreamWAV = _wave(bytes)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	return stream


func _make_cue(kind: String) -> AudioStreamWAV:
	var duration: float
	match kind:
		"phone": duration = 1.25
		"pickup": duration = 0.55
		"gate": duration = 1.8
		"hit": duration = 0.23
		"hurt": duration = 0.45
		"ending": duration = 2.4
		"step": duration = 0.15
		"start": duration = 0.85
		_: return null
	var count: int = int(duration * SAMPLE_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(count * 2)
	var filtered: float = 0.0
	for index in range(count):
		var time: float = float(index) / SAMPLE_RATE
		var progress: float = time / duration
		var noise: float = _rng.randf_range(-1.0, 1.0)
		filtered = lerpf(filtered, noise, 0.16)
		var sample: float = 0.0
		match kind:
			"phone":
				var ring_time: float = fmod(time, 0.63)
				var ring_envelope: float = exp(-ring_time * 8.0)
				sample = (sin(TAU * 760.0 * time) * 0.28
					+ sin(TAU * 1049.0 * time) * 0.17) * ring_envelope
			"pickup":
				sample = (sin(TAU * 523.25 * time) * 0.28
					+ sin(TAU * 783.99 * time) * 0.13) * exp(-time * 8.0)
			"gate":
				var scrape: float = pow(1.0 - progress, 0.65)
				var clang: float = exp(-time * 11.0)
				sample = filtered * 0.8 * scrape
				sample += sin(TAU * (120.0 * time + 12.0 * time * time)) * 0.12 * scrape
				sample += (sin(TAU * 317.0 * time) + sin(TAU * 489.0 * time)) * 0.15 * clang
			"hit":
				sample = (filtered * 1.2 + sin(TAU * 91.0 * time) * 0.35) * exp(-time * 25.0)
			"hurt":
				sample = (filtered * 0.9 + sin(TAU * 52.0 * time) * 0.28) * exp(-time * 9.0)
			"ending":
				var swell: float = sin(PI * progress)
				sample = (sin(TAU * 130.81 * time) * 0.16
					+ sin(TAU * 155.56 * time) * 0.12
					+ sin(TAU * 196.0 * time) * 0.08 + filtered * 0.3) * swell
			"step":
				sample = (filtered * 0.65 + sin(TAU * 105.0 * time) * 0.28) * exp(-time * 38.0)
			"start":
				sample = (sin(TAU * 55.0 * time) * 0.25 + filtered * 0.35) * sin(PI * progress) * (1.0 - progress)
		# Every transient has a tiny attack/release to prevent sample-edge clicks.
		var edge: float = minf(1.0, minf(time, duration - time) / 0.004)
		bytes.encode_s16(index * 2, int(clampf(sample * edge, -0.9, 0.9) * 32767.0))
	return _wave(bytes)


func _wave(bytes: PackedByteArray) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
