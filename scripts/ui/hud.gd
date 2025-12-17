extends CanvasLayer

@onready var money_label: Label = $MarginContainer/VBoxContainer/MoneyLabel
@onready var carrying_label: Label = $MarginContainer/VBoxContainer/CarryingLabel
@onready var time_bar: ProgressBar = $MarginContainer/VBoxContainer/TimeBar
@onready var message_label: Label = $MessageLabel
@onready var message_timer: Timer = $MessageTimer
@onready var pause_menu: Control = $PauseMenu
@onready var resume_button: Button = $PauseMenu/Panel/VBoxContainer/ResumeButton
@onready var menu_button: Button = $PauseMenu/Panel/VBoxContainer/MenuButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PlayerData.money_changed.connect(_on_money_changed)
	PlayerData.carrying_changed.connect(_on_carrying_changed)
	TimeSystem.time_changed.connect(_on_time_changed)
	TimeSystem.new_morning.connect(_on_new_morning)
	UIEvents.notify.connect(show_message)
	GameState.mode_changed.connect(_on_mode_changed)
	resume_button.pressed.connect(_on_resume_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	message_timer.timeout.connect(_on_message_timeout)
	_on_money_changed(PlayerData.money)
	_on_carrying_changed(PlayerData.carrying_item)
	_on_time_changed(TimeSystem.day_time)
	pause_menu.visible = false
	message_label.visible = false

func _on_money_changed(amount: int) -> void:
	money_label.text = "Money: $" + str(amount)

func _on_carrying_changed(item_name: String) -> void:
	carrying_label.text = "Carrying: %s" % (item_name if item_name != "" else "None")

func _on_time_changed(day_time: float) -> void:
	time_bar.value = day_time
	time_bar.tooltip_text = "Day progress"

func _on_new_morning() -> void:
	show_message("Morning. New deliveries available.")

func show_message(message: String, duration: float = 2.0) -> void:
	message_label.text = message
	message_label.visible = true
	message_timer.stop()
	message_timer.wait_time = duration
	message_timer.start()

func _on_message_timeout() -> void:
	message_label.visible = false

func _on_mode_changed(mode: GameState.Mode) -> void:
	pause_menu.visible = mode == GameState.Mode.PAUSED

func _on_resume_pressed() -> void:
	GameState.set_mode(GameState.Mode.PLAYING)

func _on_menu_pressed() -> void:
	GameState.set_mode(GameState.Mode.MENU)
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
