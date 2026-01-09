extends Node

signal money_changed(amount: int)
signal carrying_changed(item_name: String)

var money: int = 0
var carrying_item: String = ""

func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)

func reset_money() -> void:
	money = 0
	money_changed.emit(money)

func spend_money(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	money_changed.emit(money)
	return true

func set_carrying(item_name: String) -> void:
	if _has_inventory():
		InventorySystem.add_delivery_item(item_name)
		carrying_item = InventorySystem.get_delivery_item_name()
		carrying_changed.emit(carrying_item)
		return
	carrying_item = item_name
	carrying_changed.emit(carrying_item)

func clear_carrying() -> void:
	if _has_inventory():
		InventorySystem.clear_delivery_item()
		carrying_item = ""
		carrying_changed.emit(carrying_item)
		return
	carrying_item = ""
	carrying_changed.emit(carrying_item)

func is_carrying() -> bool:
	if _has_inventory():
		return InventorySystem.has_delivery_item()
	return carrying_item != ""

func to_dict() -> Dictionary:
	return {
		"money": money,
		"carrying_item": carrying_item
	}

func from_dict(data: Dictionary) -> void:
	money = int(data.get("money", money))
	carrying_item = str(data.get("carrying_item", carrying_item))
	if _has_inventory() and carrying_item != "":
		InventorySystem.restore_legacy_delivery(carrying_item)
	money_changed.emit(money)
	carrying_changed.emit(carrying_item)

func _has_inventory() -> bool:
	return has_node("/root/InventorySystem")
