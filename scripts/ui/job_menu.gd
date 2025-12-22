extends Panel

@onready var status_label: Label = $PackageMargin/PackageVBox/JobVBox/JobStatus
@onready var dropoff_label: Label = $PackageMargin/PackageVBox/JobVBox/DropoffLabel
@onready var snapshot_rect: TextureRect = $PackageMargin/PackageVBox/JobVBox/SnapshotRect
@onready var hint_label: Label = $PackageMargin/PackageVBox/JobVBox/HintLabel

const NO_JOB_STATUS := "Status: No job"
const ACTIVE_STATUS := "Status: Active"
const AVAILABLE_STATUS := "Status: Job available"
const DROP_OFF_NONE := "Location: --"

func _ready() -> void:
    Jobs.job_started.connect(_on_job_started)
    Jobs.job_completed.connect(_on_job_finished)
    Jobs.job_cancelled.connect(_on_job_finished)
    Jobs.job_available.connect(_on_job_available)
    Jobs.job_snapshot_ready.connect(_on_job_snapshot_ready)
    _refresh()

func _refresh() -> void:
    if Jobs.has_active_job() and Jobs.current_dropoff != null:
        _set_active(Jobs.current_dropoff)
    else:
        _set_idle(NO_JOB_STATUS)

func _set_active(dropoff: Node3D) -> void:
    status_label.text = ACTIVE_STATUS
    dropoff_label.text = "Location: %s" % _get_dropoff_display_name(dropoff)
    hint_label.text = _get_dropoff_hint_text(dropoff)
    snapshot_rect.texture = Jobs.get_active_snapshot()
    snapshot_rect.visible = snapshot_rect.texture != null

func _set_idle(status_text: String) -> void:
    status_label.text = status_text
    dropoff_label.text = DROP_OFF_NONE
    hint_label.text = "Hint: --"
    snapshot_rect.texture = null
    snapshot_rect.visible = false

func _on_job_started(dropoff: Node3D) -> void:
    _set_active(dropoff)

func _on_job_finished() -> void:
    _set_idle(NO_JOB_STATUS)

func _on_job_available() -> void:
    if Jobs.has_active_job():
        return
    _set_idle(AVAILABLE_STATUS)

func _get_dropoff_display_name(dropoff: Node3D) -> String:
    if dropoff is DropoffSite:
        var site := dropoff as DropoffSite
        if site.display_name != "":
            return site.display_name
    return dropoff.name

func _get_dropoff_hint_text(dropoff: Node3D) -> String:
    if dropoff is DropoffSite:
        var site := dropoff as DropoffSite
        if site.hint_text != "":
            return "Hint: %s" % site.hint_text
    var hint_text := Jobs.get_active_hint_text()
    if hint_text != "":
        return "Hint: %s" % hint_text
    return "Hint: --"

func _on_job_snapshot_ready(snapshot: Texture2D) -> void:
    snapshot_rect.texture = snapshot
    snapshot_rect.visible = snapshot != null
