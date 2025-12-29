extends Node3D

@export var kill_plane_path: NodePath = NodePath("KillPlane")

@onready var kill_plane: Area3D = get_node_or_null(kill_plane_path) as Area3D

var player: CharacterBody3D
var respawn_transform: Transform3D
var last_safe_transform: Transform3D

func _ready() -> void:
	GameState.set_mode(GameState.Mode.PLAYING)
	GameState.mode_changed.connect(_on_mode_changed)
	TimeSystem.set_outdoors(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	UIEvents.show_message("Pick up the parcel and deliver it before curfew.")
	_bind_player()
	_bind_kill_plane()
	_bind_safe_respawn_areas()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("unstuck") and GameState.is_playing():
		_respawn_player("Unstuck used. Returning to the inn.")

func _on_mode_changed(mode: GameState.Mode) -> void:
	if mode == GameState.Mode.PAUSED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif mode == GameState.Mode.PLAYING:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _bind_player() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null:
		return

func _bind_kill_plane() -> void:
	if kill_plane == null:
		return
	kill_plane.body_entered.connect(_on_kill_plane_body_entered)

func _bind_safe_respawn_areas() -> void:
	for area in get_tree().get_nodes_in_group("safe_respawn"):
		if area is Area3D:
			area.body_entered.connect(_on_safe_respawn_entered.bind(area))
	if last_safe_transform == Transform3D():
		_set_respawn_from_inn()

func _set_respawn_from_inn() -> void:
	var inn = get_node_or_null("town cisco /Inn") as Node3D
	if inn == null:
		return
	var respawn_marker = inn.get_node_or_null("SafeArea/RespawnPoint") as Node3D
	if respawn_marker:
		respawn_transform = respawn_marker.global_transform
		last_safe_transform = respawn_transform
	else:
		respawn_transform = inn.global_transform
		last_safe_transform = respawn_transform

func _on_safe_respawn_entered(body: Node3D, area: Area3D) -> void:
	if not body.is_in_group("player"):
		return
	var marker = area.get_node_or_null("RespawnPoint") as Node3D
	if marker:
		last_safe_transform = marker.global_transform
		return
	last_safe_transform = area.global_transform

func _on_kill_plane_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_respawn_player("You fell out of bounds. Returning to the inn.")

func _respawn_player(message: String) -> void:
	if player == null:
		_bind_player()
	if player == null:
		return
	var target = last_safe_transform
	if target == Transform3D():
		_set_respawn_from_inn()
		target = respawn_transform
	player.velocity = Vector3.ZERO
	player.global_transform = target
	UIEvents.show_message(message)
