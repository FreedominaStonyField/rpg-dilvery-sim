extends Area3D

@export var item_id: String = "apple"
@export var item_name: String = "Apple"
@export var item_description: String = "A fresh apple. Smells sweet."
@export var quantity: int = 1
@export var interact_action: String = "interact"
@export var single_use: bool = false

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: Node3D = $MeshInstance3D

var player_in_range: bool = false
var available: bool = true

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_prompt()

func _exit_tree() -> void:
	UIEvents.unregister_interaction(self)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		_update_prompt()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		_update_prompt()

func get_interaction_label() -> String:
	return "Take %s" % item_name

func get_interaction_action() -> String:
	return interact_action

func can_interact() -> bool:
	return _can_interact()

func perform_interaction() -> void:
	if not player_in_range or not _can_interact():
		return
	InventorySystem.add_item({
		"id": item_id,
		"name": item_name,
		"description": item_description,
		"quantity": quantity
	})
	UIEvents.show_message("Picked up %s." % item_name)
	if single_use:
		available = false
		mesh_instance.visible = false
		collision_shape.set_deferred("disabled", true)
	_update_prompt()

func _can_interact() -> bool:
	return available

func _update_prompt() -> void:
	if player_in_range and _can_interact():
		UIEvents.register_interaction(self)
	else:
		UIEvents.unregister_interaction(self)
