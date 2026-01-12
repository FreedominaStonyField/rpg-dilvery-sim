extends DirectionalLight3D

@export var environment_path: NodePath = NodePath("../WorldEnvironment")
@export_range(-180.0, 180.0) var dawn_angle: float = -10.0
@export_range(-180.0, 180.0) var night_angle: float = -130.0
@export_range(0.0, 2.0) var max_energy: float = 1.0
@export_range(0.0, 2.0) var min_energy: float = 0.1
@export_range(0.0, 2.0) var max_ambient_energy: float = 1.0
@export_range(0.0, 2.0) var min_ambient_energy: float = 0.15
@export_range(0.2, 3.0) var dusk_bias: float = 1.6

@onready var world_environment: WorldEnvironment = get_node_or_null(
	environment_path
) as WorldEnvironment

func _process(_delta: float) -> void:
	var ratio = TimeSystem.get_time_ratio()
	var curfew_progress = _get_curfew_progress(ratio)
	_update_rotation(curfew_progress)
	_update_energy(curfew_progress)
	_update_ambient(curfew_progress)

func _update_rotation(ratio: float) -> void:
	var sun_angle :float = lerp(dawn_angle, night_angle, ratio)
	rotation_degrees.x = sun_angle

func _update_energy(ratio: float) -> void:
	light_energy = lerp(max_energy, min_energy, ratio)

func _update_ambient(ratio: float) -> void:
	if world_environment == null or world_environment.environment == null:
		return
	world_environment.environment.ambient_light_energy = lerp(
		max_ambient_energy,
		min_ambient_energy,
		ratio
	)

func _get_curfew_progress(ratio: float) -> float:
	var curfew_ratio = max(TimeSystem.curfew_ratio, 0.001)
	var progress = clamp(ratio / curfew_ratio, 0.0, 1.0)
	return ease(progress, dusk_bias)
