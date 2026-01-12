extends Area3D

@export var pass_cost: int = 5000
@export var interact_action: String = "interact"
@export var win_scene_path: String = "res://scenes/ui/WinScreen.tscn"

var player_in_range: bool = false
var player: CharacterBody3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_prompt()

func _exit_tree() -> void:
	UIEvents.unregister_interaction(self)

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

func _update_prompt() -> void:
	if player_in_range:
		UIEvents.register_interaction(self)
	else:
		UIEvents.unregister_interaction(self)

func get_interaction_label() -> String:
	return "Buy City Pass ($%d)" % pass_cost

func get_interaction_action() -> String:
	return interact_action

func can_interact() -> bool:
	return player_in_range

func perform_interaction() -> void:
	if not player_in_range:
		return
	var can_proceed = await _await_interact_midpoint()
	if not can_proceed:
		return
	if PlayerData.get_money() < pass_cost:
		UIEvents.show_message("City Pass costs $%d." % pass_cost)
		return
	if not PlayerData.spend_money(pass_cost):
		UIEvents.show_message("Not enough gold for the City Pass.")
		return
	UIEvents.show_message("City Pass purchased.")
	_start_win_sequence()

func _await_interact_midpoint() -> bool:
	if player == null:
		return true
	if player.has_method("play_interact_and_wait_midpoint"):
		return await player.play_interact_and_wait_midpoint()
	if player.has_method("play_interact_animation"):
		return player.play_interact_animation()
	return true

func _start_win_sequence() -> void:
	GameState.set_mode(GameState.Mode.MENU)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	get_tree().change_scene_to_file(win_scene_path)
