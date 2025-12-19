extends CanvasLayer

const FADE_DURATION := 1.5
const MESSAGE_HOLD := 5.5

@onready var money_label: Label = $MarginContainer/VBoxContainer/StatusRow/MoneyPanel/MoneyMargin/MoneyVBox/MoneyLabel
@onready var time_label: Label = $MarginContainer/VBoxContainer/StatusRow/TimePanel/TimeMargin/TimeVBox/TimeLabel
@onready var carrying_label: Label = $PackageMenu/PackageMargin/PackageVBox/JobVBox/CarryingLabel
@onready var package_menu: Control = $PackageMenu
@onready var notification_container: VBoxContainer = $NotificationContainer
@onready var pause_menu: Control = $PauseMenu
@onready var resume_button: Button = $PauseMenu/Panel/VBoxContainer/ResumeButton
@onready var menu_button: Button = $PauseMenu/Panel/VBoxContainer/MenuButton
@onready var fade_rect: ColorRect = $TransitionLayer/FadeRect
@onready var transition_label: Label = $TransitionLayer/TransitionLabel
@onready var interact_prompt: Label = $InteractPrompt
@onready var ui_sfx: UiSfx = $UISfx

var in_transition: bool = false
var transition_tween: Tween
var package_pause_active: bool = false
var interact_prompt_owner_id: int = 0

const DAY_START_MINUTES := 6 * 60
const DAY_END_MINUTES := 24 * 60

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PlayerData.money_changed.connect(_on_money_changed)
	PlayerData.carrying_changed.connect(_on_carrying_changed)
	TimeSystem.time_changed.connect(_on_time_changed)
	TimeSystem.new_morning.connect(_on_new_morning)
	TimeSystem.mugged.connect(_on_mugged)
	UIEvents.notify.connect(show_message)
	UIEvents.sleep_sequence_requested.connect(_on_sleep_sequence_requested)
	UIEvents.interact_prompt_changed.connect(_on_interact_prompt_changed)
	GameState.mode_changed.connect(_on_mode_changed)
	resume_button.pressed.connect(_on_resume_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	ui_sfx.connect_button(resume_button)
	ui_sfx.connect_button(menu_button, "back")
	_on_money_changed(PlayerData.money)
	_on_carrying_changed(PlayerData.carrying_item)
	_on_time_changed(TimeSystem.day_time)
	pause_menu.visible = false
	package_menu.visible = false
	fade_rect.visible = false
	fade_rect.color = Color(0, 0, 0, 0)
	transition_label.visible = false
	transition_label.modulate = Color(1, 1, 1, 0)
	interact_prompt.visible = false

func _on_money_changed(amount: int) -> void:
	money_label.text = "$" + str(amount)

func _on_carrying_changed(item_name: String) -> void:
	carrying_label.text = "Carrying: %s" % (item_name if item_name != "" else "None")

func _on_time_changed(day_time: float) -> void:
	time_label.text = "%s  Curfew %s" % [_format_time(day_time), _format_curfew_time()]
	time_label.tooltip_text = "Day time and curfew"

func _format_time(day_time: float) -> String:
	var total_minutes := int(round(lerp(DAY_START_MINUTES, DAY_END_MINUTES, day_time)))
	total_minutes = clamp(total_minutes, DAY_START_MINUTES, DAY_END_MINUTES)
	var hours := total_minutes / 60
	var minutes := total_minutes % 60
	return "%s:%s" % [str(hours).pad_zeros(2), str(minutes).pad_zeros(2)]

func _format_curfew_time() -> String:
	var total_minutes := int(round(lerp(
		DAY_START_MINUTES,
		DAY_END_MINUTES,
		TimeSystem.curfew_ratio
	)))
	total_minutes = clamp(total_minutes, DAY_START_MINUTES, DAY_END_MINUTES)
	var hours := total_minutes / 60
	var minutes := total_minutes % 60
	return "%s:%s" % [str(hours).pad_zeros(2), str(minutes).pad_zeros(2)]

func _on_new_morning() -> void:
	if in_transition:
		return
	show_message("Morning. New deliveries available.")

func show_message(message: String, duration: float = 5) -> void:
	if in_transition:
		return
	ui_sfx.play_notify()
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
	pause_menu.visible = mode == GameState.Mode.PAUSED and not in_transition and not package_pause_active
	if mode == GameState.Mode.PLAYING and package_pause_active:
		package_pause_active = false
		package_menu.visible = false
	if mode != GameState.Mode.PLAYING and not package_pause_active:
		package_menu.visible = false
	if mode != GameState.Mode.PAUSED and package_pause_active:
		package_pause_active = false

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

func _unhandled_input(event: InputEvent) -> void:
	var toggle_pressed := event.is_action_pressed("toggle_package_menu")
	if not toggle_pressed and event is InputEventKey:
		toggle_pressed = event.pressed and event.keycode == Key.KEY_TAB
	if toggle_pressed:
		if in_transition:
			return
		if not GameState.is_playing() and not package_pause_active:
			return
		var next_visible := not package_menu.visible
		package_menu.visible = next_visible
		package_pause_active = next_visible
		GameState.set_mode(GameState.Mode.PAUSED if next_visible else GameState.Mode.PLAYING)
		get_viewport().set_input_as_handled()

func _on_interact_prompt_changed(visible: bool, action: String, owner_id: int) -> void:
	if visible:
		interact_prompt_owner_id = owner_id
		interact_prompt.text = "Press %s to use" % _get_action_label(action)
		interact_prompt.visible = true
		return
	if owner_id != 0 and owner_id != interact_prompt_owner_id:
		return
	interact_prompt_owner_id = 0
	interact_prompt.visible = false

func _get_action_label(action: String) -> String:
	var events := InputMap.action_get_events(action)
	for event in events:
		var text := event.as_text()
		if text != "":
			return text
	return action
