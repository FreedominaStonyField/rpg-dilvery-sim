extends Node
class_name UiSfx

@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

@export var profile: UiSfxProfile

const DEFAULT_PROFILE := preload("res://assets/audio/profiles/ui_sfx_default.tres")

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	if profile == null:
		profile = DEFAULT_PROFILE

func connect_button(button: BaseButton, kind: String = "press") -> void:
	if button == null:
		return
	button.mouse_entered.connect(func() -> void:
		if button.disabled:
			return
		_play_kind("hover")
	)
	button.focus_entered.connect(func() -> void:
		if button.disabled:
			return
		_play_kind("hover")
	)
	button.pressed.connect(func() -> void:
		if button.disabled:
			return
		_play_kind(kind)
	)

func play_click() -> void:
	if profile == null:
		return
	_play_random(profile.click_sounds, profile.click_volume_db)

func play_back() -> void:
	if profile == null:
		return
	_play_random(profile.back_sounds, profile.back_volume_db)

func play_confirm() -> void:
	if profile == null:
		return
	_play_random(profile.confirm_sounds, profile.confirm_volume_db)

func play_notify() -> void:
	if profile == null:
		return
	_play_random(profile.notify_sounds, profile.notify_volume_db)

func play_hover() -> void:
	if profile == null:
		return
	_play_random(profile.hover_sounds, profile.hover_volume_db)

func play_press() -> void:
	if profile == null:
		return
	if profile.press_sounds.is_empty():
		_play_random(profile.click_sounds, profile.click_volume_db)
		return
	_play_random(profile.press_sounds, profile.press_volume_db)

func _play_kind(kind: String) -> void:
	match kind:
		"hover":
			play_hover()
		"press":
			play_press()
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
	var jitter := profile.pitch_jitter if profile != null else 0.05
	audio_player.pitch_scale = 1.0 + rng.randf_range(-jitter, jitter)
	audio_player.volume_db = volume_db
	audio_player.play()
