extends Control

@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton

func _ready() -> void:
    get_tree().paused = false
    GameState.set_mode(GameState.Mode.MENU)
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    play_button.pressed.connect(_on_play_pressed)
    quit_button.pressed.connect(_on_quit_pressed)

func _on_play_pressed() -> void:
    PlayerData.reset_money()
    PlayerData.clear_carrying()
    TimeSystem.reset_day()
    GameState.set_mode(GameState.Mode.PLAYING)
    get_tree().change_scene_to_file("res://scenes/world/World.tscn")

func _on_quit_pressed() -> void:
    get_tree().quit()
