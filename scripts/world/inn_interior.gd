extends Node3D

@export var sleep_action: String = "interact"
@export var sleep_cost: int = 20
@export_range(0.0, 1.0) var sleep_threshold: float = 0.75

@onready var safe_area: Area3D = $SafeArea
@onready var sleep_spot: Area3D = $SafeArea/SleepSpot

var can_sleep: bool = false

func _ready() -> void:
	safe_area.body_entered.connect(_on_safe_entered)
	safe_area.body_exited.connect(_on_safe_exited)
	sleep_spot.body_entered.connect(_on_sleep_entered)
	sleep_spot.body_exited.connect(_on_sleep_exited)

func _on_safe_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	TimeSystem.set_outdoors(false)
	UIEvents.show_message("Inside inn.")

func _on_safe_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	TimeSystem.set_outdoors(true)
	can_sleep = false

func _on_sleep_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	can_sleep = true
	UIEvents.show_message("Press E to sleep until morning.")

func _on_sleep_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	can_sleep = false

func _unhandled_input(event: InputEvent) -> void:
	if not can_sleep:
		return
	if event.is_action_pressed(sleep_action):
		_sleep_until_morning()

func _sleep_until_morning() -> void:
	var ratio := TimeSystem.get_time_ratio()
	if ratio <= sleep_threshold:
		UIEvents.show_message("It's too early to sleep.")
		return
	if not PlayerData.spend_money(sleep_cost):
		UIEvents.show_message("Not enough money to sleep!")
		return
	UIEvents.show_message("Paid %d gold for a room." % sleep_cost)
	UIEvents.request_sleep_sequence("You got a good night's sleep.")
