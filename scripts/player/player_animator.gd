extends AnimationTree

@export var player: CharacterBody3D
@export var animation_player_path: NodePath = NodePath("../Emma avatarty/AnimationPlayer")
@export var model_root_path: NodePath = NodePath("../Emma avatarty")

const ANIM_LIB := "AnimationLibrary_Godot_Standard"

var playback: AnimationNodeStateMachinePlayback
var animation_player: AnimationPlayer
var land_timer: float = 0.0
var was_on_floor: bool = true
var jump_start_timer: float = 0.0
var model_root: Node3D
var last_local_move: Vector3 = Vector3.FORWARD
const BLEND_TIME := 0.2

func _ready() -> void:
	if player == null:
		player = get_parent() as CharacterBody3D
	animation_player = get_node_or_null(animation_player_path) as AnimationPlayer
	model_root = get_node_or_null(model_root_path) as Node3D
	if animation_player == null:
		push_warning("AnimationPlayer missing for animator.")
		return
	anim_player = animation_player_path
	tree_root = _build_state_machine()
	active = true
	playback = get("parameters/playback")
	if playback:
		playback.start("idle")

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
			_travel("jump_start")
		elif jump_start_timer > 0.0:
			jump_start_timer = max(jump_start_timer - delta, 0.0)
		elif playback.get_current_node() != "jump_loop":
			_travel("jump_loop")
	else:
		jump_start_timer = 0.0
		if not was_on_floor:
			land_timer = _animation_length("Jump_Land", 0.35)
			_travel("land")
		if land_timer > 0.0:
			land_timer = max(land_timer - delta, 0.0)
		else:
			_play_ground_state()
	was_on_floor = on_floor

func _play_ground_state() -> void:
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	if speed < 0.1:
		_travel("idle")
	elif _is_sprinting():
		_travel("sprint")
	else:
		_travel("walk")

func _is_sprinting() -> bool:
	return player.has_method("is_sprinting") and player.is_sprinting()

func _travel(state: StringName) -> void:
	if playback.get_current_node() == state:
		return
	playback.travel(state)

func _build_state_machine() -> AnimationNodeStateMachine:
	var machine := AnimationNodeStateMachine.new()
	machine.add_node("idle", _make_animation_node(_resolve_anim_candidates(["Idle_Loop", "Idle", "Walk_Loop", "Jog_Fwd"])))
	machine.add_node("walk", _make_animation_node(_resolve_anim_candidates(["Walk_Loop", "Jog_Fwd_Loop", "Jog_Fwd", "Idle_Loop"])))
	machine.add_node("sprint", _make_animation_node(_resolve_anim_candidates(["Sprint_Loop", "Jog_Fwd", "Jog_Fwd_Loop", "Walk_Loop"])))
	machine.add_node("jump_start", _make_animation_node(_resolve_anim_candidates(["Jump_Start", "Jump_Loop"])))
	machine.add_node("jump_loop", _make_animation_node(_resolve_anim_candidates(["Jump_Loop", "Jump_Start", "Idle_Loop"])))
	machine.add_node("land", _make_animation_node(_resolve_anim_candidates(["Jump_Land", "Idle_Loop"])))
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

func _make_animation_node(anim_name: String) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = anim_name
	return node

func _add_transition_pairs(machine: AnimationNodeStateMachine, a: String, b: String) -> void:
	_add_transition(machine, a, b)
	_add_transition(machine, b, a)

func _add_transition(machine: AnimationNodeStateMachine, from: String, to: String) -> void:
	if machine.has_transition(from, to):
		return
	var transition := AnimationNodeStateMachineTransition.new()
	transition.xfade_time = BLEND_TIME
	machine.add_transition(from, to, transition)

func _resolve_anim_candidates(names: Array) -> String:
	for name in names:
		var candidate := _with_library(name)
		if _has_animation(candidate):
			return candidate
	return animation_player.get_animation_list()[0] if animation_player.get_animation_list().size() > 0 else ""

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
