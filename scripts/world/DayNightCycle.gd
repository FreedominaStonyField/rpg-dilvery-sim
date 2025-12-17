extends DirectionalLight3D

@export_range(-180.0, 180.0) var dawn_angle: float = -10.0
@export_range(-180.0, 180.0) var night_angle: float = -130.0
@export_range(0.0, 2.0) var max_energy: float = 1.0
@export_range(0.0, 2.0) var min_energy: float = 0.1

func _process(_delta: float) -> void:
	var ratio := TimeSystem.get_time_ratio()
	_update_rotation(ratio)
	_update_energy(ratio)

func _update_rotation(ratio: float) -> void:
	var sun_angle :float = lerp(dawn_angle, night_angle, ratio)
	rotation_degrees.x = sun_angle

func _update_energy(ratio: float) -> void:
	light_energy = lerp(max_energy, min_energy, ratio)
