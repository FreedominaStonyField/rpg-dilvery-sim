extends Area3D

@export var dropoff_path: NodePath
@export var item_name: String = "Parcel"

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var available: bool = true
var dropoff: Node3D

func _ready() -> void:
    dropoff = get_node_or_null(dropoff_path)
    body_entered.connect(_on_body_entered)
    Jobs.job_available.connect(_on_job_available)

func _on_body_entered(body: Node3D) -> void:
    if not available:
        return
    if not body.is_in_group("player"):
        return
    if Jobs.has_active_job() or PlayerData.is_carrying():
        return
    if dropoff == null:
        push_warning("Pickup missing dropoff reference.")
        return
    available = false
    mesh_instance.visible = false
    collision_shape.disabled = true
    Jobs.start_job(dropoff)
    PlayerData.set_carrying(item_name)
    UIEvents.show_message("Picked up delivery.")

func _on_job_available() -> void:
    available = true
    mesh_instance.visible = true
    collision_shape.disabled = false
