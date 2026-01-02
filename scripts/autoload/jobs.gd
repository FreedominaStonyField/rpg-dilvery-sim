extends Node

signal job_started(dropoff)
signal job_completed(job: JobRecord)
signal job_available
signal job_snapshot_ready(snapshot: Texture2D)
signal job_offers_updated
signal pickup_consumed(pickup: Node3D)
signal jobs_restored

var current_dropoff: Node3D
var has_job: bool = false
@export var offer_count: int = 3
@export var base_reward: int = 12
@export var reward_per_meter: float = 0.4
@export var min_reward: int = 8
@export var max_reward: int = 120
@export var default_completion_sfx: AudioStream = preload("res://assets/audio/ui/bong_001.ogg")
var active_job: JobRecord
var completed_jobs: Array[JobRecord] = []
var last_completed_job: JobRecord
var job_offers: Array[Dictionary] = []
var offer_pickup: Node3D
var offer_generation: int = 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func start_job(dropoff: Node3D, record: JobRecord = null) -> void:
	if has_job:
		return
	current_dropoff = dropoff
	has_job = true
	active_job = record if record != null else _build_job_record(dropoff)
	if active_job.reward <= 0:
		var distance_m = 0.0
		if offer_pickup != null:
			distance_m = offer_pickup.global_position.distance_to(dropoff.global_position)
		active_job.reward = _calculate_reward(distance_m)
		active_job.distance_m = distance_m
	_clear_job_offers()
	if dropoff is DropoffSite:
		var site = dropoff as DropoffSite
		if site.snapshot_enabled and active_job.snapshot == null:
			call_deferred("_start_snapshot_capture", site)
	job_started.emit(dropoff)

func complete_job() -> void:
	if not has_job:
		return
	var completed_record = active_job
	has_job = false
	current_dropoff = null
	active_job = null
	if completed_record != null:
		completed_jobs.append(completed_record)
		last_completed_job = completed_record
		job_completed.emit(completed_record)
	job_available.emit()
	_clear_job_offers()

func clear_active_job() -> void:
	if not has_job:
		return
	has_job = false
	current_dropoff = null
	active_job = null
	job_available.emit()
	_clear_job_offers()

func has_active_job() -> bool:
	return has_job and current_dropoff != null

func get_active_reward() -> int:
	if active_job == null:
		return 0
	return active_job.reward

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

func get_job_offer_records() -> Array[JobRecord]:
	var records: Array[JobRecord] = []
	for offer in job_offers:
		var record = offer.get("record") as JobRecord
		if record != null:
			records.append(record)
	return records

func has_job_offers() -> bool:
	return not job_offers.is_empty()

func refresh_job_offers(pickup: Node3D) -> void:
	if pickup == null:
		_clear_job_offers()
		return
	if has_active_job():
		_clear_job_offers()
		return
	if PlayerData.is_carrying():
		_clear_job_offers()
		return
	offer_pickup = pickup
	var dropoffs = get_dropoff_sites()
	if dropoffs.is_empty():
		_clear_job_offers()
		return
	offer_generation += 1
	var generation = offer_generation
	job_offers.clear()
	var candidates: Array[DropoffSite] = dropoffs.duplicate()
	var count = clamp(offer_count, 1, candidates.size())
	for _i in range(count):
		var index = rng.randi_range(0, candidates.size() - 1)
		var site = candidates[index]
		candidates.remove_at(index)
		var distance_m = pickup.global_position.distance_to(site.global_position)
		var reward_amount = _calculate_reward(distance_m)
		var record = _build_job_record(site, reward_amount, distance_m)
		job_offers.append({
			"dropoff": site,
			"record": record
		})
	job_offers_updated.emit()
	_capture_offer_snapshots(generation)

func accept_job_offer(index: int) -> bool:
	if has_active_job():
		return false
	if index < 0 or index >= job_offers.size():
		return false
	var offer = job_offers[index]
	var dropoff = offer.get("dropoff") as Node3D
	var record = offer.get("record") as JobRecord
	if dropoff == null or record == null:
		return false
	var pickup = offer_pickup
	start_job(dropoff, record)
	offer_pickup = null
	if pickup != null:
		pickup_consumed.emit(pickup)
	return true

func clear_offer_pickup(pickup: Node3D) -> void:
	if pickup == null:
		return
	if offer_pickup == pickup:
		offer_pickup = null
		_clear_job_offers()

func assert_dropoffs_available() -> bool:
	if get_dropoff_sites().is_empty():
		UIEvents.show_message("No dropoff sites found.")
		push_error("No dropoff sites found in group 'dropoff_sites'.")
		return false
	return true

func _capture_snapshot_for_dropoff(site: DropoffSite) -> void:
	if not has_job or current_dropoff != site:
		return
	var snapshot = await site.capture_snapshot()
	if snapshot == null:
		return
	if not has_job or current_dropoff != site:
		return
	if active_job != null:
		active_job.snapshot = snapshot
		active_job.cache_snapshot()
	job_snapshot_ready.emit(snapshot)

func _start_snapshot_capture(site: DropoffSite) -> void:
	await _capture_snapshot_for_dropoff(site)

func _build_job_record(dropoff: Node3D, reward_amount: int = 0, distance_m: float = 0.0) -> JobRecord:
	var record = JobRecord.new()
	record.display_name = dropoff.name
	record.completion_sfx = default_completion_sfx
	record.reward = reward_amount
	record.distance_m = distance_m
	if dropoff is DropoffSite:
		var site = dropoff as DropoffSite
		record.site_id = site.site_id
		if site.display_name != "":
			record.display_name = site.display_name
		record.hint_text = site.hint_text
		record.completion_sfx = site.completion_sfx if site.completion_sfx != null else default_completion_sfx
	return record

func _calculate_reward(distance_m: float) -> int:
	var value = base_reward + int(round(distance_m * reward_per_meter))
	return clamp(value, min_reward, max_reward)

func _capture_offer_snapshots(generation: int) -> void:
	for offer in job_offers:
		if generation != offer_generation:
			return
		var site = offer.get("dropoff") as DropoffSite
		if site == null or not site.snapshot_enabled:
			continue
		var snapshot = await site.capture_snapshot()
		if generation != offer_generation:
			return
		if snapshot == null:
			continue
		var record = offer.get("record") as JobRecord
		if record == null:
			continue
		record.snapshot = snapshot
		record.cache_snapshot()
		job_offers_updated.emit()

func _clear_job_offers() -> void:
	offer_generation += 1
	job_offers.clear()
	job_offers_updated.emit()

func to_dict() -> Dictionary:
	var completed: Array = []
	for job in completed_jobs:
		completed.append(_serialize_job_record(job))
	var active_data: Dictionary = {}
	if active_job != null:
		active_data = _serialize_job_record(active_job)
	return {
		"has_job": has_job,
		"current_site_id": _get_current_site_id(),
		"active_job": active_data,
		"completed_jobs": completed
	}

func from_dict(data: Dictionary) -> void:
	var requested_has_job = bool(data.get("has_job", false))
	var site_id = str(data.get("current_site_id", ""))
	current_dropoff = _resolve_dropoff_by_site_id(site_id)
	var active_data = data.get("active_job", {})
	active_job = null
	if typeof(active_data) == TYPE_DICTIONARY and not active_data.is_empty():
		active_job = _deserialize_job_record(active_data)
	completed_jobs.clear()
	var completed_data = data.get("completed_jobs", [])
	if typeof(completed_data) == TYPE_ARRAY:
		for entry in completed_data:
			if typeof(entry) == TYPE_DICTIONARY:
				completed_jobs.append(_deserialize_job_record(entry))
	last_completed_job = completed_jobs.back() if not completed_jobs.is_empty() else null
	has_job = requested_has_job and current_dropoff != null and active_job != null
	if has_job:
		job_started.emit(current_dropoff)
	else:
		current_dropoff = null
		active_job = null
		job_available.emit()
	jobs_restored.emit()

func _get_current_site_id() -> String:
	if current_dropoff is DropoffSite:
		return String((current_dropoff as DropoffSite).site_id)
	if current_dropoff != null:
		return current_dropoff.name
	return ""

func _resolve_dropoff_by_site_id(site_id: String) -> Node3D:
	if site_id == "":
		return null
	for node in get_tree().get_nodes_in_group("dropoff_sites"):
		var site = node as DropoffSite
		if site == null:
			continue
		if String(site.site_id) == site_id or site.name == site_id:
			return site
	return null

func _serialize_job_record(record: JobRecord) -> Dictionary:
	var snapshot_data = ""
	if record.snapshot_jpg_b64 != "":
		snapshot_data = record.snapshot_jpg_b64
	var sfx_path = ""
	if record.completion_sfx != null and record.completion_sfx.resource_path != "":
		sfx_path = record.completion_sfx.resource_path
	return {
		"site_id": String(record.site_id),
		"display_name": record.display_name,
		"hint_text": record.hint_text,
		"reward": record.reward,
		"distance_m": record.distance_m,
		"completion_sfx_path": sfx_path,
		"snapshot_jpg": snapshot_data
	}

func _deserialize_job_record(data: Dictionary) -> JobRecord:
	var record = JobRecord.new()
	record.site_id = StringName(str(data.get("site_id", "")))
	record.display_name = str(data.get("display_name", ""))
	record.hint_text = str(data.get("hint_text", ""))
	record.reward = int(data.get("reward", 0))
	record.distance_m = float(data.get("distance_m", 0.0))
	var sfx_path = str(data.get("completion_sfx_path", ""))
	if sfx_path != "":
		record.completion_sfx = load(sfx_path) as AudioStream
	var snapshot_data = str(data.get("snapshot_jpg", ""))
	if snapshot_data == "":
		snapshot_data = str(data.get("snapshot_png", ""))
	if snapshot_data != "":
		var buffer = Marshalls.base64_to_raw(snapshot_data)
		var image = Image.new()
		var result = image.load_jpg_from_buffer(buffer)
		if result != OK:
			result = image.load_png_from_buffer(buffer)
		if result == OK:
			record.snapshot = ImageTexture.create_from_image(image)
			record.snapshot_jpg_b64 = str(data.get("snapshot_jpg", ""))
			if record.snapshot_jpg_b64 == "":
				record.cache_snapshot()
	return record
