extends Node

signal inventory_changed
signal item_added(item_id: String)
signal item_removed(item_id: String)
signal delivery_item_changed(item_name: String)

const DELIVERY_ITEM_ID = "delivery_package"
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
		_emit_delivery_change_if_needed(item_id)
		return
	var stored = item.duplicate(true)
	stored["id"] = item_id
	stored["quantity"] = quantity
	items.append(stored)
	inventory_changed.emit()
	item_added.emit(item_id)
	_emit_delivery_change_if_needed(item_id)

func remove_item(item_id: String, amount: int = 1) -> bool:
	var index = _find_item_index(item_id)
	if index == -1:
		return false
	var current = int(items[index].get("quantity", 1))
	var new_total = current - max(amount, 1)
	if new_total <= 0:
		items.remove_at(index)
	else:
		items[index]["quantity"] = new_total
	inventory_changed.emit()
	item_removed.emit(item_id)
	_emit_delivery_change_if_needed(item_id)
	return true

func discard_item(item_id: String) -> bool:
	var index = _find_item_index(item_id)
	if index == -1:
		return false
	items.remove_at(index)
	inventory_changed.emit()
	item_removed.emit(item_id)
	_emit_delivery_change_if_needed(item_id)
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
		"id": DELIVERY_ITEM_ID,
		"name": name,
		"description": item_description,
		"quantity": 1
	})

func has_delivery_item() -> bool:
	return has_item(DELIVERY_ITEM_ID)

func get_delivery_item_name() -> String:
	var index = _find_item_index(DELIVERY_ITEM_ID)
	if index == -1:
		return ""
	return str(items[index].get("name", DEFAULT_DELIVERY_NAME))

func consume_delivery_item() -> bool:
	return remove_item(DELIVERY_ITEM_ID, 1)

func clear_delivery_item() -> void:
	discard_item(DELIVERY_ITEM_ID)

func restore_legacy_delivery(item_name: String) -> void:
	if item_name == "" or has_delivery_item():
		return
	add_delivery_item(item_name)

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

func _emit_delivery_change_if_needed(item_id: String) -> void:
	if item_id != DELIVERY_ITEM_ID:
		return
	delivery_item_changed.emit(get_delivery_item_name())
