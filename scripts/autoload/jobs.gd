extends Node

signal job_started(dropoff)
signal job_completed
signal job_available
signal job_cancelled

var current_dropoff: Node3D
var has_job: bool = false
@export var reward: int = 20

func start_job(dropoff: Node3D) -> void:
    if has_job:
        return
    current_dropoff = dropoff
    has_job = true
    job_started.emit(dropoff)

func complete_job() -> void:
    if not has_job:
        return
    has_job = false
    current_dropoff = null
    job_completed.emit()
    job_available.emit()

func cancel_job() -> void:
    if not has_job:
        return
    has_job = false
    current_dropoff = null
    job_cancelled.emit()
    job_available.emit()

func has_active_job() -> bool:
    return has_job and current_dropoff != null

func get_dropoff_sites() -> Array[DropoffSite]:
    var sites: Array[DropoffSite] = []
    for node in get_tree().get_nodes_in_group("dropoff_sites"):
        if node is DropoffSite and node.enabled:
            sites.append(node)
    return sites

func assert_dropoffs_available() -> bool:
    if get_dropoff_sites().is_empty():
        UIEvents.show_message("No dropoff sites found.")
        push_error("No dropoff sites found in group 'dropoff_sites'.")
        return false
    return true
