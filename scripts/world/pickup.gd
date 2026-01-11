extends Area3D

@export var item_name: String = "Parcel"
@export var item_description: String = "Delivery parcel."
@export var interact_action: String = "interact"

@onready var mesh_instance = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var available: bool = true
var player_in_range: bool = false
var player: CharacterBody3D

func _enter_tree() -> void:
	add_to_group("saveable")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	Jobs.job_available.connect(_on_job_available)
	Jobs.job_started.connect(_on_job_state_changed)
	Jobs.pickup_consumed.connect(_on_pickup_consumed)
	PlayerData.inventory_changed.connect(_on_inventory_changed)
	_update_prompt()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		player = body as CharacterBody3D
		_refresh_offers_if_possible()
		_update_prompt()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		if player == body:
			player = null
		Jobs.clear_offer_pickup(self)
		_update_prompt()

func _exit_tree() -> void:
	UIEvents.unregister_interaction(self)

func _on_job_available() -> void:
	available = true
	mesh_instance.visible = true
	collision_shape.set_deferred("disabled", false)
	_refresh_offers_if_possible()
	_update_prompt()

func _on_job_state_changed(_dropoff: Node3D) -> void:
	_update_prompt()

func _on_inventory_changed() -> void:
	_update_prompt()

func _on_pickup_consumed(pickup: Node3D) -> void:
	if pickup != self:
		return
	available = false
	mesh_instance.visible = false
	collision_shape.set_deferred("disabled", true)
	_update_prompt()

func _can_interact() -> bool:
	if not available:
		return false
	if Jobs.has_active_job() or PlayerData.has_item_id(Jobs.DELIVERY_ITEM_ID):
		return false
	return true

func _update_prompt() -> void:
	var can_show = player_in_range and _can_interact()
	if can_show:
		UIEvents.register_interaction(self)
	else:
		UIEvents.unregister_interaction(self)

func get_interaction_label() -> String:
	return "Browse dispatch offers"

func get_interaction_action() -> String:
	return interact_action

func can_interact() -> bool:
	return _can_interact()

func perform_interaction() -> void:
	if not player_in_range:
		return
	if not _can_interact():
		return
	var can_proceed = await _await_interact_midpoint()
	if not can_proceed:
		return
	_refresh_offers_if_possible()
	UIEvents.request_package_menu(true)

func _refresh_offers_if_possible() -> void:
	if not _can_interact():
		return
	Jobs.refresh_job_offers(self)

func _await_interact_midpoint() -> bool:
	if player == null:
		return true
	if player.has_method("play_interact_and_wait_midpoint"):
		return await player.play_interact_and_wait_midpoint()
	if player.has_method("play_interact_animation"):
		return player.play_interact_animation()
	return true

func get_save_id() -> String:
	return str(get_path())

func to_dict() -> Dictionary:
	return {
		"available": available
	}

func from_dict(data: Dictionary) -> void:
	available = bool(data.get("available", true))
	mesh_instance.visible = available
	collision_shape.set_deferred("disabled", not available)
	_update_prompt()
