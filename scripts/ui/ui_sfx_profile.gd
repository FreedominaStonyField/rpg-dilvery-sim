extends Resource
class_name UiSfxProfile

@export var click_sounds: Array[AudioStream] = []
@export var back_sounds: Array[AudioStream] = []
@export var confirm_sounds: Array[AudioStream] = []
@export var notify_sounds: Array[AudioStream] = []
@export var hover_sounds: Array[AudioStream] = []
@export var press_sounds: Array[AudioStream] = []

@export var click_volume_db: float = -8.0
@export var back_volume_db: float = -6.0
@export var confirm_volume_db: float = -6.0
@export var notify_volume_db: float = -10.0
@export var hover_volume_db: float = -12.0
@export var press_volume_db: float = -8.0
@export var pitch_jitter: float = 0.05
