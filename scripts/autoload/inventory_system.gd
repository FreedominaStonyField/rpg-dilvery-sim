extends Node

signal inventory_changed
signal item_added(item_id: String)
signal item_removed(item_id: String)
signal delivery_item_changed(item_name: String)

const DELIVERY_TAG = "delivery"
const JOB_TAG = "job"
const DELIVERY_ITEM_PREFIX = "delivery_package_"
const DEFAULT_DELIVERY_NAME = "Package"

var items: Array[Dictionary] = []

func add_item(item: Dictionary) -> void:
	var item_id = str(item.get("id", ""))
	if item_id == "":
		return
	var quantity = int(item.get("quantity", 1))
	if quantity <= 0:
		quantity = 1
	var index = _find_item_index(item_id)
	if index != -1:
		var current = int(items[index].get("quantity", 1))
		items[index]["quantity"] = current + quantity
		inventory_changed.emit()
		item_added.emit(item_id)
		_emit_delivery_change_if_needed(items[index])
		return
	var stored = item.duplicate(true)
	stored["id"] = item_id
	stored["quantity"] = quantity
	items.append(stored)
	inventory_changed.emit()
	item_added.emit(item_id)
	_emit_delivery_change_if_needed(stored)

func remove_item(item_id: String, amount: int = 1) -> bool:
	var index = _find_item_index(item_id)
	if index == -1:
		return false
	var target = items[index]
	var current = int(items[index].get("quantity", 1))
	var new_total = current - max(amount, 1)
	if new_total <= 0:
		items.remove_at(index)
	else:
		items[index]["quantity"] = new_total
	inventory_changed.emit()
	item_removed.emit(item_id)
	_emit_delivery_change_if_needed(target)
	return true

func discard_item(item_id: String) -> bool:
	var index = _find_item_index(item_id)
	if index == -1:
		return false
	var target = items[index]
	items.remove_at(index)
	inventory_changed.emit()
	item_removed.emit(item_id)
	_emit_delivery_change_if_needed(target)
	return true

func has_item(item_id: String) -> bool:
	return _find_item_index(item_id) != -1

func get_item(index: int) -> Dictionary:
	if index < 0 or index >= items.size():
		return {}
	return items[index]

func add_delivery_item(item_name: String, description: String = "") -> void:
	var name = item_name if item_name != "" else DEFAULT_DELIVERY_NAME
	var item_description = description if description != "" else "Delivery parcel."
	add_item({
		"id": DELIVERY_ITEM_PREFIX + str(Time.get_ticks_msec()),
		"name": name,
		"description": item_description,
		"quantity": 1,
		"tags": [JOB_TAG, DELIVERY_TAG],
		"meta": {}
	})

func add_delivery_job_item(job_id: String, dropoff_site_id: String, dropoff_name: String, reward: int, description: String, snapshot_path: String = "") -> void:
	var name = DEFAULT_DELIVERY_NAME
	var item_description = description if description != "" else "Delivery parcel."
	var item_id = DELIVERY_ITEM_PREFIX + job_id
	add_item({
		"id": item_id,
		"name": name,
		"description": item_description,
		"quantity": 1,
		"tags": [JOB_TAG, DELIVERY_TAG],
		"meta": {
			"job_id": job_id,
			"dropoff_site_id": dropoff_site_id,
			"dropoff_name": dropoff_name,
			"reward": reward,
			"snapshot_path": snapshot_path,
			"state": "ACTIVE"
		}
	})

func has_delivery_item() -> bool:
	return _find_delivery_index() != -1

func get_delivery_item_name() -> String:
	var index = _find_delivery_index()
	if index == -1:
		return ""
	return str(items[index].get("name", DEFAULT_DELIVERY_NAME))

func consume_delivery_item() -> bool:
	var index = _find_delivery_index()
	if index == -1:
		return false
	return remove_item(str(items[index].get("id", "")), 1)

func clear_delivery_item() -> void:
	var index = _find_delivery_index()
	if index == -1:
		return
	discard_item(str(items[index].get("id", "")))

func restore_legacy_delivery(item_name: String) -> void:
	if item_name == "" or has_delivery_item():
		return
	add_delivery_item(item_name)

func get_items_with_tag(tag: String) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for item in items:
		if _item_has_tag(item, tag):
			matches.append(item)
	return matches

func find_item_by_meta(key: String, value: String) -> Dictionary:
	for item in items:
		var meta = item.get("meta", {})
		if typeof(meta) != TYPE_DICTIONARY:
			continue
		if str(meta.get(key, "")) == value:
			return item
	return {}

func can_discard(item_id: String) -> bool:
	var index = _find_item_index(item_id)
	if index == -1:
		return false
	return not _item_has_tag(items[index], JOB_TAG)

func to_dict() -> Dictionary:
	return {
		"items": items
	}

func from_dict(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	if not data.has("items"):
		return
	var raw_items = data.get("items", [])
	if typeof(raw_items) != TYPE_ARRAY:
		return
	items.clear()
	for entry in raw_items:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item = (entry as Dictionary).duplicate(true)
		var item_id = str(item.get("id", ""))
		if item_id == "":
			continue
		item["id"] = item_id
		item["quantity"] = int(item.get("quantity", 1))
		items.append(item)
	inventory_changed.emit()
	delivery_item_changed.emit(get_delivery_item_name())

func _find_item_index(item_id: String) -> int:
	for i in range(items.size()):
		if str(items[i].get("id", "")) == item_id:
			return i
	return -1

func _find_delivery_index() -> int:
	for i in range(items.size()):
		if _item_has_tag(items[i], DELIVERY_TAG):
			return i
	return -1

func _item_has_tag(item: Dictionary, tag: String) -> bool:
	var tags = item.get("tags", [])
	if typeof(tags) != TYPE_ARRAY:
		return false
	for entry in tags:
		if str(entry) == tag:
			return true
	return false

func _emit_delivery_change_if_needed(item: Dictionary) -> void:
	if not _item_has_tag(item, DELIVERY_TAG):
		return
	delivery_item_changed.emit(get_delivery_item_name())
