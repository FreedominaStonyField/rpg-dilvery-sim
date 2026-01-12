extends Control

@export var roll_duration: float = 12.0
@export var prompt_flash_period: float = 0.8

@onready var credits_viewport: Control = $CreditsViewport
@onready var credits_content: Control = $CreditsViewport/CreditsContent
@onready var credits_vbox: VBoxContainer = $CreditsViewport/CreditsContent/CreditsVBox
@onready var prompt_label: Label = $PromptLabel

var _flash_tween: Tween
var _can_exit: bool = false

func _ready() -> void:
	get_tree().paused = false
	GameState.set_mode(GameState.Mode.MENU)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	prompt_label.visible = false
	await get_tree().process_frame
	_start_credits_roll()

func _input(event: InputEvent) -> void:
	if not _can_exit:
		return
	var key_event := event as InputEventKey
	if key_event and key_event.pressed and not key_event.echo:
		_return_to_menu()
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event and mouse_event.pressed:
		_return_to_menu()

func _start_credits_roll() -> void:
	var viewport_size = credits_viewport.size
	var content_height = credits_vbox.get_combined_minimum_size().y
	if content_height <= 0.0:
		content_height = viewport_size.y
	credits_content.size = Vector2(viewport_size.x, content_height)
	credits_content.position = Vector2(0, viewport_size.y)
	var target_y = -content_height
	var tween = create_tween()
	tween.tween_property(credits_content, "position:y", target_y, roll_duration)
	tween.tween_callback(_on_credits_finished)

func _on_credits_finished() -> void:
	_can_exit = true
	prompt_label.visible = true
	prompt_label.modulate = Color(1, 1, 1, 1)
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.set_loops()
	_flash_tween.tween_property(
		prompt_label,
		"modulate:a",
		0.2,
		prompt_flash_period * 0.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flash_tween.tween_property(
		prompt_label,
		"modulate:a",
		1.0,
		prompt_flash_period * 0.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _return_to_menu() -> void:
	if _flash_tween:
		_flash_tween.kill()
	GameState.set_mode(GameState.Mode.MENU)
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
