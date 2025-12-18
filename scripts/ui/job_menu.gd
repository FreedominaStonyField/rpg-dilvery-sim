extends Panel

@onready var status_label: Label = $JobVBox/JobStatus
@onready var dropoff_label: Label = $JobVBox/DropoffLabel

const NO_JOB_STATUS := "Status: No job"
const ACTIVE_STATUS := "Status: Active"
const AVAILABLE_STATUS := "Status: Job available"
const DROP_OFF_NONE := "Dropoff: --"

func _ready() -> void:
    Jobs.job_started.connect(_on_job_started)
    Jobs.job_completed.connect(_on_job_finished)
    Jobs.job_cancelled.connect(_on_job_finished)
    Jobs.job_available.connect(_on_job_available)
    _refresh()

func _refresh() -> void:
    if Jobs.has_active_job() and Jobs.current_dropoff != null:
        _set_active(Jobs.current_dropoff)
    else:
        _set_idle(NO_JOB_STATUS)

func _set_active(dropoff: Node3D) -> void:
    status_label.text = ACTIVE_STATUS
    dropoff_label.text = "Dropoff: %s" % dropoff.name

func _set_idle(status_text: String) -> void:
    status_label.text = status_text
    dropoff_label.text = DROP_OFF_NONE

func _on_job_started(dropoff: Node3D) -> void:
    _set_active(dropoff)

func _on_job_finished() -> void:
    _set_idle(NO_JOB_STATUS)

func _on_job_available() -> void:
    if Jobs.has_active_job():
        return
    _set_idle(AVAILABLE_STATUS)
