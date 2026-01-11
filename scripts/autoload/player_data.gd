extends Node

signal money_changed(amount: int)
signal inventory_changed

@export var item_database_path: String = "res://data/databases/items"

const MONEY_ITEM_ID: StringName = &"money"

var inventory: PlayerInventory = PlayerInventory.new()
var item_database: DatabaseTable
var _money_cache: int = 0

func _ready() -> void:
	_ensure_item_database()
	inventory.inventory_changed.connect(_on_inventory_changed)
	_refresh_money_cache(true)

func add_money(amount: int) -> void:
	if amount <= 0:
		return
	add_item_by_id(MONEY_ITEM_ID, amount)

func reset_money() -> void:
	remove_all_of_item_id(MONEY_ITEM_ID)
	_refresh_money_cache(true)

func spend_money(amount: int) -> bool:
	if amount <= 0:
		return true
	if get_money() < amount:
		return false
	return remove_item_by_id(MONEY_ITEM_ID, amount)

func add_item_by_id(item_id: StringName, amount: int) -> void:
	var item = get_item_by_id(item_id)
	if item == null:
		return
	inventory.add_item(item, amount)

func remove_item_by_id(item_id: StringName, amount: int) -> bool:
	var item = get_item_by_id(item_id)
	if item == null:
		return false
	return inventory.remove_item(item, amount)

func remove_all_of_item_id(item_id: StringName) -> void:
	var item = get_item_by_id(item_id)
	if item == null:
		return
	var count = inventory.get_count(item)
	if count > 0:
		inventory.remove_item(item, count)

func ensure_item_count(item_id: StringName, amount: int) -> void:
	var item = get_item_by_id(item_id)
	if item == null:
		return
	var current = inventory.get_count(item)
	if current < amount:
		inventory.add_item(item, amount - current)
	elif current > amount:
		inventory.remove_item(item, current - amount)

func has_item_id(item_id: StringName, amount: int = 1) -> bool:
	var item = get_item_by_id(item_id)
	if item == null:
		return false
	return inventory.has_item(item, amount)

func get_item_count(item_id: StringName) -> int:
	var item = get_item_by_id(item_id)
	if item == null:
		return 0
	return inventory.get_count(item)

func get_item_by_id(item_id: StringName) -> ItemData:
	_ensure_item_database()
	if item_database == null:
		return null
	return item_database.get_by_id(item_id) as ItemData

func get_money() -> int:
	return get_item_count(MONEY_ITEM_ID)

func to_dict() -> Dictionary:
	return {
		"money": get_money(),
		"inventory": inventory.to_dict()
	}

func from_dict(data: Dictionary) -> void:
	_ensure_item_database()
	inventory.from_dict(data.get("inventory", []), item_database)
	var legacy_money = int(data.get("money", 0))
	if legacy_money > 0 and get_money() <= 0:
		ensure_item_count(MONEY_ITEM_ID, legacy_money)
	_refresh_money_cache(true)

func _ensure_item_database() -> void:
	if item_database != null:
		return
	item_database = DatabaseLoader.load_table(item_database_path)

func _on_inventory_changed() -> void:
	_refresh_money_cache(false)
	inventory_changed.emit()

func _refresh_money_cache(force_emit: bool) -> void:
	var current = get_money()
	if force_emit or current != _money_cache:
		_money_cache = current
		money_changed.emit(current)
