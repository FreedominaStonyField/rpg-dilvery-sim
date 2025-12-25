extends Node

signal save_completed(path: String)
signal load_completed(path: String)
signal save_failed(path: String, reason: String)
signal load_failed(path: String, reason: String)

const SAVE_DIR = "user://saves"
const WORLD_SCENE = "res://scenes/world/World.tscn"
const QUICK_FILE = "quick.json"
const AUTOSLEEP_FILE = "autosleep.json"
const AUTOJOB_FILE = "autojob.json"
const SLOT_PREFIX = "slot_"
const SLOT_EXTENSION = ".json"

var playtime_seconds: float = 0.0
var _loading: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	_ensure_save_dir()

func _process(delta: float) -> void:
	if GameState.is_playing() and not get_tree().paused:
		playtime_seconds += delta

func _unhandled_input(event: InputEvent) -> void:
	var key_event = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == Key.KEY_F5:
		if _can_quick_action():
			save_quick()
		return
	if key_event.keycode == Key.KEY_F9:
		if _can_quick_action():
			load_quick()

func save_quick() -> void:
	_save_to_file(QUICK_FILE, "quick")

func load_quick() -> void:
	_load_from_file(QUICK_FILE)

func save_autosleep() -> void:
	if not _is_in_world_scene():
		return
	_save_to_file(AUTOSLEEP_FILE, "autosleep")

func save_autojob() -> void:
	if not _is_in_world_scene():
		return
	_save_to_file(AUTOJOB_FILE, "autojob")

func save_new_slot() -> String:
	if not _is_in_world_scene():
		return ""
	var slot_name = _next_slot_name()
	_save_to_file(slot_name, slot_name)
	return slot_name

func load_slot(slot_name: String) -> void:
	_load_from_file(slot_name)

func list_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	var dir = DirAccess.open(SAVE_DIR)
	if dir == null:
		return slots
	for file_name in dir.get_files():
		if not _is_slot_file(file_name):
			continue
		var meta = _read_save_meta(file_name)
		meta["file_name"] = file_name
		slots.append(meta)
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("unix_time", 0)) > int(b.get("unix_time", 0))
	)
	return slots

func _can_quick_action() -> bool:
	return GameState.is_playing() and not get_tree().paused and _is_in_world_scene()

func _is_in_world_scene() -> bool:
	var current = get_tree().current_scene
	if current == null:
		return false
	return current.scene_file_path == WORLD_SCENE

func _ensure_save_dir() -> void:
	if DirAccess.dir_exists_absolute(SAVE_DIR):
		return
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func _save_to_file(file_name: String, tag: String) -> void:
	if _loading:
		return
	var payload = _build_save_payload(tag)
	var path = _build_save_path(file_name)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		save_failed.emit(path, "Unable to open file for writing.")
		return
	var json = JSON.stringify(payload, "\t")
	file.store_string(json)
	file.flush()
	file.close()
	save_completed.emit(path)

func _load_from_file(file_name: String) -> void:
	if _loading:
		return
	var path = _build_save_path(file_name)
	if not FileAccess.file_exists(path):
		load_failed.emit(path, "Save file not found.")
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		load_failed.emit(path, "Unable to open file.")
		return
	var content = file.get_as_text()
	file.close()
	var result = JSON.parse_string(content)
	if result == null or typeof(result) != TYPE_DICTIONARY:
		load_failed.emit(path, "Invalid save data.")
		return
	await _apply_save_data(result as Dictionary, path)

func _build_save_payload(tag: String) -> Dictionary:
	var payload = {
		"version": 1,
		"meta": _build_meta(tag),
		"autoloads": _build_autoload_payload(),
		"player": _build_player_payload(),
		"world": {
			"saveables": _build_saveables_payload()
		}
	}
	return payload

func _build_meta(tag: String) -> Dictionary:
	var active_name = ""
	if Jobs.active_job != null:
		active_name = Jobs.active_job.display_name
	return {
		"tag": tag,
		"timestamp": Time.get_datetime_string_from_system(),
		"unix_time": Time.get_unix_time_from_system(),
		"playtime_seconds": playtime_seconds,
		"current_day": TimeSystem.current_day,
		"money": PlayerData.money,
		"active_job": active_name
	}

func _build_autoload_payload() -> Dictionary:
	return {
		"game_state": GameState.to_dict(),
		"time_system": TimeSystem.to_dict(),
		"jobs": Jobs.to_dict(),
		"player_data": PlayerData.to_dict()
	}

func _build_player_payload() -> Dictionary:
	var player = _find_player()
	if player == null:
		return {}
	if player.has_method("get_save_data"):
		return player.call("get_save_data")
	return {
		"position": _vec3_to_array(player.global_position),
		"rotation": _vec3_to_array(player.global_rotation),
		"velocity": _vec3_to_array(player.velocity)
	}

func _build_saveables_payload() -> Dictionary:
	var saveables = {}
	for node in get_tree().get_nodes_in_group("saveable"):
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_method("get_save_id") or not node.has_method("to_dict"):
			continue
		var save_id = str(node.call("get_save_id"))
		saveables[save_id] = node.call("to_dict")
	return saveables

func _apply_save_data(data: Dictionary, path: String) -> void:
	_loading = true
	get_tree().paused = true
	await _ensure_world_scene_loaded()
	var meta = data.get("meta", {})
	playtime_seconds = float(meta.get("playtime_seconds", playtime_seconds))
	var autoloads = data.get("autoloads", {})
	PlayerData.from_dict(autoloads.get("player_data", {}))
	TimeSystem.from_dict(autoloads.get("time_system", {}))
	Jobs.from_dict(autoloads.get("jobs", {}))
	var player_payload = data.get("player", {})
	_apply_player_payload(player_payload)
	var world = data.get("world", {})
	_apply_saveables(world.get("saveables", {}))
	GameState.from_dict(autoloads.get("game_state", {}))
	var game_state_data = autoloads.get("game_state", {})
	if typeof(game_state_data) == TYPE_DICTIONARY and game_state_data.has("tree_paused"):
		get_tree().paused = bool(game_state_data.get("tree_paused", false))
	else:
		get_tree().paused = GameState.mode == GameState.Mode.PAUSED
	_ensure_unpaused_after_load()
	_loading = false
	load_completed.emit(path)

func _ensure_world_scene_loaded() -> void:
	var current = get_tree().current_scene
	if current == null or current.scene_file_path != WORLD_SCENE:
		get_tree().change_scene_to_file(WORLD_SCENE)
	await get_tree().process_frame
	await get_tree().process_frame

func _apply_player_payload(payload: Dictionary) -> void:
	var player = _find_player()
	if player == null:
		return
	if player.has_method("apply_save_data"):
		player.call("apply_save_data", payload)
		return
	var pos_array = payload.get("position", [])
	var rot_array = payload.get("rotation", [])
	if pos_array.size() == 3 and rot_array.size() == 3:
		player.global_position = _array_to_vec3(pos_array)
		player.global_rotation = _array_to_vec3(rot_array)
	player.velocity = _array_to_vec3(payload.get("velocity", []))

func _apply_saveables(saveables: Dictionary) -> void:
	for node in get_tree().get_nodes_in_group("saveable"):
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_method("get_save_id") or not node.has_method("from_dict"):
			continue
		var save_id = str(node.call("get_save_id"))
		if not saveables.has(save_id):
			continue
		node.call("from_dict", saveables.get(save_id, {}))

func _find_player() -> CharacterBody3D:
	return get_tree().get_first_node_in_group("player") as CharacterBody3D

func _build_save_path(file_name: String) -> String:
	return SAVE_DIR.path_join(file_name)

func _next_slot_name() -> String:
	var dir = DirAccess.open(SAVE_DIR)
	if dir == null:
		return "%s0001%s" % [SLOT_PREFIX, SLOT_EXTENSION]
	var max_index = 0
	for file_name in dir.get_files():
		if not _is_slot_file(file_name):
			continue
		var index = _slot_index_from_name(file_name)
		if index > max_index:
			max_index = index
	return "%s%04d%s" % [SLOT_PREFIX, max_index + 1, SLOT_EXTENSION]

func _is_slot_file(file_name: String) -> bool:
	return file_name.begins_with(SLOT_PREFIX) and file_name.ends_with(SLOT_EXTENSION)

func _slot_index_from_name(file_name: String) -> int:
	var base = file_name.replace(SLOT_PREFIX, "").replace(SLOT_EXTENSION, "")
	return int(base) if base.is_valid_int() else 0

func _read_save_meta(file_name: String) -> Dictionary:
	var path = _build_save_path(file_name)
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var content = file.get_as_text()
	file.close()
	var result = JSON.parse_string(content)
	if result == null or typeof(result) != TYPE_DICTIONARY:
		return {}
	var meta = (result as Dictionary).get("meta", {})
	return meta if typeof(meta) == TYPE_DICTIONARY else {}

func _ensure_unpaused_after_load() -> void:
	if GameState.mode == GameState.Mode.PAUSED:
		GameState.set_mode(GameState.Mode.PLAYING)
	if get_tree().paused:
		get_tree().paused = false

func _vec3_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _array_to_vec3(value: Array) -> Vector3:
	if value.size() != 3:
		return Vector3.ZERO
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
