extends Resource
class_name PlayerSfxProfile

@export_group("Footsteps")
@export var footstep_walk_sounds: Array[AudioStream] = []
@export var footstep_sprint_sounds: Array[AudioStream] = []
@export var footstep_volume_db: float = -10.0

@export_group("Landing")
@export var landing_sounds: Array[AudioStream] = []
@export var landing_volume_db: float = -8.0
@export var landing_min_impact_speed: float = 2.0

@export_group("Randomization")
@export var pitch_jitter: float = 0.05

