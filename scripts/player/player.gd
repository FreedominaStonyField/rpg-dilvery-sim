extends CharacterBody3D

@export var move_speed: float = 5.0
@export var sprint_speed: float = 9.0
@export var sprint_duration: float = 0.6
@export var sprint_cooldown: float = 2.0
@export var jump_force: float = 4.5
@export var mouse_sensitivity: float = 0.015
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _sprint_time_left: float = 0.0
var _sprint_cooldown_left: float = 0.0
var _pitch: float = deg_to_rad(-20.0)

@onready var camera_pivot: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

func _ready() -> void:
	add_to_group("player")
	GameState.mode_changed.connect(_on_mode_changed)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	if not GameState.is_playing():
		return
	_update_sprint(delta)
	var direction := _get_move_direction()
	var speed := _current_speed()
	var vel := velocity
	vel.x = direction.x * speed
	vel.z = direction.z * speed

	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			vel.y = jump_force
		else:
			vel.y = 0.0
	else:
		vel.y -= gravity * delta

	velocity = vel
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if not GameState.is_playing():
		return
	var mouse_event := event as InputEventMouseMotion
	if mouse_event and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(mouse_event.relative)

func _rotate_camera(relative: Vector2) -> void:
	rotation.y -= relative.x * mouse_sensitivity
	_pitch = clamp(_pitch - relative.y * mouse_sensitivity, deg_to_rad(-60.0), deg_to_rad(45.0))
	camera_pivot.rotation.x = _pitch

func _get_move_direction() -> Vector3:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if input_dir == Vector2.ZERO:
		return Vector3.ZERO
	var forward := transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := transform.basis.x
	right.y = 0.0
	right = right.normalized()
	return (forward * input_dir.y + right * input_dir.x).normalized()

func _current_speed() -> float:
	return sprint_speed if _sprint_time_left > 0.0 else move_speed

func _update_sprint(delta: float) -> void:
	if _sprint_time_left > 0.0:
		_sprint_time_left = max(_sprint_time_left - delta, 0.0)
		if _sprint_time_left == 0.0:
			_sprint_cooldown_left = sprint_cooldown
	elif _sprint_cooldown_left > 0.0:
		_sprint_cooldown_left = max(_sprint_cooldown_left - delta, 0.0)
	elif Input.is_action_just_pressed("sprint"):
		_sprint_time_left = sprint_duration

func _on_mode_changed(mode: GameState.Mode) -> void:
	if mode == GameState.Mode.PAUSED or mode == GameState.Mode.MENU:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif mode == GameState.Mode.PLAYING:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
