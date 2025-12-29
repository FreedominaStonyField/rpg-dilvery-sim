extends Node
class_name UiSfxRouter

const META_BOUND = &"ui_sfx_bound"
const META_SKIP = &"ui_sfx_skip"
const META_OVERRIDE = &"ui_sfx_override"
const META_OVERRIDE_HOVER = &"ui_sfx_override_hover"
const META_OVERRIDE_PRESS = &"ui_sfx_override_press"
const META_OVERRIDE_TOGGLE = &"ui_sfx_override_toggle"
const META_OVERRIDE_SELECT = &"ui_sfx_override_select"
const META_OVERRIDE_CONFIRM = &"ui_sfx_override_confirm"

@export var profile: UiSfxProfile = preload("res://assets/audio/profiles/ui_sfx_default.tres")
@export var scan_root_path: NodePath = NodePath("..")
@export var connect_on_ready: bool = true
@export var allow_keyboard_focus_sfx: bool = true

@onready var hover_player: AudioStreamPlayer = $HoverPlayer
@onready var press_player: AudioStreamPlayer = $PressPlayer
@onready var toggle_player: AudioStreamPlayer = $TogglePlayer
@onready var select_player: AudioStreamPlayer = $SelectPlayer
@onready var confirm_player: AudioStreamPlayer = $ConfirmPlayer

var _scan_root: Node

func _ready() -> void:
	_scan_root = get_node_or_null(scan_root_path)
	if connect_on_ready and _scan_root != null:
		_scan_and_connect(_scan_root)
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if _scan_root == null:
		return
	if node is Control and _scan_root.is_ancestor_of(node):
		_register_control(node)

func _scan_and_connect(root: Node) -> void:
	for child in root.get_children():
		if child is Control:
			_register_control(child)
		if child.get_child_count() > 0:
			_scan_and_connect(child)

func _register_control(control: Control) -> void:
	if control.has_meta(META_BOUND) or control.has_meta(META_SKIP):
		return
	control.set_meta(META_BOUND, true)
	if _is_interactive(control):
		control.mouse_entered.connect(_on_hover.bind(control))
		if allow_keyboard_focus_sfx:
			control.focus_entered.connect(_on_focus.bind(control))

	if control is BaseButton:
		control.pressed.connect(_on_pressed.bind(control))
		if control is CheckBox or control is CheckButton:
			control.toggled.connect(_on_toggled.bind(control))

	if control is OptionButton:
		control.item_selected.connect(_on_selected.bind(control))

	if control is TabBar:
		control.tab_changed.connect(_on_selected.bind(control))

	if control is LineEdit:
		control.text_submitted.connect(_on_confirm.bind(control))

	if control is Range and control.has_signal("drag_ended"):
		control.drag_ended.connect(_on_drag_ended.bind(control))

	if control is ItemList:
		control.item_selected.connect(_on_selected.bind(control))

func _on_hover(control: Control) -> void:
	if _should_skip(control):
		return
	_play_event(control, hover_player, profile.hover_sounds, profile.hover_volume_db, "hover")

func _on_focus(control: Control) -> void:
	if _should_skip(control):
		return
	_play_event(control, select_player, profile.select_sounds, profile.select_volume_db, "select")

func _on_pressed(control: Control) -> void:
	if _should_skip(control):
		return
	_play_event(control, press_player, profile.click_sounds, profile.click_volume_db, "press")

func _on_toggled(_pressed: bool, control: Control) -> void:
	if _should_skip(control):
		return
	_play_event(control, toggle_player, profile.toggle_sounds, profile.toggle_volume_db, "toggle")

func _on_selected(_index: int, control: Control) -> void:
	if _should_skip(control):
		return
	_play_event(control, select_player, profile.select_sounds, profile.select_volume_db, "select")

func _on_confirm(_text: String, control: Control) -> void:
	if _should_skip(control):
		return
	_play_event(control, confirm_player, profile.confirm_sounds, profile.confirm_volume_db, "confirm")

func _on_drag_ended(value_changed: bool, control: Control) -> void:
	if _should_skip(control):
		return
	if not value_changed:
		return
	_play_event(control, press_player, profile.press_sounds, profile.press_volume_db, "press")

func _play_event(
	control: Control,
	player: AudioStreamPlayer,
	sounds: Array[AudioStream],
	volume_db: float,
	override_key: String
) -> void:
	var override_stream = _resolve_override(control, override_key)
	var stream = override_stream if override_stream != null else _pick_sound(sounds)
	if stream == null:
		return
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0
	player.play()

func _pick_sound(sounds: Array[AudioStream]) -> AudioStream:
	for sound in sounds:
		if sound != null:
			return sound
	return null

func _should_skip(control: Control) -> bool:
	if not is_instance_valid(control):
		return true
	if not _is_interactive(control):
		return true
	if control is BaseButton and control.disabled:
		return true
	return false

func _is_interactive(control: Control) -> bool:
	return (
		control is BaseButton
		or control is OptionButton
		or control is TabBar
		or control is LineEdit
		or control is Range
		or control is ItemList
	)

func _resolve_override(control: Control, event_key: String) -> AudioStream:
	var override = _resolve_meta_override(control, event_key)
	if override != null:
		return override
	var child_override = _resolve_child_override(control, event_key)
	if child_override != null:
		return child_override
	return null

func _resolve_meta_override(control: Control, event_key: String) -> AudioStream:
	var keys = [META_OVERRIDE]
	match event_key:
		"hover":
			keys.append(META_OVERRIDE_HOVER)
		"press":
			keys.append(META_OVERRIDE_PRESS)
		"toggle":
			keys.append(META_OVERRIDE_TOGGLE)
		"select":
			keys.append(META_OVERRIDE_SELECT)
		"confirm":
			keys.append(META_OVERRIDE_CONFIRM)
	for key in keys:
		if control.has_meta(key):
			return _coerce_stream(control.get_meta(key))
	return null

func _resolve_child_override(control: Control, event_key: String) -> AudioStream:
	for child in control.get_children():
		if child is UiSfxOverride:
			return _resolve_override_from_node(child, event_key)
	return null

func _resolve_override_from_node(override_node: UiSfxOverride, event_key: String) -> AudioStream:
	if override_node.override_all != null:
		return override_node.override_all
	match event_key:
		"hover":
			return override_node.hover
		"press":
			return override_node.press
		"toggle":
			return override_node.toggle
		"select":
			return override_node.select
		"confirm":
			return override_node.confirm
	return null

func _coerce_stream(value: Variant) -> AudioStream:
	if value is AudioStream:
		return value
	if value is String or value is StringName:
		return load(String(value)) as AudioStream
	return null
