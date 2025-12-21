extends CharacterBody3D

signal landed(impact_speed: float)
signal stamina_changed(current: float, max: float, percent: float)

@export var move_speed: float = 5.0
@export var sprint_speed: float = 9.0
@export var jump_force: float = 4.5
@export var mouse_sensitivity: float = 0.001
@export var rotation_smoothing: float = 10.0
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@export_group("Camera Tuning")
@export var camera_shoulder_offset: Vector3 = Vector3(0.4, 0.2, 0.0)
@export var camera_pitch_min: float = -60.0
@export var camera_pitch_max: float = 45.0
@export var camera_zoom_min: float = 1.6
@export var camera_zoom_max: float = 5.0
@export var camera_zoom_step: float = 0.35
@export var camera_zoom_smoothing: float = 12.0

@export_group("Sfx")
@export var landing_sfx_path: NodePath = NodePath("AnimationSfx")

@export_group("Animation")
@export var animator_path: NodePath = NodePath("AnimationTree")

@export_group("Movement Tuning")
@export var bDisableAirControl: bool = true
@export_enum("Ignore Input", "Clamp Speed") var LandingCooldownMode: String = "Ignore Input"
@export var LandingCooldownDuration: float = 0.2
@export var LandingMoveSpeedMultiplier: float = 0.5

@export_group("Stamina")
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 30.0
@export var stamina_regen_rate: float = 20.0
@export var stamina_regen_rate_exhausted: float = 12.0
@export var stamina_resume_threshold: float = 15.0
@export var stamina_regen_delay: float = 0.2

var _stamina: float = 0.0
var _stamina_exhausted: bool = false
var _stamina_regen_delay_timer: float = 0.0
var _is_sprinting: bool = false
var _pitch: float = deg_to_rad(-20.0)
var _was_on_floor: bool = false
var _landing_cooldown_timer: float = 0.0
var _zoom_target: float = 0.0
var _movement_locked: bool = false

@onready var camera_pivot: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var landing_sfx: AnimationSfx = get_node_or_null(landing_sfx_path) as AnimationSfx
@onready var animator: Node = get_node_or_null(animator_path)

func _ready() -> void:
	add_to_group("player")
	GameState.mode_changed.connect(_on_mode_changed)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_zoom_target = clamp(camera_pivot.spring_length, camera_zoom_min, camera_zoom_max)
	camera_pivot.spring_length = _zoom_target
	_apply_camera_offsets()
	_was_on_floor = is_on_floor()
	_stamina = max_stamina
	_emit_stamina_changed()
	if landed.is_connected(_on_landed) == false:
		landed.connect(_on_landed)

func _physics_process(delta: float) -> void:
	if not GameState.is_playing():
		return
	_update_stamina(delta)
	_landing_cooldown_timer = max(0.0, _landing_cooldown_timer - delta)

	var direction := _get_move_direction()
	var speed := _current_speed()
	var vel := velocity
	var pre_move_velocity_y := vel.y
	var allow_input := not _movement_locked

	if is_on_floor():
		if _landing_cooldown_timer > 0.0:
			if LandingCooldownMode == "Ignore Input":
				direction = Vector3.ZERO
			elif LandingCooldownMode == "Clamp Speed":
				speed *= LandingMoveSpeedMultiplier
		
		if not allow_input:
			vel.x = 0.0
			vel.z = 0.0
		else:
			vel.x = direction.x * speed
			vel.z = direction.z * speed

		if allow_input and Input.is_action_just_pressed("jump"):
			vel.y = jump_force
		else:
			vel.y = 0.0
	else:
		vel.y -= gravity * delta
		if not allow_input:
			vel.x = 0.0
			vel.z = 0.0
		elif not bDisableAirControl:
			vel.x = direction.x * speed
			vel.z = direction.z * speed

	velocity = vel
	move_and_slide()

	var on_floor := is_on_floor()
	var just_landed := on_floor and not _was_on_floor
	if just_landed:
		_landing_cooldown_timer = LandingCooldownDuration
		landed.emit(abs(min(pre_move_velocity_y, 0.0)))

	_was_on_floor = on_floor
	
	# Smooth rotation
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

func is_move_input_active() -> bool:
	if _movement_locked:
		return false
	return Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	) != Vector2.ZERO

func _current_speed() -> float:
	return sprint_speed if _is_sprinting else move_speed

func _update_stamina(delta: float) -> void:
	var wants_sprint := Input.is_action_pressed("sprint") and is_move_input_active()
	var can_sprint := not _stamina_exhausted and _stamina > 0.0
	_is_sprinting = wants_sprint and can_sprint

	if _is_sprinting:
		_stamina_regen_delay_timer = stamina_regen_delay
		_set_stamina(_stamina - stamina_drain_rate * delta)
		if _stamina <= 0.0:
			_stamina = 0.0
			_stamina_exhausted = true
	else:
		_stamina_regen_delay_timer = max(0.0, _stamina_regen_delay_timer - delta)
		if _stamina < max_stamina and _stamina_regen_delay_timer <= 0.0:
			var regen_rate := stamina_regen_rate
			if _stamina_exhausted:
				regen_rate = stamina_regen_rate_exhausted
			_set_stamina(_stamina + regen_rate * delta)
		if _stamina_exhausted and _stamina >= stamina_resume_threshold:
			_stamina_exhausted = false

func _on_mode_changed(mode: GameState.Mode) -> void:
	if mode == GameState.Mode.PAUSED or mode == GameState.Mode.MENU:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif mode == GameState.Mode.PLAYING:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func is_sprinting() -> bool:
	return _is_sprinting

func get_stamina_current() -> float:
	return _stamina

func get_stamina_max() -> float:
	return max_stamina

func get_stamina_percent() -> float:
	if max_stamina <= 0.0:
		return 0.0
	return _stamina / max_stamina

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

func _set_stamina(value: float) -> void:
	var clamped = clamp(value, 0.0, max_stamina)
	if not is_equal_approx(clamped, _stamina):
		_stamina = clamped
		_emit_stamina_changed()

func _emit_stamina_changed() -> void:
	var percent := 0.0
	if max_stamina > 0.0:
		percent = _stamina / max_stamina
	stamina_changed.emit(_stamina, max_stamina, percent)

func _on_landed(impact_speed: float) -> void:
	if landing_sfx == null:
		return
	landing_sfx.play_land()

func set_movement_locked(locked: bool) -> void:
	if _movement_locked == locked:
		return
	_movement_locked = locked
	if locked:
		_is_sprinting = false
		velocity.x = 0.0
		velocity.z = 0.0

func is_movement_locked() -> bool:
	return _movement_locked

func play_interact_animation() -> bool:
	if animator == null:
		return false
	if animator.has_method("play_interact"):
		return animator.play_interact()
	return false
