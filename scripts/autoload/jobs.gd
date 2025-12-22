extends Node

signal job_started(dropoff)
signal job_completed(job: JobRecord)
signal job_available
signal job_snapshot_ready(snapshot: Texture2D)

var current_dropoff: Node3D
var has_job: bool = false
@export var reward: int = 20
@export var default_completion_sfx: AudioStream = preload("res://assets/audio/ui/bong_001.ogg")
var active_job: JobRecord
var completed_jobs: Array[JobRecord] = []
var last_completed_job: JobRecord

func start_job(dropoff: Node3D) -> void:
	if has_job:
		return
	current_dropoff = dropoff
	has_job = true
	active_job = _build_job_record(dropoff)
	if dropoff is DropoffSite:
		var site := dropoff as DropoffSite
		if site.snapshot_enabled:
			call_deferred("_start_snapshot_capture", site)
	job_started.emit(dropoff)

func complete_job() -> void:
	if not has_job:
		return
	var completed_record := active_job
	has_job = false
	current_dropoff = null
	active_job = null
	if completed_record != null:
		completed_jobs.append(completed_record)
		last_completed_job = completed_record
		job_completed.emit(completed_record)
	job_available.emit()

func clear_active_job() -> void:
	if not has_job:
		return
	has_job = false
	current_dropoff = null
	active_job = null
	job_available.emit()

func has_active_job() -> bool:
	return has_job and current_dropoff != null

func get_active_hint_text() -> String:
	if active_job != null:
		return active_job.hint_text
	return ""

func get_active_snapshot() -> Texture2D:
	if active_job != null:
		return active_job.snapshot
	return null

func get_completed_jobs() -> Array[JobRecord]:
	return completed_jobs

func get_last_completed_job() -> JobRecord:
	return last_completed_job

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

func _capture_snapshot_for_dropoff(site: DropoffSite) -> void:
	if not has_job or current_dropoff != site:
		return
	var snapshot := await site.capture_snapshot()
	if snapshot == null:
		return
	if not has_job or current_dropoff != site:
		return
	if active_job != null:
		active_job.snapshot = snapshot
	job_snapshot_ready.emit(snapshot)

func _start_snapshot_capture(site: DropoffSite) -> void:
	await _capture_snapshot_for_dropoff(site)

func _build_job_record(dropoff: Node3D) -> JobRecord:
	var record := JobRecord.new()
	record.display_name = dropoff.name
	record.completion_sfx = default_completion_sfx
	if dropoff is DropoffSite:
		var site := dropoff as DropoffSite
		record.site_id = site.site_id
		if site.display_name != "":
			record.display_name = site.display_name
		record.hint_text = site.hint_text
		record.completion_sfx = site.completion_sfx if site.completion_sfx != null else default_completion_sfx
	return record
