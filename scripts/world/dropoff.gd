extends Area3D

@export var reward: int = 20
@export var interact_action: String = "interact"

var player_in_range: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	Jobs.job_started.connect(_on_job_state_changed)
	Jobs.job_completed.connect(_on_job_state_changed)
	Jobs.job_cancelled.connect(_on_job_state_changed)
	PlayerData.carrying_changed.connect(_on_carrying_changed)
	_update_prompt()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		_update_prompt()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		_update_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if not player_in_range:
		return
	if not event.is_action_pressed(interact_action):
		return
	if not _can_interact():
		return
	_deliver()
	get_viewport().set_input_as_handled()

func _can_interact() -> bool:
	if not Jobs.has_active_job():
		return false
	if Jobs.current_dropoff != self:
		return false
	if not PlayerData.is_carrying():
		return false
	return true

func _deliver() -> void:
	PlayerData.clear_carrying()
	PlayerData.add_money(reward)
	Jobs.complete_job()
	UIEvents.show_message("Delivered! +$%d" % reward)
	_update_prompt()

func _on_job_state_changed(_dropoff: Node3D = null) -> void:
	_update_prompt()

func _on_carrying_changed(_item_name: String) -> void:
	_update_prompt()

func _update_prompt() -> void:
	var can_show := player_in_range and _can_interact()
	UIEvents.set_interact_prompt(can_show, interact_action, self)
