extends Resource
class_name PlayerSfxProfile

@export_group("Footsteps")
@export var footstep_walk_sounds: Array[AudioStream] = []
@export var footstep_sprint_sounds: Array[AudioStream] = []

@export var footstep_walk_volume_db: float = 0.0
@export var footstep_walk_pitch_scale: float = 1.0
@export var footstep_walk_volume_jitter_db: float = 0.0
@export var footstep_walk_pitch_jitter: float = 0.0

@export var footstep_sprint_volume_db: float = 0.0
@export var footstep_sprint_pitch_scale: float = 1.0
@export var footstep_sprint_volume_jitter_db: float = 0.0
@export var footstep_sprint_pitch_jitter: float = 0.0

@export_group("Jump")
@export var jump_start_sounds: Array[AudioStream] = []
@export var jump_air_sounds: Array[AudioStream] = []
@export var landing_sounds: Array[AudioStream] = []

@export var jump_start_volume_db: float = 0.0
@export var jump_start_pitch_scale: float = 1.0
@export var jump_start_volume_jitter_db: float = 0.0
@export var jump_start_pitch_jitter: float = 0.0

@export var jump_air_volume_db: float = 0.0
@export var jump_air_pitch_scale: float = 1.0
@export var jump_air_volume_jitter_db: float = 0.0
@export var jump_air_pitch_jitter: float = 0.0

@export var landing_volume_db: float = 0.0
@export var landing_pitch_scale: float = 1.0
@export var landing_volume_jitter_db: float = 0.0
@export var landing_pitch_jitter: float = 0.0
