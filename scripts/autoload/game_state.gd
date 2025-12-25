extends Node

signal mode_changed(mode: Mode)

enum Mode { MENU, PLAYING, PAUSED, SLEEPING, MUGGED }

var mode: Mode = Mode.MENU
var last_mode: Mode = Mode.MENU

func _ready() -> void:
	_ensure_input_actions()

func set_mode(next_mode: Mode) -> void:
	if mode == next_mode:
		return
	last_mode = mode
	mode = next_mode
	_apply_pause_state()
	mode_changed.emit(mode)

func toggle_pause() -> void:
	if mode == Mode.PAUSED:
		set_mode(Mode.PLAYING)
	elif mode == Mode.PLAYING:
		set_mode(Mode.PAUSED)

func is_playing() -> bool:
	return mode == Mode.PLAYING

func _apply_pause_state() -> void:
	get_tree().paused = mode == Mode.PAUSED

func to_dict() -> Dictionary:
	return {
		"mode": int(mode),
		"last_mode": int(last_mode),
		"tree_paused": get_tree().paused
	}

func from_dict(data: Dictionary) -> void:
	var mode_value = int(data.get("mode", Mode.MENU))
	var last_value = int(data.get("last_mode", mode_value))
	last_mode = last_value
	mode = mode_value
	_apply_pause_state()
	if data.has("tree_paused"):
		get_tree().paused = bool(data.get("tree_paused"))
	mode_changed.emit(mode)

func _ensure_input_actions() -> void:
	#_add_action_if_missing("move_forward", [Key.W, Key.UP])
	#_add_action_if_missing("move_backward", [Key.S, Key.DOWN])
	#_add_action_if_missing("move_left", [Key.A, Key.LEFT])
	#_add_action_if_missing("move_right", [Key.D, Key.RIGHT])
	#_add_action_if_missing("jump", [Key.SPACE])
	#_add_action_if_missing("sprint", [Key.SHIFT])
	#_add_action_if_missing("pause", [Key.ESCAPE])
	#_add_action_if_missing("interact", [Key.E])
	return

func _add_action_if_missing(name: String, keys: Array) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name)
	for key in keys:
		var event = InputEventKey.new()
		event.keycode = key
		if not _event_exists(name, event):
			InputMap.action_add_event(name, event)

func _event_exists(action: String, new_event: InputEventKey) -> bool:
	for event in InputMap.action_get_events(action):
		var key_event = event as InputEventKey
		if key_event and key_event.keycode == new_event.keycode:
			return true
	return false
