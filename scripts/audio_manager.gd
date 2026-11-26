extends Node

# Two players per continuous layer allow crossfades without restarting the active stream.
var _music_players: Array[AudioStreamPlayer] = []
var _ambience_players: Array[AudioStreamPlayer] = []
# A small rotating pool avoids allocating a new player for every effect.
var _effects: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _track := ""
var _zone := ""
var _ambience_name := ""
var _active_music := -1
var _active_ambience := -1
var _music_weights: Array[float] = [0.0, 0.0]
var _music_targets: Array[float] = [0.0, 0.0]
var _ambience_weights: Array[float] = [0.0, 0.0]
var _ambience_targets: Array[float] = [0.0, 0.0]
var _ambience_scales: Array[float] = [1.0, 1.0]
var _next_effect := 0
var _bird_timer := 8.0
var _paused := false
# The headless dummy driver retains WAV playbacks during engine teardown.
var _audio_enabled := DisplayServer.get_name() != "headless"

# Creates persistent audio players that continue responding while the scene tree is paused.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(2):
		var music := AudioStreamPlayer.new()
		music.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(music)
		_music_players.append(music)
		var ambience := AudioStreamPlayer.new()
		ambience.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(ambience)
		_ambience_players.append(ambience)
	for i in range(6):
		var effect := AudioStreamPlayer.new()
		effect.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(effect)
		_effects.append(effect)
	apply_settings()

# Advances both crossfades and releases players only after their target volume reaches zero.
func _process(delta: float) -> void:
	if not _audio_enabled:
		return
	var blend := delta / 1.15
	for i in range(_music_players.size()):
		_music_weights[i] = move_toward(_music_weights[i], _music_targets[i], blend)
		if _music_weights[i] <= 0.001 and _music_targets[i] <= 0.0 and _music_players[i].playing:
			_music_weights[i] = 0.0
			_music_players[i].stop()
			_music_players[i].stream = null
	for i in range(_ambience_players.size()):
		_ambience_weights[i] = move_toward(_ambience_weights[i], _ambience_targets[i], blend)
		if _ambience_weights[i] <= 0.001 and _ambience_targets[i] <= 0.0 and _ambience_players[i].playing:
			_ambience_weights[i] = 0.0
			_ambience_players[i].stop()
			_ambience_players[i].stream = null
	_update_volumes()
	_update_birds(delta)

# Loads and caches audio, preferring exported WAV files and configuring loop playback on a duplicate.
func _stream(name: String, loop: bool = false) -> AudioStream:
	var key := name + ("_loop" if loop else "")
	if not _cache.has(key):
		var wav_path := "res://assets/audio/" + name + ".wav"
		var mp3_path := "res://assets/audio/" + name + ".mp3"
		# WAV is the Android export-safe choice; MP3 remains a fallback for missing WAV assets.
		var path := wav_path if ResourceLoader.exists(wav_path) else mp3_path
		if not ResourceLoader.exists(path):
			return null
		var stream := ResourceLoader.load(path, "AudioStream") as AudioStream
		if stream == null:
			return null
		if loop:
			stream = stream.duplicate()
			if stream is AudioStreamWAV:
				stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
				stream.loop_begin = 0
				# Exported WAV data is 16-bit PCM, so two bytes represent each sample frame.
				stream.loop_end = stream.data.size() / 2
			elif stream is AudioStreamMP3:
				stream.loop = true
		_cache[key] = stream
	return _cache[key]

# Starts a looping music track on the inactive player and crossfades away from the previous track.
func play_music(name: String) -> void:
	if not _audio_enabled:
		return
	if _track == name and _active_music >= 0 and _music_players[_active_music].playing:
		return
	var stream := _stream("music_" + name, true)
	if stream == null:
		return
	_track = name
	var next_index := 0 if _active_music < 0 else 1 - _active_music
	var player := _music_players[next_index]
	player.stop()
	player.stream = stream
	player.play()
	_music_targets = [0.0, 0.0]
	_music_targets[next_index] = 1.0
	_active_music = next_index
	_refresh_ambience()
	_update_volumes()

# Changes the active zone and restarts the randomized bird schedule for its ambience.
func set_zone(zone: String) -> void:
	if _zone == zone:
		return
	_zone = zone
	_bird_timer = randf_range(7.0, 13.0)
	_refresh_ambience()
	_update_volumes()

# Plays a bounded one-shot effect through the next player in the rotating pool.
func play_sfx(name: String, volume_scale: float = 1.0, pitch_scale: float = 1.0) -> void:
	if not _audio_enabled or float(GameState.settings.sound) <= 0.0 or volume_scale <= 0.0:
		return
	var stream := _stream("sfx_" + name)
	if stream == null:
		return
	var player := _effects[_next_effect]
	_next_effect = (_next_effect + 1) % _effects.size()
	player.stream = stream
	player.volume_db = linear_to_db(maxf(0.0001, float(GameState.settings.sound) * 0.55 * clampf(volume_scale, 0.0, 4.0)))
	player.pitch_scale = clampf(pitch_scale, 0.5, 2.0)
	player.play()

# Reapplies stored volume settings to the live audio layers.
func apply_settings() -> void:
	_update_volumes()

# Pauses continuous layers and immediately stops effects so none resume after focus loss.
func set_paused(value: bool) -> void:
	_paused = value
	for effect in _effects:
		effect.stop()
	_update_volumes()

# Reports whether audio is paused by game or focus handling.
func is_paused() -> bool:
	return _paused

# Stops every player and clears cached streams during scene teardown.
func shutdown() -> void:
	_paused = true
	for player in _music_players + _ambience_players + _effects:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_cache.clear()

# Selects ambience from the current music track and zone, with no ambience on the title screen.
func _refresh_ambience() -> void:
	var next := ""
	if _track != "title":
		if _track == "rain":
			next = "sfx_rain"
		elif _zone == "city":
			next = "sfx_water_loop"
		elif _zone in ["garden", "school", "park", "memorial"]:
			next = "sfx_wind"
	_start_ambience(next)

# Crossfades to the requested ambience or fades all ambience out when the name is empty.
func _start_ambience(name: String) -> void:
	if not _audio_enabled:
		return
	if name.is_empty():
		_ambience_name = ""
		_active_ambience = -1
		_ambience_targets = [0.0, 0.0]
		return
	if _ambience_name == name and _active_ambience >= 0 and _ambience_players[_active_ambience].playing:
		return
	var stream := _stream(name, true)
	if stream == null:
		return
	_ambience_name = name
	var next_index := 0 if _active_ambience < 0 else 1 - _active_ambience
	var player := _ambience_players[next_index]
	player.stop()
	player.stream = stream
	player.play()
	_ambience_targets = [0.0, 0.0]
	_ambience_targets[next_index] = 1.0
	_ambience_scales[next_index] = _ambience_scale(name)
	_active_ambience = next_index

# Returns the relative ambience level for weather and location-specific soundscapes.
func _ambience_scale(name: String) -> float:
	if name == "sfx_rain":
		return 0.9
	if name == "sfx_water_loop":
		return 0.72
	match _zone:
		"memorial":
			return 0.52
		"school":
			return 0.68
		"park":
			return 0.92
	return 0.8

# Schedules quiet bird calls only in eligible outdoor zones while audio is active.
func _update_birds(delta: float) -> void:
	if _paused or float(GameState.settings.sound) <= 0.0 or _track == "title" or _track == "rain":
		return
	if _ambience_name != "sfx_wind" or _zone not in ["garden", "school", "park"]:
		return
	_bird_timer -= delta
	if _bird_timer <= 0.0:
		play_sfx("birds", 0.24 if _zone == "school" else 0.32, randf_range(0.94, 1.06))
		_bird_timer = randf_range(13.0, 23.0)

# Converts layer weights and user settings to decibels, pausing silent or inactive streams.
func _update_volumes() -> void:
	var music_volume := float(GameState.settings.music)
	var sound_volume := float(GameState.settings.sound)
	for i in range(_music_players.size()):
		var level := music_volume * 0.4 * _music_weights[i]
		_music_players[i].volume_db = linear_to_db(maxf(0.0001, level))
		_music_players[i].stream_paused = _paused or music_volume <= 0.0 or level <= 0.0
	for i in range(_ambience_players.size()):
		var level := sound_volume * 0.1 * _ambience_scales[i] * _ambience_weights[i]
		_ambience_players[i].volume_db = linear_to_db(maxf(0.0001, level))
		_ambience_players[i].stream_paused = _paused or sound_volume <= 0.0 or level <= 0.0

# Releases audio resources when the manager leaves the scene tree.
func _exit_tree() -> void:
	shutdown()
