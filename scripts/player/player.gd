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

@export_group("Step Up")
@export var step_height: float = 0.5
@export var step_forward_distance: float = 0.3
@export var step_up_duration: float = 0.08
@export var ground_grace_time: float = 0.1
@export var step_down_grace_time: float = 0.12
@export var step_down_max_fall_speed: float = 2.5
@export var step_check_path: NodePath = NodePath("StepCheck")

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
var _sprint_release_required: bool = false
var _pitch: float = deg_to_rad(-20.0)
var _was_on_floor: bool = false
var _landing_cooldown_timer: float = 0.0
var _zoom_target: float = 0.0
var _movement_locked: bool = false
var _step_up_active: bool = false
var _step_up_target_y: float = 0.0
var _ground_grace_timer: float = 0.0

@onready var camera_pivot: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var landing_sfx: AnimationSfx = get_node_or_null(landing_sfx_path) as AnimationSfx
@onready var animator: Node = get_node_or_null(animator_path)
@onready var step_check: ShapeCast3D = get_node_or_null(step_check_path) as ShapeCast3D

func _ready() -> void:
	add_to_group("player")
	GameState.mode_changed.connect(_on_mode_changed)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_zoom_target = clamp(camera_pivot.spring_length, camera_zoom_min, camera_zoom_max)
	camera_pivot.spring_length = _zoom_target
	_apply_camera_offsets()
	_was_on_floor = is_on_floor()
	_ground_grace_timer = ground_grace_time
	_stamina = max_stamina
	_emit_stamina_changed()
	if landed.is_connected(_on_landed) == false:
		landed.connect(_on_landed)
	_sync_step_check()

func _physics_process(delta: float) -> void:
	if not GameState.is_playing():
		return
	_update_stamina(delta)
	_landing_cooldown_timer = max(0.0, _landing_cooldown_timer - delta)

	var direction = _get_move_direction()
	var speed = _current_speed()
	var vel = velocity
	var pre_move_velocity_y = vel.y
	var allow_input = not _movement_locked

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
	_handle_step_up(direction)
	_update_step_up(delta)

	var on_floor = is_on_floor()
	var just_landed = on_floor and not _was_on_floor
	if just_landed:
		_landing_cooldown_timer = LandingCooldownDuration
		landed.emit(abs(min(pre_move_velocity_y, 0.0)))

	if on_floor:
		_ground_grace_timer = ground_grace_time
	elif _was_on_floor and velocity.y <= 0.0 and abs(velocity.y) <= step_down_max_fall_speed:
		_ground_grace_timer = max(_ground_grace_timer, step_down_grace_time)
	else:
		_ground_grace_timer = max(0.0, _ground_grace_timer - delta)

	_was_on_floor = on_floor
	
	_update_camera_zoom(delta)
	_apply_camera_offsets()

func _handle_step_up(move_dir: Vector3) -> void:
	if _step_up_active:
		return
	if step_check == null:
		return
	if not is_on_floor():
		return
	if not is_on_wall():
		return
	if step_height <= 0.0 or step_forward_distance <= 0.0:
		return
	var flat_dir = Vector3(move_dir.x, 0.0, move_dir.z)
	if flat_dir == Vector3.ZERO:
		return
	_sync_step_check()
	step_check.force_shapecast_update()
	if step_check.is_colliding():
		return

	var original_transform = global_transform
	var up_offset = Vector3.UP * step_height
	if move_and_collide(up_offset, true) != null:
		return

	flat_dir = flat_dir.normalized()
	var forward_offset = flat_dir * step_forward_distance
	global_transform = original_transform.translated(up_offset)
	if move_and_collide(forward_offset, true) != null:
		global_transform = original_transform
		return

	global_transform = original_transform.translated(up_offset + forward_offset)
	var down_collision = move_and_collide(Vector3.DOWN * step_height)
	if down_collision == null:
		global_transform = original_transform
		return
	var target_transform = global_transform
	global_transform = original_transform
	_step_up_target_y = target_transform.origin.y
	_step_up_active = true
	velocity = Vector3.ZERO

func _update_step_up(delta: float) -> void:
	if not _step_up_active:
		return
	if step_up_duration <= 0.0:
		global_position.y = _step_up_target_y
		_step_up_active = false
		velocity.y = 0.0
		return
	var remaining = _step_up_target_y - global_position.y
	if remaining <= 0.001:
		_step_up_active = false
		velocity.y = 0.0
		return
	var speed = step_height / step_up_duration
	var step = min(remaining, speed * delta)
	var hit = move_and_collide(Vector3(0.0, step, 0.0))
	if hit != null:
		_step_up_active = false
		velocity.y = 0.0
		return
	velocity.y = step / max(delta, 0.0001)

func _sync_step_check() -> void:
	if step_check == null:
		return
	step_check.position.y = step_height
	step_check.target_position = Vector3(
		0.0,
		0.0,
		-max(0.1, step_forward_distance * 2.0)
	)
	var shape = step_check.shape
	if shape is CylinderShape3D:
		var cylinder = shape as CylinderShape3D
		cylinder.height = max(0.05, step_height)
	elif shape is BoxShape3D:
		var box = shape as BoxShape3D
		var size = box.size
		size.y = max(0.05, step_height)
		box.size = size

func is_grounded() -> bool:
	return is_on_floor() or _step_up_active or _ground_grace_timer > 0.0

func _unhandled_input(event: InputEvent) -> void:
	if not GameState.is_playing():
		return
	var mouse_event = event as InputEventMouseMotion
	if mouse_event and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(mouse_event.relative)
		return
	var wheel_event = event as InputEventMouseButton
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
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if input_dir == Vector2.ZERO:
		return Vector3.ZERO
	var forward = camera_pivot.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right = camera_pivot.global_transform.basis.x
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
	var wants_sprint = Input.is_action_pressed("sprint") and is_move_input_active()
	if _sprint_release_required and not Input.is_action_pressed("sprint"):
		_sprint_release_required = false
	var can_sprint = (
		not _stamina_exhausted
		and _stamina > 0.0
		and not _sprint_release_required
	)
	_is_sprinting = wants_sprint and can_sprint

	if _is_sprinting:
		_stamina_regen_delay_timer = stamina_regen_delay
		_set_stamina(_stamina - stamina_drain_rate * delta)
		if _stamina <= 0.0:
			_stamina = 0.0
			_stamina_exhausted = true
			_sprint_release_required = true
	else:
		_stamina_regen_delay_timer = max(0.0, _stamina_regen_delay_timer - delta)
		if _stamina < max_stamina and _stamina_regen_delay_timer <= 0.0:
			var regen_rate = stamina_regen_rate
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
	var percent = 0.0
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

func play_interact_and_wait_midpoint() -> bool:
	if animator == null:
		return true
	if not animator.has_method("play_interact"):
		return true
	var started = animator.play_interact()
	if not started:
		return false
	if animator.has_signal("interact_midpoint"):
		await animator.interact_midpoint
	return true

func get_save_data() -> Dictionary:
	return {
		"position": _vec3_to_array(global_position),
		"rotation": _vec3_to_array(global_rotation),
		"velocity": _vec3_to_array(velocity),
		"camera": {
			"pivot_rotation": _vec3_to_array(camera_pivot.rotation),
			"spring_length": camera_pivot.spring_length
		}
	}

func apply_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	var pos_array = data.get("position", [])
	var rot_array = data.get("rotation", [])
	if pos_array.size() == 3 and rot_array.size() == 3:
		global_position = _array_to_vec3(pos_array)
		global_rotation = _array_to_vec3(rot_array)
	var vel_array = data.get("velocity", [])
	velocity = _array_to_vec3(vel_array)
	var camera_data = data.get("camera", {})
	if typeof(camera_data) == TYPE_DICTIONARY:
		var pivot_array = camera_data.get("pivot_rotation", [])
		if pivot_array.size() == 3:
			camera_pivot.rotation = _array_to_vec3(pivot_array)
			_pitch = camera_pivot.rotation.x
		var zoom = float(camera_data.get("spring_length", camera_pivot.spring_length))
		_zoom_target = clamp(zoom, camera_zoom_min, camera_zoom_max)
		camera_pivot.spring_length = _zoom_target

func _vec3_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _array_to_vec3(value: Array) -> Vector3:
	if value.size() != 3:
		return Vector3.ZERO
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
