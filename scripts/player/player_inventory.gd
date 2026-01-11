extends Resource

class_name PlayerInventory

signal inventory_changed

@export var stacks: Array[InventoryStack] = []

var _suppress_signal: bool = false

func add_item(item: ItemData, amount: int) -> void:
	if item == null or amount <= 0:
		return
	var remaining = amount
	if item.max_stack <= 0:
		for stack in stacks:
			if stack == null or stack.item != item:
				continue
			stack.amount += remaining
			_emit_changed(true)
			return
		var new_stack := InventoryStack.new()
		new_stack.item = item
		new_stack.amount = remaining
		stacks.append(new_stack)
		_emit_changed(true)
		return
	var max_stack = max(1, item.max_stack)
	var changed = false
	for stack in stacks:
		if stack == null or stack.item != item:
			continue
		if stack.amount >= max_stack:
			continue
		var space = max_stack - stack.amount
		var to_add = min(space, remaining)
		stack.amount += to_add
		remaining -= to_add
		changed = true
		if remaining <= 0:
			_emit_changed(changed)
			return
	while remaining > 0:
		var stack_amount = min(max_stack, remaining)
		var new_stack := InventoryStack.new()
		new_stack.item = item
		new_stack.amount = stack_amount
		stacks.append(new_stack)
		remaining -= stack_amount
		changed = true
	_emit_changed(changed)

func remove_item(item: ItemData, amount: int) -> bool:
	if item == null or amount <= 0:
		return false
	var remaining = amount
	var changed = false
	for i in range(stacks.size() - 1, -1, -1):
		var stack = stacks[i]
		if stack == null or stack.item != item:
			continue
		var to_remove = min(stack.amount, remaining)
		stack.amount -= to_remove
		remaining -= to_remove
		changed = true
		if stack.amount <= 0:
			stacks.remove_at(i)
		if remaining <= 0:
			_emit_changed(changed)
			return true
	_emit_changed(changed)
	return false

func get_count(item: ItemData) -> int:
	if item == null:
		return 0
	var total = 0
	for stack in stacks:
		if stack != null and stack.item == item:
			total += stack.amount
	return total

func has_item(item: ItemData, amount: int = 1) -> bool:
	return get_count(item) >= amount

func clear() -> void:
	if stacks.is_empty():
		return
	stacks.clear()
	_emit_changed(true)

func to_dict() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for stack in stacks:
		if stack == null or stack.item == null:
			continue
		var item_id = String(stack.item.id)
		if item_id == "":
			continue
		data.append({
			"item_id": item_id,
			"amount": stack.amount
		})
	return data

func from_dict(data: Array, item_db: DatabaseTable) -> void:
	stacks.clear()
	if typeof(data) != TYPE_ARRAY or item_db == null:
		_emit_changed(true)
		return
	_suppress_signal = true
	for entry in data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var entry_dict = entry as Dictionary
		var item_id = StringName(str(entry_dict.get("item_id", "")))
		var amount = int(entry_dict.get("amount", 0))
		if amount <= 0:
			continue
		var item = item_db.get_by_id(item_id) as ItemData
		if item == null:
			continue
		add_item(item, amount)
	_suppress_signal = false
	_emit_changed(true)

func _emit_changed(changed: bool) -> void:
	if not changed or _suppress_signal:
		return
	inventory_changed.emit()
