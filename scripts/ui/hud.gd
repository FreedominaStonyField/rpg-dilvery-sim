extends CanvasLayer

@export var notification_fade_in: float = 0.25
@export var notification_hold: float = 4.0
@export var notification_fade_out: float = 1.0
@export var journal_open_duration: float = 0.22
@export var journal_close_duration: float = 0.2
@export var journal_flash_fade: float = 1.1
@export var pause_fade_duration: float = 0.18
@export var transition_fade_duration: float = 1.2
@export var transition_hold: float = 4.5
@export var interaction_fade_duration: float = 0.16
@export var status_fade_in: float = 0.18
@export var status_hold: float = 2.5
@export var status_fade_out: float = 0.3
@export var offer_menu_open_duration: float = 0.2
@export var offer_menu_close_duration: float = 0.18
@export var alert_text_color: Color = Color(1, 0.35, 0.45, 1)
@export var rest_text_color: Color = Color(0.9, 0.95, 1, 1)

@onready var status_row: Control = $MarginContainer/VBoxContainer/StatusRow
@onready var money_label: Label = $MarginContainer/VBoxContainer/StatusRow/MoneyPanel/MoneyMargin/MoneyVBox/MoneyLabel
@onready var time_label: Label = $MarginContainer/VBoxContainer/StatusRow/TimePanel/TimeMargin/TimeVBox/TimeLabel
@onready var carrying_label: Label = $PackageCenter/PackageMenu/PackageMargin/PackageVBox/InfoBlock/InfoMargin/InfoVBox/InfoGrid/CarryingValue
@onready var package_menu: Control = $PackageCenter/PackageMenu
@onready var job_offer_menu: Control = $OfferCenter/JobOfferMenu
@onready var package_fade_timer: Timer = $PackageFadeTimer
@onready var completion_audio: AudioStreamPlayer = $PackageCenter/PackageMenu/CompletionAudioPlayer
@onready var notification_container: VBoxContainer = $NotificationContainer
@onready var pause_menu: Control = $PauseMenu
@onready var resume_button: Button = $PauseMenu/PauseCenter/Panel/PauseMargin/PauseVBox/ResumeButton
@onready var save_button: Button = $PauseMenu/PauseCenter/Panel/PauseMargin/PauseVBox/SaveButton
@onready var menu_button: Button = $PauseMenu/PauseCenter/Panel/PauseMargin/PauseVBox/MenuButton
@onready var fade_rect: ColorRect = $TransitionLayer/FadeRect
@onready var transition_panel: PanelContainer = $TransitionLayer/TransitionPanel
@onready var transition_label: Label = $TransitionLayer/TransitionPanel/TransitionMargin/TransitionLabel
@onready var interact_prompt: Label = $InteractPrompt
@onready var interaction_panel: Panel = $InteractionPanel
@onready var interaction_list: ItemList = $InteractionPanel/PanelMargin/InteractionVBox/InteractionList
@onready var interaction_hint: Label = $InteractionPanel/PanelMargin/InteractionVBox/InteractionHint
@onready var stamina_container: Control = $StaminaContainer
@onready var stamina_bar: ProgressBar = $StaminaContainer/StaminaPanel/StaminaBar
@onready var speed_label: Label = $SpeedContainer/SpeedPanel/SpeedMargin/SpeedLabel

var in_transition: bool = false
var transition_tween: Tween
var pause_tween: Tween
var package_open_tween: Tween
var offer_menu_tween: Tween
var interaction_panel_tween: Tween
var interact_prompt_tween: Tween
var status_tween: Tween
var package_pause_active: bool = false
var job_offer_pause_active: bool = false
var interact_prompt_owner_id: int = 0
var stamina_source: Node
var speed_source: Node
var package_flash_timer: SceneTreeTimer
var package_fade_tween: Tween
var interaction_entries: Array[Node] = []
var interaction_selected_index: int = -1
var inn_checkin_ratio: float = -1.0
var status_pinned: bool = false
var status_hold_active: bool = false
var last_money: int = 0
var inn_open_announced: bool = false

const DAY_START_MINUTES = 6 * 60
const DAY_END_MINUTES = 24 * 60
const INN_CHECKIN_FALLBACK = 0.75

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	package_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	job_offer_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	PlayerData.inventory_changed.connect(_on_inventory_changed)
	TimeSystem.time_changed.connect(_on_time_changed)
	TimeSystem.new_morning.connect(_on_new_morning)
	TimeSystem.mugged.connect(_on_mugged)
	UIEvents.notify.connect(show_message)
	UIEvents.sleep_sequence_requested.connect(_on_sleep_sequence_requested)
	UIEvents.interact_prompt_changed.connect(_on_interact_prompt_changed)
	UIEvents.interaction_registered.connect(_on_interaction_registered)
	UIEvents.interaction_unregistered.connect(_on_interaction_unregistered)
	UIEvents.package_menu_requested.connect(_on_package_menu_requested)
	UIEvents.job_offer_menu_requested.connect(_on_job_offer_menu_requested)
	GameState.mode_changed.connect(_on_mode_changed)
	Jobs.job_started.connect(_on_job_started)
	Jobs.job_completed.connect(_on_job_completed)
	resume_button.pressed.connect(_on_resume_pressed)
	save_button.pressed.connect(_on_save_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	interaction_list.item_selected.connect(_on_interaction_item_selected)
	last_money = PlayerData.get_money()
	_update_money_label()
	_on_inventory_changed()
	_on_time_changed(TimeSystem.day_time)
	pause_menu.visible = false
	package_menu.visible = false
	job_offer_menu.visible = false
	status_row.visible = false
	status_row.modulate = Color(1, 1, 1, 0)
	fade_rect.visible = false
	fade_rect.color = Color(0, 0, 0, 0)
	transition_panel.visible = false
	transition_panel.modulate = Color(1, 1, 1, 0)
	transition_label.modulate = Color(1, 1, 1, 1)
	interact_prompt.visible = false
	interact_prompt.modulate = Color(1, 1, 1, 0)
	interaction_panel.visible = false
	interaction_panel.modulate = Color(1, 1, 1, 0)
	stamina_container.visible = false
	_bind_player_stamina()
	_bind_player_speed()
	_refresh_inn_checkin_ratio()
	get_tree().node_added.connect(_on_node_added)

func _process(_delta: float) -> void:
	_update_speed_label()

func _update_money_label() -> void:
	var current_money = PlayerData.get_money()
	money_label.text = "$" + str(current_money)
	if current_money != last_money:
		last_money = current_money
		_show_status_temporarily()

func _on_inventory_changed() -> void:
	_update_money_label()
	var count = PlayerData.get_item_count(Jobs.DELIVERY_ITEM_ID)
	if count <= 0:
		carrying_label.text = "NONE"
		return
	var item = PlayerData.get_item_by_id(Jobs.DELIVERY_ITEM_ID)
	var name = item.display_name if item != null and item.display_name != "" else "Parcel"
	var display_name = name.to_upper()
	if count > 1:
		display_name = "%s x%d" % [display_name, count]
	carrying_label.text = display_name

func _on_time_changed(day_time: float) -> void:
	time_label.text = "%s  Curfew %s  Inn %s" % [
		_format_time(day_time),
		_format_curfew_time(),
		_format_inn_checkin_time()
	]
	time_label.tooltip_text = "Day time, curfew, and inn check-in"
	if not inn_open_announced and _is_inn_open(day_time):
		inn_open_announced = true
		_show_status_temporarily()

func _format_time(day_time: float) -> String:
	var total_minutes = int(round(lerp(DAY_START_MINUTES, DAY_END_MINUTES, day_time)))
	total_minutes = clamp(total_minutes, DAY_START_MINUTES, DAY_END_MINUTES)
	var hours = total_minutes / 60
	var minutes = total_minutes % 60
	return "%s:%s" % [str(hours).pad_zeros(2), str(minutes).pad_zeros(2)]

func _format_curfew_time() -> String:
	var total_minutes = int(round(lerp(
		DAY_START_MINUTES,
		DAY_END_MINUTES,
		TimeSystem.curfew_ratio
	)))
	total_minutes = clamp(total_minutes, DAY_START_MINUTES, DAY_END_MINUTES)
	var hours = total_minutes / 60
	var minutes = total_minutes % 60
	return "%s:%s" % [str(hours).pad_zeros(2), str(minutes).pad_zeros(2)]

func _format_inn_checkin_time() -> String:
	var ratio = inn_checkin_ratio if inn_checkin_ratio >= 0.0 else INN_CHECKIN_FALLBACK
	return _format_time(ratio)

func _on_new_morning() -> void:
	if in_transition:
		return
	inn_open_announced = false
	show_message("Morning. New deliveries available.")

func _on_job_started(_dropoff: Node3D) -> void:
	_flash_package_menu(2.25)

func _on_job_completed(job: JobRecord) -> void:
	_play_completion_sfx(job)
	_flash_package_menu(2.0, job)
	show_message("Delivery complete!")
	SaveSystem.save_autojob()

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
	tween.tween_property(label, "position", Vector2(0,0), notification_fade_in)
	tween.tween_property(label, "modulate:a", 1.0, notification_fade_in)
	tween.set_parallel(false)
	
	var hold_time = duration if duration > 0.0 else notification_hold
	tween.tween_interval(hold_time)
	
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 0.0, notification_fade_out)
	tween.set_parallel(false)
	
	tween.tween_callback(label.queue_free)

func _on_mode_changed(mode: GameState.Mode) -> void:
	var should_show_pause = (
		mode == GameState.Mode.PAUSED
		and not in_transition
		and not package_pause_active
		and not job_offer_pause_active
	)
	_set_pause_menu_visible(should_show_pause)
	if mode == GameState.Mode.PLAYING and package_pause_active:
		package_pause_active = false
		_hide_package_menu(journal_close_duration)
	if mode == GameState.Mode.PLAYING and job_offer_pause_active:
		job_offer_pause_active = false
		_hide_job_offer_menu(offer_menu_close_duration)
	if mode != GameState.Mode.PLAYING and not package_pause_active:
		_hide_package_menu(0.0)
	if mode != GameState.Mode.PLAYING and not job_offer_pause_active:
		_hide_job_offer_menu(0.0)
	if mode != GameState.Mode.PAUSED and package_pause_active:
		package_pause_active = false
	if mode != GameState.Mode.PAUSED and job_offer_pause_active:
		job_offer_pause_active = false
	_update_interaction_visibility()

func _on_resume_pressed() -> void:
	GameState.set_mode(GameState.Mode.PLAYING)

func _on_menu_pressed() -> void:
	GameState.set_mode(GameState.Mode.MENU)
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _on_save_pressed() -> void:
	var slot_name = SaveSystem.save_new_slot()
	if slot_name != "":
		show_message("Saved %s" % slot_name)

func _on_mugged() -> void:
	_play_transition("CURFEW VIOLATED\nSTOLEN: ALL CASH", true)

func _on_sleep_sequence_requested(message: String) -> void:
	_play_transition(message, false)

func _play_transition(message: String, is_mugged: bool) -> void:
	in_transition = true
	fade_rect.visible = true
	fade_rect.color = Color(0, 0, 0, 0)
	transition_panel.visible = true
	transition_label.text = message
	transition_label.modulate = Color(1, 1, 1, 1)
	transition_label.add_theme_color_override(
		"font_color",
		alert_text_color if is_mugged else rest_text_color
	)
	transition_panel.modulate = Color(1, 1, 1, 0)
	if transition_tween:
		transition_tween.kill()
	var target_mode = GameState.Mode.SLEEPING
	if is_mugged:
		target_mode = GameState.Mode.MUGGED
	else:
		SaveSystem.save_autosleep()
	GameState.set_mode(target_mode)
	transition_tween = create_tween()
	transition_tween.tween_property(fade_rect, "color:a", 1.0, transition_fade_duration)
	transition_tween.tween_property(transition_panel, "modulate:a", 1.0, 0.25)
	transition_tween.tween_callback(func() -> void:
		if is_mugged:
			PlayerData.reset_money()
			Jobs.clear_active_job()
		TimeSystem.start_new_day()
	)
	transition_tween.tween_interval(transition_hold)
	transition_tween.tween_property(fade_rect, "color:a", 0.0, transition_fade_duration)
	transition_tween.tween_property(transition_panel, "modulate:a", 0.0, 0.2)
	transition_tween.tween_callback(_finish_transition)

func _finish_transition() -> void:
	fade_rect.visible = false
	transition_panel.visible = false
	in_transition = false
	GameState.set_mode(GameState.Mode.PLAYING)

func _input(event: InputEvent) -> void:
	var toggle_pressed = event.is_action_pressed("toggle_package_menu")
	if not toggle_pressed and event is InputEventKey:
		toggle_pressed = event.pressed and event.keycode == Key.KEY_TAB
	if toggle_pressed:
		_set_package_menu_visible(not package_menu.visible)
		var viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		return
	if interaction_entries.is_empty():
		return
	if in_transition or package_pause_active or job_offer_pause_active or not GameState.is_playing():
		return
	if interaction_selected_index < 0:
		interaction_selected_index = 0
		if interaction_list.get_item_count() > 0:
			interaction_list.select(0)
	var action = _get_selected_interaction_action()
	if action != "" and event.is_action_pressed(action):
		await _trigger_selected_interaction()
		var viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		return

func _on_interact_prompt_changed(visible: bool, action: String, owner_id: int) -> void:
	if not interaction_entries.is_empty():
		return
	if visible:
		interact_prompt_owner_id = owner_id
		interact_prompt.text = "Press %s to use" % _get_action_label(action)
		_set_interact_prompt_visible(true)
		return
	if owner_id != 0 and owner_id != interact_prompt_owner_id:
		return
	interact_prompt_owner_id = 0
	_set_interact_prompt_visible(false)

func _get_action_label(action: String) -> String:
	var events = InputMap.action_get_events(action)
	for event in events:
		var text = event.as_text()
		if text != "":
			return text
	return action

func _unhandled_input(event: InputEvent) -> void:
	if interaction_entries.is_empty():
		return
	if in_transition or package_pause_active or job_offer_pause_active or not GameState.is_playing():
		return
	var wheel_event = event as InputEventMouseButton
	if wheel_event and wheel_event.pressed:
		if wheel_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select_interaction_index(interaction_selected_index - 1)
			var viewport = get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()
			return
		if wheel_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select_interaction_index(interaction_selected_index + 1)
			var viewport = get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()
			return
	var key_event = event as InputEventKey
	if key_event and key_event.pressed and not key_event.echo:
		if key_event.keycode == Key.KEY_UP:
			_select_interaction_index(interaction_selected_index - 1)
			var viewport = get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()
			return
		if key_event.keycode == Key.KEY_DOWN:
			_select_interaction_index(interaction_selected_index + 1)
			var viewport = get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()
			return
		if key_event.keycode == Key.KEY_PAGEUP:
			_select_interaction_index(interaction_selected_index - 3)
			var viewport = get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()
			return
		if key_event.keycode == Key.KEY_PAGEDOWN:
			_select_interaction_index(interaction_selected_index + 3)
			var viewport = get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()
			return
	var action = _get_selected_interaction_action()
	if action != "" and event.is_action_pressed(action):
		await _trigger_selected_interaction()
		var viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()

func _bind_player_stamina() -> void:
	if stamina_source != null and is_instance_valid(stamina_source):
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	stamina_source = player
	if player.has_signal("stamina_changed"):
		player.stamina_changed.connect(_on_stamina_changed)
		if player.has_method("get_stamina_current") and player.has_method("get_stamina_max"):
			_on_stamina_changed(
				player.get_stamina_current(),
				player.get_stamina_max(),
				player.get_stamina_percent()
			)

func _on_node_added(node: Node) -> void:
	if stamina_source == null and node.is_in_group("player"):
		_bind_player_stamina()
	if speed_source == null and node.is_in_group("player"):
		_bind_player_speed()
	if inn_checkin_ratio < 0.0 and node.is_in_group("inns"):
		_refresh_inn_checkin_ratio()

func _refresh_inn_checkin_ratio() -> void:
	var inn = get_tree().get_first_node_in_group("inns")
	if inn == null:
		return
	var threshold = inn.get("sleep_threshold")
	if typeof(threshold) == TYPE_FLOAT:
		inn_checkin_ratio = clamp(float(threshold), 0.0, 1.0)

func _bind_player_speed() -> void:
	if speed_source != null and is_instance_valid(speed_source):
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	speed_source = player
	_update_speed_label()

func _on_stamina_changed(current: float, max_value: float, percent: float) -> void:
	stamina_bar.max_value = max_value
	stamina_bar.value = current
	stamina_container.visible = current < max_value - 0.01

func _update_speed_label() -> void:
	if speed_source == null or not is_instance_valid(speed_source):
		speed_label.text = "Speed 0 m/min"
		return
	var body := speed_source as CharacterBody3D
	if body == null:
		speed_label.text = "Speed 0 m/min"
		return
	var horizontal_speed = Vector2(body.velocity.x, body.velocity.z).length()
	var meters_per_minute = horizontal_speed * 60.0
	speed_label.text = "Speed %s m/min" % str(int(round(meters_per_minute)))

func _flash_package_menu(duration: float, completed_job: JobRecord = null) -> void:
	if in_transition or package_pause_active:
		return
	if package_flash_timer:
		package_flash_timer.timeout.disconnect(_on_package_flash_timeout)
		package_flash_timer = null
	if package_fade_tween:
		package_fade_tween.kill()
		package_fade_tween = null
	_show_package_menu(journal_open_duration)
	if completed_job != null and package_menu.has_method("show_completed_job"):
		package_menu.call("show_completed_job", completed_job)
	elif package_menu.has_method("clear_override"):
		package_menu.call("clear_override")
	package_flash_timer = get_tree().create_timer(duration)
	package_flash_timer.timeout.connect(_on_package_flash_timeout)

func _on_package_flash_timeout() -> void:
	package_flash_timer = null
	if package_pause_active or in_transition:
		return
	package_fade_tween = create_tween()
	package_fade_tween.tween_property(
		package_menu,
		"modulate:a",
		0.0,
		journal_flash_fade
	).set_trans(Tween.TRANS_SINE)
	package_fade_tween.tween_callback(_on_package_fade_finished)

func _on_package_fade_finished() -> void:
	if package_pause_active or in_transition:
		return
	package_menu.visible = false
	package_menu.modulate = Color(1, 1, 1, 1)
	if package_menu.has_method("clear_override"):
		package_menu.call("clear_override")
	package_fade_tween = null

func _on_package_menu_requested(visible: bool) -> void:
	_set_package_menu_visible(visible)

func _set_package_menu_visible(visible: bool) -> void:
	if in_transition:
		return
	if visible and not GameState.is_playing() and not package_pause_active:
		return
	if package_flash_timer:
		package_flash_timer.timeout.disconnect(_on_package_flash_timeout)
		package_flash_timer = null
	if package_fade_tween:
		package_fade_tween.kill()
		package_fade_tween = null
	if visible and job_offer_pause_active:
		job_offer_pause_active = false
		_hide_job_offer_menu(0.0)
	package_pause_active = visible
	status_pinned = visible
	if visible:
		_set_status_visible(true)
	else:
		_hide_status_if_needed()
	if visible:
		_show_package_menu(journal_open_duration)
	else:
		_hide_package_menu(journal_close_duration)
	if package_menu.has_method("clear_override"):
		package_menu.call("clear_override")
	if visible and package_menu.has_method("focus_default"):
		package_menu.call("focus_default")
	if visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	GameState.set_mode(GameState.Mode.PAUSED if visible else GameState.Mode.PLAYING)

func _on_job_offer_menu_requested(visible: bool) -> void:
	_set_job_offer_menu_visible(visible)

func _set_job_offer_menu_visible(visible: bool) -> void:
	if in_transition:
		return
	if visible and not GameState.is_playing() and not job_offer_pause_active:
		return
	if visible and package_pause_active:
		package_pause_active = false
		_hide_package_menu(0.0)
	job_offer_pause_active = visible
	if visible:
		_show_job_offer_menu(offer_menu_open_duration)
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		_hide_job_offer_menu(offer_menu_close_duration)
	GameState.set_mode(GameState.Mode.PAUSED if visible else GameState.Mode.PLAYING)

func _play_completion_sfx(job: JobRecord) -> void:
	if completion_audio == null or job == null:
		return
	if job.completion_sfx == null:
		return
	completion_audio.stream = job.completion_sfx
	completion_audio.play()

func _on_interaction_registered(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if interaction_entries.has(node):
		return
	interaction_entries.append(node)
	_refresh_interaction_menu()

func _on_interaction_unregistered(node: Node) -> void:
	if interaction_entries.has(node):
		interaction_entries.erase(node)
		_refresh_interaction_menu()

func _on_interaction_item_selected(index: int) -> void:
	interaction_selected_index = index
	_update_interaction_hint()

func _refresh_interaction_menu() -> void:
	_prune_invalid_interactions()
	var previous: Node = _get_selected_interaction()
	interaction_list.clear()
	for node in interaction_entries:
		interaction_list.add_item(_get_interaction_label(node))
	if previous != null:
		var new_index = interaction_entries.find(previous)
		if new_index != -1:
			interaction_selected_index = new_index
	if interaction_entries.is_empty():
		interaction_selected_index = -1
	_update_interaction_visibility()
	if interaction_entries.is_empty():
		return
	if interaction_selected_index < 0:
		interaction_selected_index = 0
	interaction_selected_index = clamp(interaction_selected_index, 0, interaction_entries.size() - 1)
	interaction_list.select(interaction_selected_index)
	if interaction_list.has_method("ensure_current_is_visible"):
		interaction_list.ensure_current_is_visible()
	_update_interaction_hint()

func _update_interaction_visibility() -> void:
	var should_show = GameState.is_playing()
	should_show = should_show and not package_pause_active
	should_show = should_show and not job_offer_pause_active
	should_show = should_show and not in_transition
	should_show = should_show and not interaction_entries.is_empty()
	_set_interaction_panel_visible(should_show)
	if should_show:
		_set_interact_prompt_visible(false)

func _update_interaction_hint() -> void:
	var action = _get_selected_interaction_action()
	if action == "":
		interaction_hint.text = "Press key to interact"
		return
	interaction_hint.text = "Press %s to interact" % _get_action_label(action)

func _select_interaction_index(index: int) -> void:
	if interaction_entries.is_empty():
		return
	var size = interaction_entries.size()
	var clamped = index
	if clamped < 0:
		clamped = size - 1
	elif clamped >= size:
		clamped = 0
	interaction_selected_index = clamped
	interaction_list.select(interaction_selected_index)
	if interaction_list.has_method("ensure_current_is_visible"):
		interaction_list.ensure_current_is_visible()
	_update_interaction_hint()

func _get_selected_interaction() -> Node:
	if interaction_selected_index < 0 or interaction_selected_index >= interaction_entries.size():
		return null
	var node = interaction_entries[interaction_selected_index]
	if node == null or not is_instance_valid(node):
		return null
	return node

func _get_selected_interaction_action() -> String:
	var node = _get_selected_interaction()
	return _get_interaction_action(node)

func _get_interaction_label(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return "Interact"
	if node.has_method("get_interaction_label"):
		return node.call("get_interaction_label")
	return node.name

func _get_interaction_action(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return ""
	if node.has_method("get_interaction_action"):
		return node.call("get_interaction_action")
	return "interact"

func _trigger_selected_interaction() -> void:
	var node = _get_selected_interaction()
	if node == null:
		return
	if node.has_method("can_interact"):
		var can_interact: bool = node.call("can_interact")
		if not can_interact:
			return
	if node.has_method("perform_interaction"):
		await node.perform_interaction()

func _prune_invalid_interactions() -> void:
	for i in range(interaction_entries.size() - 1, -1, -1):
		var node = interaction_entries[i]
		if node == null or not is_instance_valid(node):
			interaction_entries.remove_at(i)

func _set_pause_menu_visible(visible: bool) -> void:
	if pause_tween:
		pause_tween.kill()
	if visible:
		pause_menu.visible = true
		pause_menu.modulate = Color(1, 1, 1, 0)
		pause_tween = create_tween()
		pause_tween.tween_property(
			pause_menu,
			"modulate:a",
			1.0,
			pause_fade_duration
		).set_trans(Tween.TRANS_SINE)
		return
	if not pause_menu.visible:
		return
	pause_tween = create_tween()
	pause_tween.tween_property(
		pause_menu,
		"modulate:a",
		0.0,
		pause_fade_duration
	).set_trans(Tween.TRANS_SINE)
	pause_tween.tween_callback(func() -> void:
		pause_menu.visible = false
		pause_menu.modulate = Color(1, 1, 1, 1)
	)

func _show_package_menu(duration: float) -> void:
	if package_open_tween:
		package_open_tween.kill()
	package_menu.visible = true
	package_menu.modulate = Color(1, 1, 1, 0)
	package_open_tween = create_tween()
	package_open_tween.tween_property(
		package_menu,
		"modulate:a",
		1.0,
		duration
	).set_trans(Tween.TRANS_SINE)

func _hide_package_menu(duration: float) -> void:
	if package_open_tween:
		package_open_tween.kill()
	if package_fade_tween:
		package_fade_tween.kill()
		package_fade_tween = null
	if duration <= 0.0:
		package_menu.visible = false
		package_menu.modulate = Color(1, 1, 1, 1)
		if package_menu.has_method("clear_override"):
			package_menu.call("clear_override")
		return
	package_open_tween = create_tween()
	package_open_tween.tween_property(
		package_menu,
		"modulate:a",
		0.0,
		duration
	).set_trans(Tween.TRANS_SINE)
	package_open_tween.tween_callback(func() -> void:
		package_menu.visible = false
		package_menu.modulate = Color(1, 1, 1, 1)
		if package_menu.has_method("clear_override"):
			package_menu.call("clear_override")
	)

func _show_job_offer_menu(duration: float) -> void:
	if offer_menu_tween:
		offer_menu_tween.kill()
	job_offer_menu.visible = true
	job_offer_menu.modulate = Color(1, 1, 1, 0)
	if job_offer_menu.has_method("focus_default"):
		job_offer_menu.call("focus_default")
	offer_menu_tween = create_tween()
	offer_menu_tween.tween_property(
		job_offer_menu,
		"modulate:a",
		1.0,
		duration
	).set_trans(Tween.TRANS_SINE)

func _hide_job_offer_menu(duration: float) -> void:
	if offer_menu_tween:
		offer_menu_tween.kill()
	if duration <= 0.0:
		job_offer_menu.visible = false
		job_offer_menu.modulate = Color(1, 1, 1, 1)
		return
	offer_menu_tween = create_tween()
	offer_menu_tween.tween_property(
		job_offer_menu,
		"modulate:a",
		0.0,
		duration
	).set_trans(Tween.TRANS_SINE)
	offer_menu_tween.tween_callback(func() -> void:
		job_offer_menu.visible = false
		job_offer_menu.modulate = Color(1, 1, 1, 1)
	)

func _set_interaction_panel_visible(visible: bool) -> void:
	if interaction_panel_tween:
		interaction_panel_tween.kill()
	if visible:
		interaction_panel.visible = true
		interaction_panel.modulate = Color(1, 1, 1, 0)
		interaction_panel_tween = create_tween()
		interaction_panel_tween.tween_property(
			interaction_panel,
			"modulate:a",
			1.0,
			interaction_fade_duration
		).set_trans(Tween.TRANS_SINE)
		return
	if not interaction_panel.visible:
		return
	interaction_panel_tween = create_tween()
	interaction_panel_tween.tween_property(
		interaction_panel,
		"modulate:a",
		0.0,
		interaction_fade_duration
	).set_trans(Tween.TRANS_SINE)
	interaction_panel_tween.tween_callback(func() -> void:
		interaction_panel.visible = false
		interaction_panel.modulate = Color(1, 1, 1, 1)
	)

func _set_interact_prompt_visible(visible: bool) -> void:
	if interact_prompt_tween:
		interact_prompt_tween.kill()
	if visible:
		interact_prompt.visible = true
		interact_prompt.modulate = Color(1, 1, 1, 0)
		interact_prompt_tween = create_tween()
		interact_prompt_tween.tween_property(
			interact_prompt,
			"modulate:a",
			1.0,
			interaction_fade_duration
		).set_trans(Tween.TRANS_SINE)
		return
	if not interact_prompt.visible:
		return
	interact_prompt_tween = create_tween()
	interact_prompt_tween.tween_property(
		interact_prompt,
		"modulate:a",
		0.0,
		interaction_fade_duration
	).set_trans(Tween.TRANS_SINE)
	interact_prompt_tween.tween_callback(func() -> void:
		interact_prompt.visible = false
		interact_prompt.modulate = Color(1, 1, 1, 1)
	)

func _set_status_visible(visible: bool) -> void:
	if status_tween:
		status_tween.kill()
	if visible:
		status_row.visible = true
		status_row.modulate = Color(1, 1, 1, 0)
		status_tween = create_tween()
		status_tween.tween_property(
			status_row,
			"modulate:a",
			1.0,
			status_fade_in
		).set_trans(Tween.TRANS_SINE)
		return
	if not status_row.visible:
		return
	status_tween = create_tween()
	status_tween.tween_property(
		status_row,
		"modulate:a",
		0.0,
		status_fade_out
	).set_trans(Tween.TRANS_SINE)
	status_tween.tween_callback(func() -> void:
		status_row.visible = false
		status_row.modulate = Color(1, 1, 1, 1)
	)

func _show_status_temporarily() -> void:
	if status_pinned:
		_set_status_visible(true)
		return
	status_hold_active = true
	_set_status_visible(true)
	if status_tween:
		status_tween.tween_interval(status_hold)
		status_tween.tween_callback(func() -> void:
			status_hold_active = false
			_hide_status_if_needed()
		)

func _hide_status_if_needed() -> void:
	if status_pinned or status_hold_active:
		return
	_set_status_visible(false)

func _is_inn_open(day_time: float) -> bool:
	var ratio = inn_checkin_ratio if inn_checkin_ratio >= 0.0 else INN_CHECKIN_FALLBACK
	return day_time >= ratio
