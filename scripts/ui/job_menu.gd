extends Panel

@onready var status_label: Label = $PackageMargin/PackageVBox/JobVBox/JobStatus
@onready var dropoff_label: Label = $PackageMargin/PackageVBox/JobVBox/DropoffLabel
@onready var snapshot_rect: TextureRect = $PackageMargin/PackageVBox/JobVBox/SnapshotRect
@onready var hint_label: Label = $PackageMargin/PackageVBox/JobVBox/HintLabel
@onready var completed_list: ItemList = $PackageMargin/PackageVBox/CompletedSection/CompletedList

const NO_JOB_STATUS := "Status: No job"
const ACTIVE_STATUS := "Status: Active"
const COMPLETED_STATUS := "Status: Completed"
const AVAILABLE_STATUS := "Status: Job available"
const DROP_OFF_NONE := "Location: --"

var override_job: JobRecord

func _ready() -> void:
    Jobs.job_started.connect(_on_job_started)
    Jobs.job_completed.connect(_on_job_completed)
    Jobs.job_available.connect(_on_job_available)
    Jobs.job_snapshot_ready.connect(_on_job_snapshot_ready)
    _configure_snapshot_rect()
    _refresh()
    _refresh_completed_list()

func _refresh() -> void:
    if override_job != null:
        _set_completed(override_job)
        return
    if Jobs.has_active_job() and Jobs.current_dropoff != null:
        _set_active(Jobs.current_dropoff)
        return
    _set_idle(NO_JOB_STATUS)

func _set_active(dropoff: Node3D) -> void:
    status_label.text = ACTIVE_STATUS
    dropoff_label.text = "Location: %s" % _get_dropoff_display_name(dropoff)
    hint_label.text = _get_dropoff_hint_text(dropoff)
    snapshot_rect.texture = Jobs.get_active_snapshot()
    snapshot_rect.visible = snapshot_rect.texture != null

func _set_completed(job: JobRecord) -> void:
    status_label.text = COMPLETED_STATUS
    dropoff_label.text = "Location: %s" % _get_job_display_name(job)
    hint_label.text = _get_job_hint_text(job)
    snapshot_rect.texture = job.snapshot
    snapshot_rect.visible = snapshot_rect.texture != null

func _set_idle(status_text: String) -> void:
    status_label.text = status_text
    dropoff_label.text = DROP_OFF_NONE
    hint_label.text = "Hint: --"
    snapshot_rect.texture = null
    snapshot_rect.visible = false

func _on_job_started(dropoff: Node3D) -> void:
    override_job = null
    _set_active(dropoff)

func _on_job_completed(_job: JobRecord) -> void:
    _refresh_completed_list()

func _on_job_available() -> void:
    if override_job != null:
        return
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
    if override_job != null:
        return
    snapshot_rect.texture = snapshot
    snapshot_rect.visible = snapshot != null

func _configure_snapshot_rect() -> void:
    snapshot_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    snapshot_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    snapshot_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    snapshot_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL

func show_completed_job(job: JobRecord) -> void:
    override_job = job
    if job != null:
        _set_completed(job)

func clear_override() -> void:
    override_job = null
    _refresh()

func _refresh_completed_list() -> void:
    completed_list.clear()
    for job in Jobs.get_completed_jobs():
        var label := "%s" % _get_job_display_name(job)
        var icon := job.snapshot
        completed_list.add_item(label, icon)
        var index := completed_list.get_item_count() - 1
        completed_list.set_item_tooltip(index, _get_job_hint_text(job))
        completed_list.set_item_metadata(index, job)

func _get_job_display_name(job: JobRecord) -> String:
    if job == null:
        return "--"
    if job.display_name != "":
        return job.display_name
    return "--"

func _get_job_hint_text(job: JobRecord) -> String:
    if job == null:
        return "Hint: --"
    if job.hint_text != "":
        return "Hint: %s" % job.hint_text
    return "Hint: --"
