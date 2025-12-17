extends Area3D

@export var dropoff_paths: Array[NodePath] = []
@export var item_name: String = "Parcel"

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var available: bool = true
var dropoffs: Array[Node3D] = []
var last_dropoff: Node3D
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	for path in dropoff_paths:
		var dropoff := get_node_or_null(path)
		if dropoff:
			dropoffs.append(dropoff)
	if dropoffs.is_empty():
		push_warning("Pickup missing dropoff references.")
	body_entered.connect(_on_body_entered)
	Jobs.job_available.connect(_on_job_available)

func _on_body_entered(body: Node3D) -> void:
	if not available:
		return
	if not body.is_in_group("player"):
		return
	if Jobs.has_active_job() or PlayerData.is_carrying():
		return
	var dropoff := _choose_dropoff()
	if dropoff == null:
		push_warning("Pickup missing dropoff reference.")
		return
	available = false
	mesh_instance.visible = false
	collision_shape.set_deferred("disabled", true)
	Jobs.start_job(dropoff)
	PlayerData.set_carrying(item_name)
	UIEvents.show_message("Picked up delivery. Target: %s" % dropoff.name)

func _choose_dropoff() -> Node3D:
	if dropoffs.is_empty():
		return null
	if dropoffs.size() == 1:
		last_dropoff = dropoffs[0]
		return last_dropoff
	var dropoff := dropoffs[rng.randi_range(0, dropoffs.size() - 1)]
	if last_dropoff != null and dropoffs.size() > 1:
		var tries := 0
		while dropoff == last_dropoff and tries < 3:
			dropoff = dropoffs[rng.randi_range(0, dropoffs.size() - 1)]
			tries += 1
	last_dropoff = dropoff
	return dropoff

func _on_job_available() -> void:
	available = true
	mesh_instance.visible = true
	collision_shape.set_deferred("disabled", false)
