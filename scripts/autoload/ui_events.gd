extends Node

signal notify(message: String, duration: float)
signal sleep_sequence_requested(message: String)
signal interact_prompt_changed(visible: bool, action: String, owner_id: int)
signal interaction_registered(node: Node)
signal interaction_unregistered(node: Node)
signal package_menu_requested(visible: bool)

func show_message(message: String, duration: float = 2.0) -> void:
	notify.emit(message, duration)

func request_sleep_sequence(message: String = "You got a good night's sleep.") -> void:
	sleep_sequence_requested.emit(message)

func set_interact_prompt(visible: bool, action: String = "interact", owner: Node = null) -> void:
	var owner_id = 0
	if owner != null:
		owner_id = owner.get_instance_id()
	interact_prompt_changed.emit(visible, action, owner_id)

func register_interaction(node: Node) -> void:
	if node == null:
		return
	interaction_registered.emit(node)

func unregister_interaction(node: Node) -> void:
	if node == null:
		return
	interaction_unregistered.emit(node)

func request_package_menu(visible: bool) -> void:
	package_menu_requested.emit(visible)
