extends Node3D

@export var player: CharacterBody3D
@export var footstep_interval_walk: float = 0.5
@export var footstep_interval_sprint: float = 0.32
@export var footstep_volume_db: float = -6.0

@onready var step_player: AudioStreamPlayer3D = $StepPlayer
@onready var one_shot_player: AudioStreamPlayer3D = $OneShotPlayer

const FOOTSTEP_GRASS := [
	preload("res://assets/audio/impacts/footstep_grass_000.ogg"),
	preload("res://assets/audio/impacts/footstep_grass_001.ogg"),
	preload("res://assets/audio/impacts/footstep_grass_002.ogg"),
	preload("res://assets/audio/impacts/footstep_grass_003.ogg")
]
const FOOTSTEP_CONCRETE := [
	preload("res://assets/audio/impacts/footstep_concrete_000.ogg"),
	preload("res://assets/audio/rpg/footstep01.ogg"),
	preload("res://assets/audio/rpg/footstep02.ogg"),
	preload("res://assets/audio/rpg/footstep03.ogg")
]
const FOOTSTEP_CARPET := [
	preload("res://assets/audio/impacts/footstep_carpet_000.ogg"),
	preload("res://assets/audio/impacts/footstep_carpet_001.ogg"),
	preload("res://assets/audio/impacts/footstep_carpet_002.ogg")
]
const PICKUP_SOUNDS := [
	preload("res://assets/audio/rpg/cloth2.ogg"),
	preload("res://assets/audio/rpg/cloth3.ogg")
]
const DELIVERY_SOUNDS := [
	preload("res://assets/audio/rpg/handleCoins.ogg"),
	preload("res://assets/audio/rpg/handleCoins2.ogg")
]
const CURFEW_SOUNDS := [
	preload("res://assets/audio/ui/bong_001.ogg"),
	preload("res://assets/audio/ui/close_003.ogg")
]
const MUGGED_SOUNDS := [
	preload("res://assets/audio/ui/back_003.ogg"),
	preload("res://assets/audio/ui/back_004.ogg")
]
const DOOR_SOUNDS := [
	preload("res://assets/audio/rpg/doorOpen_1.ogg"),
	preload("res://assets/audio/rpg/doorClose_2.ogg")
]
const JUMP_SOUNDS := [
	preload("res://assets/audio/rpg/cloth1.ogg"),
	preload("res://assets/audio/rpg/cloth4.ogg")
]
const LAND_SOUNDS := [
	preload("res://assets/audio/impacts/footstep_concrete_000.ogg"),
	preload("res://assets/audio/impacts/footstep_grass_001.ogg")
]

var step_timer: float = 0.0
var was_on_floor: bool = true
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	if player == null:
		player = get_parent() as CharacterBody3D
	Jobs.job_started.connect(_on_job_started)
	Jobs.job_completed.connect(_on_job_completed)
	TimeSystem.curfew_started.connect(_on_curfew_started)
	TimeSystem.mugged.connect(_on_mugged)
	UIEvents.sleep_sequence_requested.connect(_on_sleep_sequence_requested)

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
		_play_random(JUMP_SOUNDS, -4.0)
	elif not was_on_floor and on_floor:
		_play_random(LAND_SOUNDS, -2.0, 1.0 + rng.randf_range(-0.05, 0.05))
	was_on_floor = on_floor

func _is_sprinting() -> bool:
	return player.has_method("is_sprinting") and player.is_sprinting()

func _play_footstep() -> void:
	var clip := _choose_step_stream()
	if clip == null:
		return
	step_player.stream = clip
	step_player.pitch_scale = 1.0 + rng.randf_range(-0.05, 0.05)
	step_player.volume_db = footstep_volume_db + rng.randf_range(-1.5, 1.5)
	step_player.play()

func _choose_step_stream() -> AudioStream:
	var surface := _guess_surface()
	var options := FOOTSTEP_CONCRETE
	if surface == "grass":
		options = FOOTSTEP_GRASS
	elif surface == "carpet":
		options = FOOTSTEP_CARPET
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

func _on_job_started(_dropoff: Node3D) -> void:
	_play_random(PICKUP_SOUNDS, -2.0)

func _on_job_completed() -> void:
	_play_random(DELIVERY_SOUNDS, -3.0, 1.0 + rng.randf_range(-0.05, 0.05))

func _on_curfew_started() -> void:
	_play_random(CURFEW_SOUNDS, -8.0, 1.0)

func _on_mugged() -> void:
	_play_random(MUGGED_SOUNDS, -4.0, 0.9)

func _on_sleep_sequence_requested(_message: String) -> void:
	_play_random(DOOR_SOUNDS, -6.0)

func _play_random(pool: Array, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if pool.is_empty():
		return
	one_shot_player.stream = pool[rng.randi_range(0, pool.size() - 1)]
	one_shot_player.pitch_scale = pitch + rng.randf_range(-0.02, 0.02)
	one_shot_player.volume_db = volume_db
	one_shot_player.play()
