extends Node

signal job_started(dropoff)
signal job_completed
signal job_available
signal job_cancelled
signal job_snapshot_ready(snapshot: Texture2D)

var current_dropoff: Node3D
var has_job: bool = false
@export var reward: int = 20
var active_job: Dictionary = {}

func start_job(dropoff: Node3D) -> void:
	if has_job:
		return
	current_dropoff = dropoff
	has_job = true
	active_job = {
		"dropoff": dropoff,
		"hint_text": "",
		"snapshot": null
	}
	if dropoff is DropoffSite:
		var site := dropoff as DropoffSite
		active_job["hint_text"] = site.hint_text
		if site.snapshot_enabled:
			call_deferred("_start_snapshot_capture", site)
	job_started.emit(dropoff)

func complete_job() -> void:
	if not has_job:
		return
	has_job = false
	current_dropoff = null
	active_job.clear()
	job_completed.emit()
	job_available.emit()

func cancel_job() -> void:
	if not has_job:
		return
	has_job = false
	current_dropoff = null
	active_job.clear()
	job_cancelled.emit()
	job_available.emit()

func has_active_job() -> bool:
	return has_job and current_dropoff != null

func get_active_hint_text() -> String:
	if active_job.has("hint_text"):
		return active_job["hint_text"]
	return ""

func get_active_snapshot() -> Texture2D:
	if active_job.has("snapshot"):
		return active_job["snapshot"]
	return null

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
	active_job["snapshot"] = snapshot
	job_snapshot_ready.emit(snapshot)

func _start_snapshot_capture(site: DropoffSite) -> void:
	await _capture_snapshot_for_dropoff(site)
