extends Control

@export var overlay_hotkey_action: StringName = "debug_toggle_anim_overlay"
@export var log_hotkey_action: StringName = "debug_toggle_anim_log"
@export var max_entries: int = 200

@onready var overlay_panel: Panel = $OverlayPanel
@onready var overlay_info: RichTextLabel = $OverlayPanel/OverlayVBox/OverlayInfo
@onready var log_panel: Panel = $LogPanel
@onready var log_list: ItemList = $LogPanel/LogVBox/LogList
@onready var filter_edit: LineEdit = $LogPanel/LogVBox/FilterRow/FilterEdit
@onready var type_option: OptionButton = $LogPanel/LogVBox/FilterRow/TypeOption
@onready var pause_button: Button = $LogPanel/LogVBox/ControlsRow/PauseButton
@onready var clear_button: Button = $LogPanel/LogVBox/ControlsRow/ClearButton
@onready var status_label: Label = $LogPanel/LogVBox/ControlsRow/StatusLabel

var player: CharacterBody3D
var animator_tree: AnimationTree
var debug_enabled: bool = OS.is_debug_build() or Engine.is_editor_hint()
var logging_paused: bool = false
var log_entries: Array = []
var last_velocity: Vector3 = Vector3.ZERO
var start_time: float = Time.get_ticks_msec() / 1000.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not debug_enabled:
		visible = false
		return
	_ensure_actions()
	_setup_ui()
	_connect_ui()
	_find_player()

func _process(delta: float) -> void:
	if not debug_enabled:
		return
	if player == null or not is_instance_valid(player):
		_find_player()
	if overlay_panel.visible and player != null:
		_update_overlay(delta)

func _unhandled_input(event: InputEvent) -> void:
	if not debug_enabled:
		return
	if event.is_action_pressed(overlay_hotkey_action):
		overlay_panel.visible = not overlay_panel.visible
	if event.is_action_pressed(log_hotkey_action):
		log_panel.visible = not log_panel.visible
		if log_panel.visible:
			_refresh_log_view()

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player != null:
		last_velocity = player.velocity
		animator_tree = player.get_node_or_null("AnimationTree") as AnimationTree
		if animator_tree != null and animator_tree.has_signal("animation_debug_event"):
			if animator_tree.animation_debug_event.is_connected(_on_animation_event) == false:
				animator_tree.animation_debug_event.connect(_on_animation_event)

func _update_overlay(delta: float) -> void:
	var velocity := player.velocity
	var accel :Vector3 = (velocity - last_velocity) / max(delta, 0.0001)
	last_velocity = velocity
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	var is_falling := not player.is_on_floor() and velocity.y < -0.1
	var movement_mode := _movement_mode(velocity, planar_speed, is_falling)
	var anim_state := {}
	if animator_tree != null and animator_tree.has_method("get_debug_state"):
		anim_state = animator_tree.get_debug_state()
	var blends := []
	if animator_tree != null and animator_tree.has_method("get_blend_snapshot"):
		blends = animator_tree.get_blend_snapshot()
	var blend_lines: Array[String] = []
	for blend in blends:
		var state_name := str(blend.get("state", ""))
		var anim_name := str(blend.get("animation", ""))
		var weight := float(blend.get("weight", 0.0))
		blend_lines.append(" - %s (%.2f) [%s]" % [state_name, weight, anim_name])
	if blend_lines.is_empty():
		blend_lines.append(" - None")
	var state_name := str(anim_state.get("state", ""))
	var state_time := float(anim_state.get("state_time", 0.0))
	var anim_name := str(anim_state.get("animation", ""))
	var land_timer := float(anim_state.get("land_timer", 0.0))
	var jump_timer := float(anim_state.get("jump_start_timer", 0.0))
	var overlay_text := "Movement Mode: %s | Game Mode: %s\n"
	overlay_text += "Grounded: %s | IsFalling: %s | Jump Count: n/a\n"
	overlay_text += "Velocity: (%.2f, %.2f, %.2f) | Accel: (%.2f, %.2f, %.2f)\n"
	overlay_text += "Planar Speed: %.2f | Vertical: %.2f\n"
	overlay_text += "State: %s (%.2fs) anim=%s\n"
	overlay_text += "Land Timer: %.2f | JumpStart Timer: %.2f\n"
	overlay_text += "Montages: None\n"
	overlay_text += "Blend Snapshot:\n%s"
	overlay_info.text = overlay_text % [
		movement_mode, _mode_name(GameState.mode),
		str(player.is_on_floor()), str(is_falling),
		velocity.x, velocity.y, velocity.z,
		accel.x, accel.y, accel.z,
		planar_speed, velocity.y,
		state_name, state_time, anim_name,
		land_timer, jump_timer,
		"\n".join(blend_lines)
	]

func _on_animation_event(event: Dictionary) -> void:
	if logging_paused:
		return
	log_entries.append(event.duplicate())
	if log_entries.size() > max_entries:
		log_entries.pop_front()
	if log_panel.visible:
		_refresh_log_view()
	_update_status_label()

func _refresh_log_view() -> void:
	log_list.clear()
	var filter_text := filter_edit.text.strip_edges().to_lower()
	var selected_index := type_option.get_selected()
	var selected_type := type_option.get_item_text(selected_index) if selected_index >= 0 else "All"
	for i in range(log_entries.size() - 1, -1, -1):
		var entry :Dictionary= log_entries[i]
		if not _passes_filters(entry, filter_text, selected_type):
			continue
		log_list.add_item(_format_entry(entry))
	_update_status_label()

func _passes_filters(entry: Dictionary, filter_text: String, type_filter: String) -> bool:
	var event_type := str(entry.get("event_type", ""))
	if type_filter != "All" and type_filter != event_type:
		return false
	if filter_text == "":
		return true
	var payload := _format_entry(entry).to_lower()
	return payload.find(filter_text) != -1

func _format_entry(entry: Dictionary) -> String:
	var timestamp := float(entry.get("timestamp", 0.0)) - start_time
	var frame := int(entry.get("frame", 0))
	var event_type := str(entry.get("event_type", ""))
	var anim := str(entry.get("animation", ""))
	var state := str(entry.get("state", ""))
	var source := str(entry.get("source", ""))
	var reason := str(entry.get("reason", ""))
	var velocity_y := float(entry.get("velocity_y", 0.0))
	var speed := float(entry.get("speed", 0.0))
	var on_floor :bool= entry.get("is_on_floor", false)
	var mode_value := int(entry.get("mode", GameState.mode))
	var entry_text := "[%6.2fs | f%s] %s | anim=%s | state=%s | src=%s\n"
	entry_text += " speed=%.2f | vy=%.2f | floor=%s | reason=%s | mode=%s"
	return entry_text % [
		timestamp, frame,
		event_type, anim, state, source,
		speed, velocity_y, str(on_floor), reason, _mode_name(mode_value)
	]

func _toggle_logging_pause() -> void:
	logging_paused = not logging_paused
	pause_button.text = "Resume Log" if logging_paused else "Pause Log"
	_update_status_label()

func _clear_log() -> void:
	log_entries.clear()
	log_list.clear()
	_update_status_label()

func _setup_ui() -> void:
	overlay_panel.visible = false
	log_panel.visible = false
	type_option.clear()
	type_option.add_item("All", 0)
	type_option.add_item("StateEntered", 1)
	type_option.add_item("AnimationStarted", 2)
	type_option.select(0)
	filter_edit.placeholder_text = "filter text or anim name"
	pause_button.text = "Pause Log"
	_update_status_label()

func _connect_ui() -> void:
	filter_edit.text_changed.connect(func(_t: String) -> void: _refresh_log_view())
	type_option.item_selected.connect(func(_i: int) -> void: _refresh_log_view())
	pause_button.pressed.connect(_toggle_logging_pause)
	clear_button.pressed.connect(_clear_log)

func _ensure_actions() -> void:
	_ensure_action(overlay_hotkey_action, Key.KEY_F9)
	_ensure_action(log_hotkey_action, Key.KEY_F10)

func _ensure_action(action: StringName, keycode: int) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.keycode = keycode
	InputMap.action_add_event(action, event)

func _movement_mode(velocity: Vector3, planar_speed: float, is_falling: bool) -> String:
	if is_falling:
		return "Falling"
	if not player.is_on_floor() and velocity.y > 0.1:
		return "Rising"
	if planar_speed < 0.1:
		return "Idle"
	if player.has_method("is_sprinting") and player.is_sprinting():
		return "Sprinting"
	return "Walking"

func _mode_name(mode_value: int) -> String:
	for key in GameState.Mode.keys():
		if GameState.Mode[key] == mode_value:
			return key
	return str(mode_value)

func _update_status_label() -> void:
	var mode_text := "Paused" if logging_paused else "Live"
	status_label.text = "%s | entries: %d" % [mode_text, log_entries.size()]
