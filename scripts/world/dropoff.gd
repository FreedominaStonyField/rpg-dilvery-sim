extends Area3D

@export var reward: int = 20
@export var interact_action: String = "interact"
@export var dropoff_site_path: NodePath

var player_in_range: bool = false
var player: CharacterBody3D
var dropoff_site: DropoffSite

func _ready() -> void:
	_resolve_dropoff_site()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	Jobs.job_started.connect(_on_job_state_changed)
	Jobs.job_completed.connect(_on_job_state_changed)
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

func _exit_tree() -> void:
	UIEvents.unregister_interaction(self)

func _can_interact() -> bool:
	if not Jobs.has_active_job():
		return false
	if not _matches_current_dropoff():
		return false
	if not PlayerData.is_carrying():
		return false
	return true

func _deliver() -> void:
	PlayerData.clear_carrying()
	var reward_amount = Jobs.get_active_reward()
	if reward_amount <= 0:
		reward_amount = reward
	PlayerData.add_money(reward_amount)
	Jobs.complete_job()
	UIEvents.show_message("Delivered! +$%d" % reward_amount)
	_update_prompt()

func _on_job_state_changed(_payload = null) -> void:
	_update_prompt()

func _on_carrying_changed(_item_name: String) -> void:
	_update_prompt()

func _update_prompt() -> void:
	var can_show = player_in_range and _can_interact()
	if can_show:
		UIEvents.register_interaction(self)
	else:
		UIEvents.unregister_interaction(self)

func get_interaction_label() -> String:
	if dropoff_site != null and dropoff_site.display_name != "":
		return "Deliver to %s" % dropoff_site.display_name
	if dropoff_site != null:
		return "Deliver to %s" % dropoff_site.name
	return "Deliver package"

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
	_deliver()

func _await_interact_midpoint() -> bool:
	if player == null:
		return true
	if player.has_method("play_interact_and_wait_midpoint"):
		return await player.play_interact_and_wait_midpoint()
	if player.has_method("play_interact_animation"):
		return player.play_interact_animation()
	return true

func _resolve_dropoff_site() -> void:
	var site: DropoffSite = null
	if dropoff_site_path != NodePath():
		site = get_node_or_null(dropoff_site_path) as DropoffSite
	elif get_parent() is DropoffSite:
		site = get_parent() as DropoffSite
	dropoff_site = site

func _matches_current_dropoff() -> bool:
	if dropoff_site != null:
		return Jobs.current_dropoff == dropoff_site
	return Jobs.current_dropoff == self
