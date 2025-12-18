extends CanvasLayer

const FADE_DURATION := 1.5
const MESSAGE_HOLD := 5.5

@onready var money_label: Label = $MarginContainer/VBoxContainer/MoneyLabel
@onready var carrying_label: Label = $MarginContainer/VBoxContainer/CarryingLabel
@onready var time_bar: ProgressBar = $MarginContainer/VBoxContainer/TimeBar
@onready var notification_container: VBoxContainer = $NotificationContainer
@onready var pause_menu: Control = $PauseMenu
@onready var resume_button: Button = $PauseMenu/Panel/VBoxContainer/ResumeButton
@onready var menu_button: Button = $PauseMenu/Panel/VBoxContainer/MenuButton
@onready var fade_rect: ColorRect = $TransitionLayer/FadeRect
@onready var transition_label: Label = $TransitionLayer/TransitionLabel

var in_transition: bool = false
var transition_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PlayerData.money_changed.connect(_on_money_changed)
	PlayerData.carrying_changed.connect(_on_carrying_changed)
	TimeSystem.time_changed.connect(_on_time_changed)
	TimeSystem.new_morning.connect(_on_new_morning)
	TimeSystem.mugged.connect(_on_mugged)
	UIEvents.notify.connect(show_message)
	UIEvents.sleep_sequence_requested.connect(_on_sleep_sequence_requested)
	GameState.mode_changed.connect(_on_mode_changed)
	resume_button.pressed.connect(_on_resume_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	_on_money_changed(PlayerData.money)
	_on_carrying_changed(PlayerData.carrying_item)
	_on_time_changed(TimeSystem.day_time)
	pause_menu.visible = false
	fade_rect.visible = false
	fade_rect.color = Color(0, 0, 0, 0)
	transition_label.visible = false
	transition_label.modulate = Color(1, 1, 1, 0)

func _on_money_changed(amount: int) -> void:
	money_label.text = "Money: $" + str(amount)

func _on_carrying_changed(item_name: String) -> void:
	carrying_label.text = "Carrying: %s" % (item_name if item_name != "" else "None")

func _on_time_changed(day_time: float) -> void:
	time_bar.value = day_time
	time_bar.tooltip_text = "Day progress"

func _on_new_morning() -> void:
	if in_transition:
		return
	show_message("Morning. New deliveries available.")

func show_message(message: String, duration: float = 5) -> void:
	if in_transition:
		return
	var label = Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_color_override("font_color", Color("#ffd9a1"))
	notification_container.add_child(label)
	
	label.position = Vector2(0, -20)
	label.modulate = Color(1,1,1,0)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", Vector2(0,0), 0.3).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(label, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
	tween.set_parallel(false)
	
	tween.tween_interval(duration)
	
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 0.0, 1.5).set_trans(Tween.TRANS_SINE)
	tween.set_parallel(false)
	
	tween.tween_callback(label.queue_free)

func _on_mode_changed(mode: GameState.Mode) -> void:
	pause_menu.visible = mode == GameState.Mode.PAUSED and not in_transition

func _on_resume_pressed() -> void:
	GameState.set_mode(GameState.Mode.PLAYING)

func _on_menu_pressed() -> void:
	GameState.set_mode(GameState.Mode.MENU)
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _on_mugged() -> void:
	_play_transition("You were mugged! Money lost.", true)

func _on_sleep_sequence_requested(message: String) -> void:
	_play_transition(message, false)

func _play_transition(message: String, is_mugged: bool) -> void:
	in_transition = true
	fade_rect.visible = true
	fade_rect.color = Color(0, 0, 0, 0)
	transition_label.visible = true
	transition_label.text = message
	transition_label.modulate = Color(1, 1, 1, 0)
	if transition_tween:
		transition_tween.kill()
	var target_mode := GameState.Mode.SLEEPING
	if is_mugged:
		target_mode = GameState.Mode.MUGGED
	GameState.set_mode(target_mode)
	transition_tween = create_tween()
	transition_tween.tween_property(fade_rect, "color:a", 1.0, FADE_DURATION)
	transition_tween.tween_property(transition_label, "modulate:a", 1.0, 0.25)
	transition_tween.tween_callback(func() -> void:
		if is_mugged:
			PlayerData.reset_money()
			PlayerData.clear_carrying()
			Jobs.cancel_job()
		TimeSystem.start_new_day()
	)
	transition_tween.tween_interval(MESSAGE_HOLD)
	transition_tween.tween_property(fade_rect, "color:a", 0.0, FADE_DURATION)
	transition_tween.tween_property(transition_label, "modulate:a", 0.0, 0.25)
	transition_tween.tween_callback(_finish_transition)

func _finish_transition() -> void:
	fade_rect.visible = false
	transition_label.visible = false
	in_transition = false
	GameState.set_mode(GameState.Mode.PLAYING)
