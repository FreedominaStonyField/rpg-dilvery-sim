extends AnimationTree

signal animation_debug_event(event: Dictionary)

@export var player: CharacterBody3D
@export var animation_player_path: NodePath = NodePath("../Emma avatarty/AnimationPlayer")
@export var model_root_path: NodePath = NodePath("../Emma avatarty")
@export var landing_enabled: bool = true
@export var landing_move_break_speed: float = 0.15

@export_group("Animation Blending")
@export var default_blend_time: float = 0.2
@export var blend_overrides: Dictionary = {}

const ANIM_LIB := "AnimationLibrary_Godot_Standard"

var playback: AnimationNodeStateMachinePlayback
var animation_player: AnimationPlayer
var land_timer: float = 0.0
var was_on_floor: bool = true
var jump_start_timer: float = 0.0
var model_root: Node3D
var last_local_move: Vector3 = Vector3.FORWARD
var last_state: StringName = ""
var blend_from_state: StringName = ""
var blend_time_left: float = 0.0
var current_blend_duration: float = 0.2
var state_time: float = 0.0
var state_anim_map: Dictionary = {}
var debug_enabled: bool = OS.is_debug_build() or Engine.is_editor_hint()

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
	anim_player = animation_player_path
	tree_root = _build_state_machine()
	active = true
	playback = get("parameters/playback")
	if playback:
		playback.start("idle")
		last_state = playback.get_current_node()
		state_time = 0.0

func _physics_process(delta: float) -> void:
	if animation_player == null or playback == null:
		return
	if not GameState.is_playing():
		return
	var on_floor := player.is_on_floor()
	_update_model_facing()
	if not on_floor:
		if was_on_floor:
			jump_start_timer = _animation_length("Jump_Start", 0.2)
			_travel("jump_start", "left_floor")
		elif jump_start_timer > 0.0:
			jump_start_timer = max(jump_start_timer - delta, 0.0)
		elif playback.get_current_node() != "jump_loop":
			_travel("jump_loop", "airborne_loop")
	else:
		jump_start_timer = 0.0
		if not was_on_floor:
			if landing_enabled:
				land_timer = _animation_length("Jump_Land", 0.35)
				_travel("land", "landed")
			else:
				land_timer = 0.0
		if landing_enabled and land_timer > 0.0:
			if _ground_speed() > landing_move_break_speed:
				land_timer = 0.0
				_play_ground_state()
			land_timer = max(land_timer - delta, 0.0)
		else:
			_play_ground_state()
	was_on_floor = on_floor
	if blend_time_left > 0.0:
		blend_time_left = max(blend_time_left - delta, 0.0)
	state_time += delta

func _play_ground_state() -> void:
	var speed := _ground_speed()
	if speed < 0.1:
		_travel("idle", "ground_move")
	elif _is_sprinting():
		_travel("sprint", "ground_move")
	else:
		_travel("walk", "ground_move")

func _ground_speed() -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()

func _is_sprinting() -> bool:
	return player.has_method("is_sprinting") and player.is_sprinting()

func _travel(state: StringName, reason: String = "") -> void:
	if playback == null or playback.get_current_node() == state:
		return
	var previous_state := playback.get_current_node()
	_start_blend(previous_state, state)
	playback.travel(state)
	last_state = state
	state_time = 0.0
	_emit_debug_event("StateEntered", _state_to_animation(state), "AnimatorTravel", {
		"state": state,
		"previous_state": previous_state,
		"reason": reason
	})

func _build_state_machine() -> AnimationNodeStateMachine:
	var machine := AnimationNodeStateMachine.new()
	machine.add_node(
		"idle",
		_make_animation_node(
			"idle",
			_resolve_anim_candidates([
				"Idle_Loop",
				"Idle",
				"Walk_Loop",
                "Jog_Fwd"
			])
		)
	)
	machine.add_node(
		"walk",
		_make_animation_node(
			"walk",
			_resolve_anim_candidates([
				"Walk_Loop",
				"Jog_Fwd_Loop",
				"Jog_Fwd",
                "Idle_Loop"
			])
		)
	)
	machine.add_node(
		"sprint",
		_make_animation_node(
			"sprint",
			_resolve_anim_candidates([
				"Sprint_Loop",
				"Jog_Fwd",
				"Jog_Fwd_Loop",
                "Walk_Loop"
			])
		)
	)
	machine.add_node(
		"jump_start",
		_make_animation_node(
			"jump_start",
			_resolve_anim_candidates([
				"Jump_Start",
                "Jump_Loop"
			])
		)
	)
	machine.add_node(
		"jump_loop",
		_make_animation_node(
			"jump_loop",
			_resolve_anim_candidates([
				"Jump_Loop",
				"Jump_Start",
                "Idle_Loop"
			])
		)
	)
	machine.add_node(
		"land",
		_make_animation_node(
			"land",
			_resolve_anim_candidates([
				"Jump_Land",
                "Idle_Loop"
			])
		)
	)
	_add_transition_pairs(machine, "idle", "walk")
	_add_transition_pairs(machine, "walk", "sprint")
	_add_transition(machine, "idle", "sprint")
	_add_transition(machine, "sprint", "idle")
	_add_transition(machine, "walk", "jump_start")
	_add_transition(machine, "sprint", "jump_start")
	_add_transition(machine, "idle", "jump_start")
	_add_transition(machine, "jump_start", "jump_loop")
	_add_transition(machine, "jump_loop", "land")
	_add_transition(machine, "land", "idle")
	_add_transition(machine, "land", "walk")
	return machine

func _make_animation_node(state_name: String, anim_name: String) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = anim_name
	state_anim_map[state_name] = anim_name
	return node

func _add_transition_pairs(machine: AnimationNodeStateMachine, a: String, b: String) -> void:
	_add_transition(machine, a, b)
	_add_transition(machine, b, a)

func _add_transition(machine: AnimationNodeStateMachine, from: String, to: String) -> void:
	if machine.has_transition(from, to):
		return
	var transition := AnimationNodeStateMachineTransition.new()
	transition.xfade_time = _get_transition_time(from, to)
	machine.add_transition(from, to, transition)

func _resolve_anim_candidates(names: Array) -> String:
	for name in names:
		var candidate := _with_library(name)
		if _has_animation(candidate):
			return candidate
	var anim_list := animation_player.get_animation_list()
	return anim_list[0] if anim_list.size() > 0 else ""

func _has_animation(name: String) -> bool:
	return animation_player != null and animation_player.has_animation(name)

func _with_library(name: String) -> String:
	return "%s/%s" % [ANIM_LIB, name]

func _animation_length(anim_key: String, default_length: float) -> float:
	var anim_name := _with_library(anim_key)
	if _has_animation(anim_name):
		return animation_player.get_animation(anim_name).length
	return default_length

func _update_model_facing() -> void:
	if model_root == null:
		return
	var move_dir := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var local_dir := player.global_transform.basis.inverse() * move_dir
	local_dir.y = 0.0
	if local_dir.length() > 0.05:
		last_local_move = local_dir.normalized()
	if last_local_move.length() < 0.01:
		return
	var target_yaw := atan2(last_local_move.x, last_local_move.z)
	var current_yaw := model_root.rotation.y
	model_root.rotation.y = lerp_angle(current_yaw, target_yaw, 0.15)

func _start_blend(from: StringName, to: StringName) -> void:
	if from == "":
		blend_from_state = ""
		blend_time_left = 0.0
		return
	blend_from_state = from
	var time := _get_transition_time(str(from), str(to))
	blend_time_left = time
	current_blend_duration = time

func _get_transition_time(from: String, to: String) -> float:
	var key := "%s>%s" % [from, to]
	if blend_overrides.has(key):
		return blend_overrides[key]
	return default_blend_time

func _state_to_animation(state: StringName) -> String:
	return state_anim_map.get(state, "")

func _on_animation_started(anim_name: StringName) -> void:
	_emit_debug_event("AnimationStarted", str(anim_name), "AnimationPlayer", {
		"state": playback.get_current_node() if playback else "",
	})

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
		"land_timer": land_timer,
		"jump_start_timer": jump_start_timer
	}

func get_blend_snapshot() -> Array[Dictionary]:
	var blends: Array[Dictionary] = []
	if blend_from_state != "":
		var div := current_blend_duration if current_blend_duration > 0.0 else 1.0
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
			var div := current_blend_duration if current_blend_duration > 0.0 else 1.0
			current_weight = 1.0 - clamp(blend_time_left / div, 0.0, 1.0)
		blends.append({
			"state": current_state,
			"animation": _state_to_animation(current_state),
			"weight": current_weight
		})
	return blends
