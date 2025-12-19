extends Node3D
class_name PlayerSfxController

@export var profile: PlayerSfxProfile
@export var player_path: NodePath = NodePath("..")
@export var footsteps_player_path: NodePath = NodePath("Footsteps")
@export var landing_player_path: NodePath = NodePath("Landing")

#const DEFAULT_PROFILE := preload("res://assets/audio/profiles/player_sfx_default.tres")

@onready var player: CharacterBody3D = get_node_or_null(player_path) as CharacterBody3D
@onready var footsteps_player: AudioStreamPlayer3D = get_node_or_null(footsteps_player_path) as AudioStreamPlayer3D
@onready var landing_player: AudioStreamPlayer3D = get_node_or_null(landing_player_path) as AudioStreamPlayer3D

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	#if profile == null:
		#profile = DEFAULT_PROFILE
	if player != null and player.has_signal("landed"):
		player.landed.connect(_on_player_landed)

func anim_footstep() -> void:
	play_footstep()

func _play_footstep() -> void:
	play_footstep()

func play_footstep() -> void:
	if profile == null:
		return
	if player != null and not player.is_on_floor():
		return
	var pool := _choose_footstep_pool()
	_play_random(footsteps_player, pool, profile.footstep_volume_db)

func play_landing(impact_speed: float = 999.0) -> void:
	if profile == null:
		return
	if impact_speed < profile.landing_min_impact_speed:
		return
	_play_random(landing_player, profile.landing_sounds, profile.landing_volume_db)

func _choose_footstep_pool() -> Array[AudioStream]:
	if player != null and player.has_method("is_sprinting") and player.is_sprinting():
		if not profile.footstep_sprint_sounds.is_empty():
			return profile.footstep_sprint_sounds
	return profile.footstep_walk_sounds

func _play_random(
		audio_player: AudioStreamPlayer3D,
		pool: Array[AudioStream],
		volume_db: float
	) -> void:
	if audio_player == null or pool.is_empty():
		return
	if not is_inside_tree() or not audio_player.is_inside_tree():
		return
	audio_player.stop()
	audio_player.stream = pool[rng.randi_range(0, pool.size() - 1)]
	var jitter := profile.pitch_jitter if profile != null else 0.05
	audio_player.pitch_scale = 1.0 + rng.randf_range(-jitter, jitter)
	audio_player.volume_db = volume_db
	audio_player.play()

func _on_player_landed(impact_speed: float) -> void:
	play_landing(impact_speed)
