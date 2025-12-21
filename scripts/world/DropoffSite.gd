extends Node3D

class_name DropoffSite

@export var site_id: StringName
@export var display_name: String = ""
@export var hint_text: String = ""
@export var enabled: bool = true
@export var snapshot_enabled: bool = false

func _enter_tree() -> void:
    add_to_group("dropoff_sites")

func _exit_tree() -> void:
    remove_from_group("dropoff_sites")

func _ready() -> void:
    if site_id == &"":
        site_id = StringName(name)
        push_warning(
            "DropoffSite '%s' missing site_id. Defaulting to node name." % name
        )
