@tool
extends AnimationTree

signal animation_debug_event(event: Dictionary)
signal interact_started()
signal interact_finished()
signal interact_midpoint()

@export var player: CharacterBody3D
@export var animation_player_path: NodePath = NodePath("../Emma avatarty/AnimationPlayer")
@export var model_root_path: NodePath = NodePath("../Emma avatarty")

@export_group("State Animations")
@export var idle_anim: StringName = &""
@export var walk_anim: StringName = &""
@export var sprint_anim: StringName = &""
@export var jump_start_anim: StringName = &""
@export var jump_loop_anim: StringName = &""
@export var land_anim: StringName = &""

@export_group("Animation Blending")
@export var default_blend_time: float = 0.2
@export var blend_overrides: Dictionary = {}

@export_group("Facing")
@export var enable_facing: bool = true
@export var facing_smoothing: float = 0.15

@export_group("Interact")
@export var interact_anim: StringName = &"AnimationLibrary_Godot_Standard/Interact"
@export_range(0.0, 1.0, 0.05) var interact_midpoint_ratio: float = 0.5

const STATE_IDLE = &"idle"
const STATE_WALK = &"walk"
const STATE_SPRINT = &"sprint"
const STATE_JUMP_START = &"jump_start"
const STATE_JUMP_LOOP = &"jump_loop"
const STATE_LAND = &"land"

var playback: AnimationNodeStateMachinePlayback
var animation_player: AnimationPlayer
var was_on_floor: bool = true
var jump_start_timer: float = 0.0
var model_root: Node3D
var last_local_move: Vector3 = Vector3.FORWARD
var last_state: StringName = &""
var blend_from_state: StringName = &""
var blend_time_left: float = 0.0
var current_blend_duration: float = 0.2
var state_time: float = 0.0
var state_anim_map: Dictionary = {}
var debug_enabled: bool = OS.is_debug_build() or Engine.is_editor_hint()
var _missing_anim_warnings: Dictionary = {}
var _interact_active: bool = false
var _interact_mid_timer: SceneTreeTimer

func _ready() -> void:
	if player == null:
		player = get_parent() as CharacterBody3D
	animation_player = get_node_or_null(animation_player_path) as AnimationPlayer
	model_root = get_node_or_null(model_root_path) as Node3D
	add_to_group("player_animator")
	if animation_player == null:
		push_warning("AnimationPlayer missing for animator.")
		return
	if animation_player.animation_started.is_connected(_on_animation_started) == false:
		animation_player.animation_started.connect(_on_animation_started)
	if animation_player.animation_finished.is_connected(_on_animation_finished) == false:
		animation_player.animation_finished.connect(_on_animation_finished)
	anim_player = animation_player_path
	active = true
	playback = get("parameters/playback")
	if playback:
		playback.start(STATE_IDLE)
		last_state = playback.get_current_node()
		state_time = 0.0
	_apply_state_animations()
	_apply_blend_times()
	_validate_animation_mapping()

func _physics_process(delta: float) -> void:
	if animation_player == null or playback == null:
		return
	if Engine.is_editor_hint():
		return
	if not GameState.is_playing():
		return
	if _interact_active:
		state_time += delta
		return
	var on_floor = _is_player_grounded()
	if enable_facing:
		_update_model_facing()
	if not on_floor:
		if was_on_floor:
			jump_start_timer = _animation_length(jump_start_anim, 0.2)
			_travel(STATE_JUMP_START, "left_floor")
		elif jump_start_timer > 0.0:
			jump_start_timer = max(jump_start_timer - delta, 0.0)
		elif playback.get_current_node() != STATE_JUMP_LOOP:
			_travel(STATE_JUMP_LOOP, "airborne_loop")
	else:
		jump_start_timer = 0.0
		_play_ground_state()
	was_on_floor = on_floor
	if blend_time_left > 0.0:
		blend_time_left = max(blend_time_left - delta, 0.0)
	state_time += delta

func _play_ground_state() -> void:
	if not _has_move_input():
		_travel(STATE_IDLE, "ground_move")
	elif _is_sprinting():
		_travel(STATE_SPRINT, "ground_move")
	else:
		_travel(STATE_WALK, "ground_move")

func _ground_speed() -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()

func _has_move_input() -> bool:
	if player == null:
		return false
	if player.has_method("is_move_input_active"):
		return player.is_move_input_active()
	return _ground_speed() > 0.1

func _is_player_grounded() -> bool:
	if player == null:
		return false
	if player.has_method("is_grounded"):
		return player.is_grounded()
	return player.is_on_floor()

func _is_sprinting() -> bool:
	return player.has_method("is_sprinting") and player.is_sprinting()

func _travel(state: StringName, reason: String = "") -> void:
	if playback == null or playback.get_current_node() == state:
		return
	var previous_state = playback.get_current_node()
	_start_blend(previous_state, state)
	playback.travel(state)
	last_state = state
	state_time = 0.0
	_emit_debug_event("StateEntered", _state_to_animation(state), "AnimatorTravel", {
		"state": state,
		"previous_state": previous_state,
		"reason": reason
	})

func _apply_state_animations() -> void:
	var machine = _get_state_machine()
	if machine == null:
		return
	_set_state_animation(machine, STATE_IDLE, idle_anim)
	_set_state_animation(machine, STATE_WALK, walk_anim)
	_set_state_animation(machine, STATE_SPRINT, sprint_anim)
	_set_state_animation(machine, STATE_JUMP_START, jump_start_anim)
	_set_state_animation(machine, STATE_JUMP_LOOP, jump_loop_anim)
	_set_state_animation(machine, STATE_LAND, land_anim)

func _apply_blend_times() -> void:
	var machine = _get_state_machine()
	if machine == null:
		return
	var count = machine.get_transition_count()
	for index in count:
		var from_state: String = machine.get_transition_from(index)
		var to_state: String = machine.get_transition_to(index)
		var transition = machine.get_transition(index)
		if transition == null:
			continue
		transition.xfade_time = _get_transition_time(from_state, to_state)

func _get_state_machine() -> AnimationNodeStateMachine:
	var root: AnimationRootNode = tree_root
	if root is AnimationNodeStateMachine:
		return root as AnimationNodeStateMachine
	return null

func _set_state_animation(
		machine: AnimationNodeStateMachine,
		state_name: StringName,
		anim_name: StringName
	) -> void:
	if anim_name == StringName(""):
		return
	var node = machine.get_node(state_name)
	if node is AnimationNodeAnimation:
		var anim_string = String(anim_name)
		node.animation = anim_string
		state_anim_map[state_name] = anim_string

func _animation_length(anim_name: StringName, default_length: float) -> float:
	var anim_string = String(anim_name)
	if _has_animation(anim_string):
		return animation_player.get_animation(anim_string).length
	return default_length

func _update_model_facing() -> void:
	if model_root == null:
		return
	var move_dir = Vector3(player.velocity.x, 0.0, player.velocity.z)
	var local_dir = player.global_transform.basis.inverse() * move_dir
	local_dir.y = 0.0
	if local_dir.length() > 0.05:
		last_local_move = local_dir.normalized()
	if last_local_move.length() < 0.01:
		return
	var target_yaw = atan2(last_local_move.x, last_local_move.z)
	var current_yaw = model_root.rotation.y
	model_root.rotation.y = lerp_angle(current_yaw, target_yaw, facing_smoothing)

func _start_blend(from: StringName, to: StringName) -> void:
	if from == "":
		blend_from_state = ""
		blend_time_left = 0.0
		return
	blend_from_state = from
	var time = _get_transition_time(str(from), str(to))
	blend_time_left = time
	current_blend_duration = time

func _get_transition_time(from: String, to: String) -> float:
	var key = "%s>%s" % [from, to]
	if blend_overrides.has(key):
		return blend_overrides[key]
	return default_blend_time

func _state_to_animation(state: StringName) -> String:
	return state_anim_map.get(state, "")

func _validate_animation_mapping() -> void:
	_warn_missing_anim(STATE_IDLE, idle_anim)
	_warn_missing_anim(STATE_WALK, walk_anim)
	_warn_missing_anim(STATE_SPRINT, sprint_anim)
	_warn_missing_anim(STATE_JUMP_START, jump_start_anim)
	_warn_missing_anim(STATE_JUMP_LOOP, jump_loop_anim)
	_warn_missing_anim(STATE_LAND, land_anim)
	_warn_missing_anim(&"interact", interact_anim)

func _warn_missing_anim(state: StringName, anim_name: StringName) -> void:
	if anim_name == StringName(""):
		_warn_once(state, "Animation not assigned for state '%s'." % state)
		return
	if not _has_animation(String(anim_name)):
		_warn_once(
			state,
			"Animation '%s' missing for state '%s'." % [anim_name, state]
		)

func _warn_once(key: StringName, message: String) -> void:
	if _missing_anim_warnings.has(key):
		return
	_missing_anim_warnings[key] = true
	push_warning(message)

func _has_animation(name: String) -> bool:
	return animation_player != null and animation_player.has_animation(name)

func _on_animation_started(anim_name: StringName) -> void:
	_emit_debug_event("AnimationStarted", str(anim_name), "AnimationPlayer", {
		"state": playback.get_current_node() if playback else "",
	})

func _on_animation_finished(anim_name: StringName) -> void:
	if _interact_active and anim_name == interact_anim:
		_end_interact()

func _emit_debug_event(
		event_type: String,
		anim_key: String,
		source: String,
		context: Dictionary
	) -> void:
	if not debug_enabled:
		return
	if player == null:
		return
	var entry: Dictionary = {
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"frame": Engine.get_physics_frames(),
		"event_type": event_type,
		"animation": anim_key,
		"state": context.get("state", ""),
		"previous_state": context.get("previous_state", ""),
		"source": source,
		"reason": context.get("reason", ""),
		"is_on_floor": player.is_on_floor(),
		"velocity": player.velocity,
		"speed": Vector2(player.velocity.x, player.velocity.z).length(),
		"velocity_y": player.velocity.y,
		"mode": GameState.mode
	}
	animation_debug_event.emit(entry)

func get_debug_state() -> Dictionary:
	var current_state: StringName = playback.get_current_node() if playback else StringName("")
	return {
		"state": current_state,
		"state_time": state_time,
		"animation": _state_to_animation(current_state),
		"jump_start_timer": jump_start_timer
	}

func get_blend_snapshot() -> Array[Dictionary]:
	var blends: Array[Dictionary] = []
	if blend_from_state != "":
		var div = current_blend_duration if current_blend_duration > 0.0 else 1.0
		var from_weight: float = clamp(blend_time_left / div, 0.0, 1.0)
		blends.append({
			"state": blend_from_state,
			"animation": _state_to_animation(blend_from_state),
			"weight": from_weight
		})
	var current_state: StringName = playback.get_current_node() if playback else StringName("")
	if current_state != "":
		var current_weight: float = 1.0
		if blend_from_state != "":
			var div = current_blend_duration if current_blend_duration > 0.0 else 1.0
			current_weight = 1.0 - clamp(blend_time_left / div, 0.0, 1.0)
		blends.append({
			"state": current_state,
			"animation": _state_to_animation(current_state),
			"weight": current_weight
		})
	return blends

func play_interact() -> bool:
	if _interact_active:
		return false
	if animation_player == null:
		return false
	var anim_name = String(interact_anim)
	if anim_name == "":
		return false
	if not _has_animation(anim_name):
		_warn_once(&"interact", "Animation '%s' missing for interact." % anim_name)
		return false
	_interact_active = true
	active = false
	animation_player.play(anim_name)
	_schedule_interact_midpoint(_animation_length(interact_anim, 0.0))
	if player != null and player.has_method("set_movement_locked"):
		player.set_movement_locked(true)
	interact_started.emit()
	return true

func is_interacting() -> bool:
	return _interact_active

func _end_interact() -> void:
	_interact_active = false
	active = true
	if playback != null and playback.get_current_node() == "":
		playback.start(STATE_IDLE)
	if player != null and player.has_method("set_movement_locked"):
		player.set_movement_locked(false)
	interact_finished.emit()

func _schedule_interact_midpoint(anim_length: float) -> void:
	var ratio = clamp(interact_midpoint_ratio, 0.0, 1.0)
	if anim_length <= 0.0:
		_emit_interact_midpoint()
		return
	var time = anim_length * ratio
	if time <= 0.0:
		_emit_interact_midpoint()
		return
	if not is_inside_tree():
		return
	_interact_mid_timer = get_tree().create_timer(time)
	_interact_mid_timer.timeout.connect(_on_interact_midpoint_timeout)

func _on_interact_midpoint_timeout() -> void:
	if not _interact_active:
		return
	_emit_interact_midpoint()

func _emit_interact_midpoint() -> void:
	interact_midpoint.emit()
