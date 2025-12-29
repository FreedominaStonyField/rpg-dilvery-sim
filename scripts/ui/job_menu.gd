extends PanelContainer

@onready var status_value: Label = $PackageMargin/PackageVBox/InfoBlock/InfoMargin/InfoVBox/InfoGrid/StatusValue
@onready var location_value: Label = $PackageMargin/PackageVBox/InfoBlock/InfoMargin/InfoVBox/InfoGrid/LocationValue
@onready var note_value: Label = $PackageMargin/PackageVBox/InfoBlock/InfoMargin/InfoVBox/InfoGrid/NoteValue
@onready var snapshot_rect: TextureRect = $PackageMargin/PackageVBox/SnapshotBlock/SnapshotMargin/SnapshotVBox/SnapshotRect
@onready var no_active_block: Control = $PackageMargin/PackageVBox/InfoBlock/InfoMargin/InfoVBox/NoActiveBlock
@onready var completed_list: ItemList = $PackageMargin/PackageVBox/CompletedBlock/CompletedMargin/CompletedVBox/CompletedList
@onready var completed_empty: Label = $PackageMargin/PackageVBox/CompletedBlock/CompletedMargin/CompletedVBox/CompletedEmpty

const NO_JOB_STATUS = "NO ACTIVE JOB"
const ACTIVE_STATUS = "ACTIVE"
const COMPLETED_STATUS = "COMPLETED"
const AVAILABLE_STATUS = "JOB AVAILABLE"
const DROP_OFF_NONE = "--"
const NOTE_NONE = "--"

var override_job: JobRecord

func _ready() -> void:
	Jobs.job_started.connect(_on_job_started)
	Jobs.job_completed.connect(_on_job_completed)
	Jobs.job_available.connect(_on_job_available)
	Jobs.job_snapshot_ready.connect(_on_job_snapshot_ready)
	Jobs.jobs_restored.connect(_on_jobs_restored)
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
	status_value.text = ACTIVE_STATUS
	location_value.text = _get_dropoff_display_name(dropoff)
	note_value.text = _get_dropoff_note_text(dropoff)
	snapshot_rect.texture = Jobs.get_active_snapshot()
	snapshot_rect.visible = snapshot_rect.texture != null
	_set_no_active_visible(false)

func _set_completed(job: JobRecord) -> void:
	status_value.text = COMPLETED_STATUS
	location_value.text = _get_job_display_name(job)
	note_value.text = _get_job_note_text(job)
	snapshot_rect.texture = job.snapshot
	snapshot_rect.visible = snapshot_rect.texture != null
	_set_no_active_visible(false)

func _set_idle(status_text: String) -> void:
	status_value.text = status_text
	location_value.text = DROP_OFF_NONE
	note_value.text = NOTE_NONE
	snapshot_rect.texture = null
	snapshot_rect.visible = false
	_set_no_active_visible(true)

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
		var site = dropoff as DropoffSite
		if site.display_name != "":
			return site.display_name
	return dropoff.name

func _get_dropoff_note_text(dropoff: Node3D) -> String:
	if dropoff is DropoffSite:
		var site = dropoff as DropoffSite
		if site.hint_text != "":
			return site.hint_text
	var hint_text = Jobs.get_active_hint_text()
	if hint_text != "":
		return hint_text
	return NOTE_NONE

func _on_job_snapshot_ready(snapshot: Texture2D) -> void:
	if override_job != null:
		return
	snapshot_rect.texture = snapshot
	snapshot_rect.visible = snapshot != null

func _on_jobs_restored() -> void:
	_refresh()
	_refresh_completed_list()

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
		var label = "%s  [COMPLETED]" % _get_job_display_name(job)
		var icon = job.snapshot
		completed_list.add_item(label, icon)
		var index = completed_list.get_item_count() - 1
		completed_list.set_item_tooltip(index, _get_job_tooltip(job))
		completed_list.set_item_metadata(index, job)
	_update_completed_empty()

func _get_job_display_name(job: JobRecord) -> String:
	if job == null:
		return "--"
	if job.display_name != "":
		return job.display_name
	return "--"

func _get_job_note_text(job: JobRecord) -> String:
	if job == null:
		return NOTE_NONE
	if job.hint_text != "":
		return job.hint_text
	return NOTE_NONE

func _get_job_tooltip(job: JobRecord) -> String:
	var note = _get_job_note_text(job)
	if note == NOTE_NONE:
		return "NOTE: --"
	return "NOTE: %s" % note

func _set_no_active_visible(visible: bool) -> void:
	if no_active_block:
		no_active_block.visible = visible

func _update_completed_empty() -> void:
	if completed_empty:
		completed_empty.visible = completed_list.get_item_count() == 0
