extends CharacterBody3D

@export var move_speed: float = 5.0
@export var sprint_speed: float = 9.0
@export var sprint_duration: float = 0.6
@export var sprint_cooldown: float = 2.0
@export var jump_force: float = 4.5
@export var mouse_sensitivity: float = 0.001
@export var rotation_smoothing: float = 10.0
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@export_group("Camera Tuning")
@export var camera_pivot_offset: Vector3 = Vector3(0.0, 1.6, 0.0)
@export var camera_shoulder_offset: Vector3 = Vector3(0.4, 0.2, 0.0)
@export var camera_pitch_min: float = -60.0
@export var camera_pitch_max: float = 45.0
@export var camera_zoom_min: float = 1.6
@export var camera_zoom_max: float = 5.0
@export var camera_zoom_step: float = 0.35
@export var camera_zoom_smoothing: float = 12.0

@export_group("Movement Tuning")
@export var bDisableAirControl: bool = true
@export_enum("Ignore Input", "Clamp Speed") var LandingCooldownMode: String = "Ignore Input"
@export var LandingCooldownDuration: float = 0.2
@export var LandingMoveSpeedMultiplier: float = 0.5

var _sprint_time_left: float = 0.0
var _sprint_cooldown_left: float = 0.0
var _pitch: float = deg_to_rad(-20.0)
var _was_on_floor: bool = false
var _landing_cooldown_timer: float = 0.0
var _zoom_target: float = 0.0

@onready var camera_pivot: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

func _ready() -> void:
	add_to_group("player")
	GameState.mode_changed.connect(_on_mode_changed)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_pivot.set_as_top_level(true)
	_zoom_target = clamp(camera_pivot.spring_length, camera_zoom_min, camera_zoom_max)
	camera_pivot.spring_length = _zoom_target
	_apply_camera_offsets()
	_was_on_floor = is_on_floor()

func _physics_process(delta: float) -> void:
	if not GameState.is_playing():
		return
	_update_sprint(delta)
	_landing_cooldown_timer = max(0.0, _landing_cooldown_timer - delta)

	var direction := _get_move_direction()
	var speed := _current_speed()
	var vel := velocity

	var just_landed := is_on_floor() and not _was_on_floor
	if just_landed:
		_landing_cooldown_timer = LandingCooldownDuration

	if is_on_floor():
		if _landing_cooldown_timer > 0.0:
			if LandingCooldownMode == "Ignore Input":
				direction = Vector3.ZERO
			elif LandingCooldownMode == "Clamp Speed":
				speed *= LandingMoveSpeedMultiplier
		
		vel.x = direction.x * speed
		vel.z = direction.z * speed

		if Input.is_action_just_pressed("jump"):
			vel.y = jump_force
		else:
			vel.y = 0.0
	else:
		vel.y -= gravity * delta
		if not bDisableAirControl:
			vel.x = direction.x * speed
			vel.z = direction.z * speed

	velocity = vel
	move_and_slide()
	
	_was_on_floor = is_on_floor()
	
	# Sync camera position and smooth rotation
	camera_pivot.global_position = global_position + camera_pivot_offset
	rotation.y = lerp_angle(rotation.y, camera_pivot.rotation.y, delta * rotation_smoothing)
	_update_camera_zoom(delta)
	_apply_camera_offsets()

func _unhandled_input(event: InputEvent) -> void:
	if not GameState.is_playing():
		return
	var mouse_event := event as InputEventMouseMotion
	if mouse_event and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(mouse_event.relative)
		return
	var wheel_event := event as InputEventMouseButton
	if wheel_event and wheel_event.pressed:
		if wheel_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_target = clamp(
				_zoom_target - camera_zoom_step,
				camera_zoom_min,
				camera_zoom_max
			)
		elif wheel_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_target = clamp(
				_zoom_target + camera_zoom_step,
				camera_zoom_min,
				camera_zoom_max
			)

func _rotate_camera(relative: Vector2) -> void:
	camera_pivot.rotation.y -= relative.x * mouse_sensitivity
	_pitch = clamp(
		_pitch - relative.y * mouse_sensitivity,
		deg_to_rad(camera_pitch_min),
		deg_to_rad(camera_pitch_max)
	)
	camera_pivot.rotation.x = _pitch

func _get_move_direction() -> Vector3:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if input_dir == Vector2.ZERO:
		return Vector3.ZERO
	var forward := camera_pivot.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := camera_pivot.global_transform.basis.x
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

func is_sprinting() -> bool:
	return _sprint_time_left > 0.0

func _update_camera_zoom(delta: float) -> void:
	if camera_zoom_smoothing <= 0.0:
		camera_pivot.spring_length = _zoom_target
		return
	camera_pivot.spring_length = lerp(
		camera_pivot.spring_length,
		_zoom_target,
		delta * camera_zoom_smoothing
	)

func _apply_camera_offsets() -> void:
	camera.position = camera_shoulder_offset
