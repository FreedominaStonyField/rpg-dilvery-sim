extends Node3D

@export var player: CharacterBody3D
@export var footstep_interval_walk: float = 0.5
@export var footstep_interval_sprint: float = 0.32
@export var profile: PlayerSfxProfile

@onready var step_player: AudioStreamPlayer3D = $StepPlayer
@onready var one_shot_player: AudioStreamPlayer3D = $OneShotPlayer

const DEFAULT_PROFILE := preload("res://assets/audio/profiles/player_sfx_default.tres")

var step_timer: float = 0.0
var was_on_floor: bool = true
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	if player == null:
		player = get_parent() as CharacterBody3D
	if profile == null:
		profile = DEFAULT_PROFILE

func _physics_process(delta: float) -> void:
	if player == null or not GameState.is_playing():
		return
	var on_floor := player.is_on_floor()
	var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
	if on_floor and was_on_floor and horizontal_speed > 0.2:
		step_timer -= delta
		if step_timer <= 0.0:
			_play_footstep()
			var interval := footstep_interval_sprint if _is_sprinting() else footstep_interval_walk
			step_timer = max(interval, 0.1)
	else:
		step_timer = 0.0
	if was_on_floor and not on_floor:
		if profile != null:
			_play_random(profile.jump_sounds, profile.jump_volume_db, profile.jump_pitch_scale)
	elif not was_on_floor and on_floor:
		if profile != null:
			_play_random(profile.land_sounds, profile.land_volume_db, profile.land_pitch_scale)
	was_on_floor = on_floor

func _is_sprinting() -> bool:
	return player.has_method("is_sprinting") and player.is_sprinting()

func _play_footstep() -> void:
	var clip := _choose_step_stream()
	if clip == null:
		return
	step_player.stream = clip
	var jitter := profile.footstep_pitch_jitter if profile != null else 0.05
	step_player.pitch_scale = 1.0 + rng.randf_range(-jitter, jitter)
	var base_volume := profile.footstep_volume_db if profile != null else -6.0
	step_player.volume_db = base_volume + rng.randf_range(-1.5, 1.5)
	step_player.play()

func _choose_step_stream() -> AudioStream:
	var surface := _guess_surface()
	var options := profile.footstep_concrete if profile != null else []
	if surface == "grass":
		options = profile.footstep_grass if profile != null else []
	elif surface == "carpet":
		options = profile.footstep_carpet if profile != null else []
	return options[rng.randi_range(0, options.size() - 1)] if options.size() > 0 else null

func _guess_surface() -> String:
	var collision := player.get_last_slide_collision()
	if collision:
		var collider := collision.get_collider() as Node
		if collider:
			if collider.is_in_group("grass"):
				return "grass"
			if collider.is_in_group("carpet"):
				return "carpet"
			var name_lower := collider.name.to_lower()
			if name_lower.find("grass") != -1:
				return "grass"
			if name_lower.find("carpet") != -1 or name_lower.find("inn") != -1:
				return "carpet"
	return "concrete"

func _play_random(pool: Array, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if pool.is_empty():
		return
	one_shot_player.stream = pool[rng.randi_range(0, pool.size() - 1)]
	var jitter := profile.one_shot_pitch_jitter if profile != null else 0.02
	one_shot_player.pitch_scale = pitch + rng.randf_range(-jitter, jitter)
	one_shot_player.volume_db = volume_db
	one_shot_player.play()
