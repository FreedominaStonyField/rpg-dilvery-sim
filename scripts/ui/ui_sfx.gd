extends Node
class_name UiSfx

@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

const CLICK_SOUNDS := [
	preload("res://assets/audio/ui/click_001.ogg"),
	preload("res://assets/audio/ui/click_002.ogg"),
	preload("res://assets/audio/ui/click_003.ogg")
]
const BACK_SOUNDS := [
	preload("res://assets/audio/ui/back_001.ogg"),
	preload("res://assets/audio/ui/back_002.ogg")
]
const CONFIRM_SOUNDS := [
	preload("res://assets/audio/ui/confirmation_001.ogg"),
	preload("res://assets/audio/ui/confirmation_002.ogg")
]
const NOTIFY_SOUNDS := [
	preload("res://assets/audio/ui/bong_001.ogg"),
	preload("res://assets/audio/ui/close_004.ogg")
]

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func connect_button(button: BaseButton, kind: String = "click") -> void:
	if button == null:
		return
	button.pressed.connect(func() -> void:
		_play_kind(kind)
	)

func play_click() -> void:
	_play_random(CLICK_SOUNDS, -8.0)

func play_back() -> void:
	_play_random(BACK_SOUNDS, -6.0)

func play_confirm() -> void:
	_play_random(CONFIRM_SOUNDS, -6.0)

func play_notify() -> void:
	_play_random(NOTIFY_SOUNDS, -10.0)

func _play_kind(kind: String) -> void:
	match kind:
		"back":
			play_back()
		"confirm":
			play_confirm()
		"notify":
			play_notify()
		_:
			play_click()

func _play_random(pool: Array, volume_db: float = 0.0) -> void:
	if pool.is_empty():
		return
	if audio_player == null or not is_inside_tree() or not audio_player.is_inside_tree():
		return
	audio_player.stop()
	audio_player.stream = pool[rng.randi_range(0, pool.size() - 1)]
	audio_player.pitch_scale = 1.0 + rng.randf_range(-0.05, 0.05)
	audio_player.volume_db = volume_db
	audio_player.play()
