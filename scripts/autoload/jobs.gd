extends Node

signal job_started(dropoff)
signal job_completed(job: JobRecord)
signal job_available
signal job_snapshot_ready(snapshot: Texture2D)
signal job_offers_updated
signal pickup_consumed(pickup: Node3D)
signal jobs_restored

const DELIVERY_ITEM_NAME = "Package"

var current_dropoff: Node3D
@export var offer_count: int = 3
@export var base_reward: int = 90
@export var reward_per_meter: float = 0.6
@export var min_reward: int = 80
@export var max_reward: int = 160
@export var default_completion_sfx: AudioStream = preload("res://assets/audio/ui/bong_001.ogg")
var completed_jobs: Array[JobRecord] = []
var last_completed_job: JobRecord
var job_offers: Array[Dictionary] = []
var offer_pickup: Node3D
var offer_generation: int = 0
var rng := RandomNumberGenerator.new()
var active_record: JobRecord

func _ready() -> void:
	rng.randomize()

func start_job(dropoff: Node3D, record: JobRecord = null) -> void:
	if has_active_job():
		return
	current_dropoff = dropoff
	active_record = record if record != null else _build_job_record(dropoff)
	if active_record.reward <= 0:
		var distance_m = 0.0
		if offer_pickup != null:
			distance_m = offer_pickup.global_position.distance_to(dropoff.global_position)
		active_record.reward = _calculate_reward(distance_m)
		active_record.distance_m = distance_m
	_clear_job_offers()
	if dropoff is DropoffSite:
		var site = dropoff as DropoffSite
		if site.snapshot_enabled and active_record.snapshot == null:
			call_deferred("_start_snapshot_capture", site)
	_set_carrying_state(true)
	job_started.emit(dropoff)

func complete_job() -> int:
	if not has_active_job():
		return 0
	var completed_record = active_record
	var reward_amount = 0
	if completed_record != null:
		reward_amount = completed_record.reward
		PlayerData.add_money(reward_amount)
	if completed_record != null:
		completed_jobs.append(completed_record)
		last_completed_job = completed_record
		job_completed.emit(completed_record)
	_clear_active_job_state()
	job_available.emit()
	_clear_job_offers()
	return reward_amount

func clear_active_job() -> void:
	if not has_active_job():
		return
	_clear_active_job_state()
	job_available.emit()
	_clear_job_offers()

func has_active_job() -> bool:
	return current_dropoff != null and active_record != null

func get_active_reward() -> int:
	if active_record == null:
		return 0
	return active_record.reward

func get_active_hint_text() -> String:
	if active_record == null:
		return ""
	return active_record.hint_text

func get_active_snapshot() -> Texture2D:
	return active_record.snapshot if active_record != null else null

func get_completed_jobs() -> Array[JobRecord]:
	return completed_jobs

func get_last_completed_job() -> JobRecord:
	return last_completed_job

func get_active_job_display_name() -> String:
	if active_record == null:
		return ""
	return active_record.display_name

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
	if not has_active_job() or current_dropoff != site:
		return
	var snapshot = await site.capture_snapshot()
	if snapshot == null:
		return
	if not has_active_job() or current_dropoff != site:
		return
	if active_record == null:
		return
	_set_record_snapshot(active_record, snapshot)
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
	elif dropoff != null:
		record.site_id = StringName(dropoff.name)
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
	var active = {}
	if active_record != null:
		active = _serialize_job_record(active_record)
	return {
		"completed_jobs": completed,
		"active_job": active
	}

func from_dict(data: Dictionary) -> void:
	completed_jobs.clear()
	var completed_data = data.get("completed_jobs", [])
	if typeof(completed_data) == TYPE_ARRAY:
		for entry in completed_data:
			if typeof(entry) == TYPE_DICTIONARY:
				completed_jobs.append(_deserialize_job_record(entry))
	last_completed_job = completed_jobs.back() if not completed_jobs.is_empty() else null
	_restore_active_job(data.get("active_job", {}), true)
	jobs_restored.emit()

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

func complete_active_job_for_dropoff(dropoff: Node3D) -> int:
	if not has_active_job():
		return 0
	if current_dropoff != dropoff:
		return 0
	return complete_job()

func _restore_active_job(data: Dictionary, emit_signal: bool) -> void:
	active_record = null
	current_dropoff = null
	if typeof(data) != TYPE_DICTIONARY or (data as Dictionary).is_empty():
		_set_carrying_state(false)
		if emit_signal:
			job_available.emit()
		return
	var record = _deserialize_job_record(data as Dictionary)
	if record == null:
		_set_carrying_state(false)
		if emit_signal:
			job_available.emit()
		return
	var dropoff = _resolve_dropoff_by_site_id(str(record.site_id))
	if dropoff == null:
		_set_carrying_state(false)
		if emit_signal:
			job_available.emit()
		return
	active_record = record
	current_dropoff = dropoff
	_set_carrying_state(true)
	if emit_signal:
		job_started.emit(dropoff)

func _clear_active_job_state() -> void:
	active_record = null
	current_dropoff = null
	_set_carrying_state(false)

func _set_carrying_state(active: bool) -> void:
	if active:
		PlayerData.set_carrying(DELIVERY_ITEM_NAME)
		return
	PlayerData.clear_carrying()

func _set_record_snapshot(record: JobRecord, snapshot: Texture2D) -> void:
	if record == null or snapshot == null:
		return
	record.snapshot = snapshot
	record.cache_snapshot()
