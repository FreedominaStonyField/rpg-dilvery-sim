extends Area3D

@export var reward: int = 20

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
    if not body.is_in_group("player"):
        return
    if not Jobs.has_active_job():
        return
    if Jobs.current_dropoff != self:
        return
    if not PlayerData.is_carrying():
        return
    PlayerData.clear_carrying()
    PlayerData.add_money(reward)
    Jobs.complete_job()
    UIEvents.show_message("Delivered! +$%d" % reward)
