extends Node
class_name MenuAudio

@export var profile: MenuAudioProfile
@export var autoplay: bool = true

@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

const DEFAULT_PROFILE := preload("res://assets/audio/profiles/menu_audio_default.tres")

var rng := RandomNumberGenerator.new()
var last_index: int = -1

func _ready() -> void:
	rng.randomize()
	if profile == null:
		profile = DEFAULT_PROFILE
	if audio_player != null:
		audio_player.finished.connect(_on_track_finished)
	if autoplay:
		play_menu()

func play_menu() -> void:
	if profile == null:
		return
	if audio_player == null or profile.music_tracks.is_empty():
		return
	audio_player.volume_db = profile.music_volume_db
	_play_track(_choose_index())

func stop_menu() -> void:
	if audio_player == null:
		return
	audio_player.stop()

func _play_track(index: int) -> void:
	if profile == null or audio_player == null:
		return
	if index < 0 or index >= profile.music_tracks.size():
		return
	audio_player.stream = profile.music_tracks[index]
	audio_player.play()

func _choose_index() -> int:
	if profile.music_tracks.size() <= 1:
		last_index = 0
		return 0
	var index := rng.randi_range(0, profile.music_tracks.size() - 1)
	if index == last_index:
		index = (index + 1) % profile.music_tracks.size()
	last_index = index
	return index

func _on_track_finished() -> void:
	if profile == null or not profile.loop_playlist:
		return
	if profile.music_tracks.is_empty():
		return
	_play_track(_choose_index())
