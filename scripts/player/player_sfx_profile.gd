extends Resource
class_name PlayerSfxProfile

@export var footstep_grass: Array[AudioStream] = []
@export var footstep_concrete: Array[AudioStream] = []
@export var footstep_carpet: Array[AudioStream] = []
@export var jump_sounds: Array[AudioStream] = []
@export var land_sounds: Array[AudioStream] = []

@export var footstep_volume_db: float = -6.0
@export var jump_volume_db: float = -4.0
@export var land_volume_db: float = -2.0

@export var footstep_pitch_jitter: float = 0.05
@export var one_shot_pitch_jitter: float = 0.02
@export var jump_pitch_scale: float = 1.0
@export var land_pitch_scale: float = 1.0
