extends Control

@onready var start_button: Button = $UI_Layer/LayoutRoot/Split/MenuColumn/StartBtn
@onready var quit_button: Button = $UI_Layer/LayoutRoot/Split/MenuColumn/QuitBtn

func _ready() -> void:
	get_tree().paused = false
	GameState.set_mode(GameState.Mode.MENU)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	start_button.grab_focus()
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_start_pressed() -> void:
	GameState.set_mode(GameState.Mode.PLAYING)
	get_tree().change_scene_to_file("res://scenes/world/World.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
