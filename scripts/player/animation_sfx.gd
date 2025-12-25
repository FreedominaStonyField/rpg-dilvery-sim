@tool
extends AudioStreamPlayer3D
class_name AnimationSfx

@export var profile: PlayerSfxProfile
@export var pool_size: int = 3
@export var allow_expand: bool = true

var _rng = RandomNumberGenerator.new()
var _pool: Array[AudioStreamPlayer3D] = []

func _ready() -> void:
	_rng.randomize()
	_build_pool()

func play_walk_step() -> void:
	if profile == null:
		return
	_play_from_profile(
		profile.footstep_walk_sounds,
		profile.footstep_walk_volume_db,
		profile.footstep_walk_pitch_scale,
		profile.footstep_walk_volume_jitter_db,
		profile.footstep_walk_pitch_jitter
	)

func play_run_step() -> void:
	if profile == null:
		return
	_play_from_profile(
		profile.footstep_sprint_sounds,
		profile.footstep_sprint_volume_db,
		profile.footstep_sprint_pitch_scale,
		profile.footstep_sprint_volume_jitter_db,
		profile.footstep_sprint_pitch_jitter
	)

func play_jump_start() -> void:
	if profile == null:
		return
	_play_from_profile(
		profile.jump_start_sounds,
		profile.jump_start_volume_db,
		profile.jump_start_pitch_scale,
		profile.jump_start_volume_jitter_db,
		profile.jump_start_pitch_jitter
	)

func play_jump_air() -> void:
	if profile == null:
		return
	_play_from_profile(
		profile.jump_air_sounds,
		profile.jump_air_volume_db,
		profile.jump_air_pitch_scale,
		profile.jump_air_volume_jitter_db,
		profile.jump_air_pitch_jitter
	)

func play_land() -> void:
	if profile == null:
		return
	_play_from_profile(
		profile.landing_sounds,
		profile.landing_volume_db,
		profile.landing_pitch_scale,
		profile.landing_volume_jitter_db,
		profile.landing_pitch_jitter
	)

func _play_from_profile(
		sounds: Array[AudioStream],
		base_volume_db: float,
		base_pitch_scale: float,
		volume_jitter_db: float,
		pitch_jitter: float
	) -> void:
	if profile == null or sounds.is_empty():
		return
	var stream = _pick_random_stream(sounds)
	if stream == null:
		return
	var final_volume = volume_db + base_volume_db
	if volume_jitter_db > 0.0:
		final_volume += _rng.randf_range(-volume_jitter_db, volume_jitter_db)
	var final_pitch = pitch_scale * base_pitch_scale
	if pitch_jitter > 0.0:
		final_pitch *= 1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter)
	final_pitch = max(final_pitch, 0.01)
	_play_stream_with_settings(stream, final_volume, final_pitch)

func _pick_random_stream(sounds: Array[AudioStream]) -> AudioStream:
	if sounds.is_empty():
		return null
	var index = _rng.randi_range(0, sounds.size() - 1)
	return sounds[index]

func _play_stream_with_settings(
		sound: AudioStream,
		volume_db_override: float,
		pitch_scale_override: float
	) -> void:
	if sound == null:
		return
	var player = _get_available_player()
	_apply_template_settings(player)
	player.stream = sound
	player.volume_db = volume_db_override
	player.pitch_scale = pitch_scale_override
	player.play()

func _build_pool() -> void:
	_pool.clear()
	_pool.append(self)
	for index in range(pool_size):
		var player = AudioStreamPlayer3D.new()
		player.name = "SfxInstance_%d" % (index + 1)
		add_child(player)
		_pool.append(player)

func _get_available_player() -> AudioStreamPlayer3D:
	for player in _pool:
		if player.playing == false:
			return player
	if allow_expand:
		var player = AudioStreamPlayer3D.new()
		player.name = "SfxInstance_%d" % (_pool.size() + 1)
		add_child(player)
		_pool.append(player)
		return player
	return self

func _apply_template_settings(player: AudioStreamPlayer3D) -> void:
	if player == self:
		return
	player.bus = bus
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.unit_size = unit_size
	player.max_distance = max_distance
	player.attenuation_filter_cutoff_hz = attenuation_filter_cutoff_hz
	player.attenuation_filter_db = attenuation_filter_db
	player.doppler_tracking = doppler_tracking
