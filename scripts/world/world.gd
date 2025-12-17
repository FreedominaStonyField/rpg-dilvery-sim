extends Node3D

func _ready() -> void:
	GameState.set_mode(GameState.Mode.PLAYING)
	GameState.mode_changed.connect(_on_mode_changed)
	TimeSystem.set_outdoors(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	UIEvents.show_message("Pick up the parcel and deliver it before curfew.")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		GameState.toggle_pause()

func _on_mode_changed(mode: GameState.Mode) -> void:
	if mode == GameState.Mode.PAUSED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif mode == GameState.Mode.PLAYING:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
