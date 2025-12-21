extends Area3D

@export var dropoff_paths: Array[NodePath] = []
@export var item_name: String = "Parcel"
@export var interact_action: String = "interact"

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var available: bool = true
var dropoffs: Array[Node3D] = []
var last_dropoff: Node3D
var rng := RandomNumberGenerator.new()
var player_in_range: bool = false
var player: CharacterBody3D

func _ready() -> void:
	rng.randomize()
	for path in dropoff_paths:
		var dropoff := get_node_or_null(path)
		if dropoff:
			dropoffs.append(dropoff)
	if dropoffs.is_empty():
		push_warning("Pickup missing dropoff references.")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	Jobs.job_available.connect(_on_job_available)
	Jobs.job_started.connect(_on_job_state_changed)
	PlayerData.carrying_changed.connect(_on_carrying_changed)
	_update_prompt()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		player = body as CharacterBody3D
		_update_prompt()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		if player == body:
			player = null
		_update_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if not player_in_range:
		return
	if not event.is_action_pressed(interact_action):
		return
	if not _can_interact():
		return
	_request_interact_animation()
	_try_pickup()
	get_viewport().set_input_as_handled()

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
	_update_prompt()

func _on_job_state_changed(_dropoff: Node3D) -> void:
	_update_prompt()

func _on_carrying_changed(_item_name: String) -> void:
	_update_prompt()

func _can_interact() -> bool:
	if not available:
		return false
	if Jobs.has_active_job() or PlayerData.is_carrying():
		return false
	return true

func _try_pickup() -> void:
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
	_update_prompt()

func _update_prompt() -> void:
	var can_show := player_in_range and _can_interact()
	UIEvents.set_interact_prompt(can_show, interact_action, self)

func _request_interact_animation() -> void:
	if player == null:
		return
	if player.has_method("play_interact_animation"):
		player.play_interact_animation()
