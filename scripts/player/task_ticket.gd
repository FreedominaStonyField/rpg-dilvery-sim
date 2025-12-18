extends Node

class_name TaskTicket

signal ticket_updated(item_name: String, recipient_name: String)
signal ticket_cleared

var item_name: String = ""
var recipient_name: String = ""
var dropoff_ref: Node3D = null

func _ready() -> void:
    Jobs.job_started.connect(_on_job_started)
    Jobs.job_completed.connect(_on_job_finished)
    Jobs.job_cancelled.connect(_on_job_finished)
    PlayerData.carrying_changed.connect(_on_carrying_changed)

func has_ticket() -> bool:
    return item_name != "" and recipient_name != ""

func get_details() -> Dictionary:
    return {
        "item_name": item_name,
        "recipient_name": recipient_name,
        "dropoff": dropoff_ref
    }

func _on_job_started(dropoff: Node3D) -> void:
    dropoff_ref = dropoff
    recipient_name = dropoff.name
    if PlayerData.is_carrying():
        item_name = PlayerData.carrying_item
    _emit_update()

func _on_carrying_changed(carrying: String) -> void:
    item_name = carrying
    if not Jobs.has_active_job() and carrying == "":
        _clear_ticket()
        return
    _emit_update()

func _on_job_finished() -> void:
    _clear_ticket()

func _emit_update() -> void:
    if has_ticket():
        ticket_updated.emit(item_name, recipient_name)

func _clear_ticket() -> void:
    if item_name == "" and recipient_name == "" and dropoff_ref == null:
        return
    item_name = ""
    recipient_name = ""
    dropoff_ref = null
    ticket_cleared.emit()
