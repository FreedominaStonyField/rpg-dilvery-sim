extends Resource

class_name DatabaseTable

@export var entries: Array[DatabaseEntry] = []

func get_by_id(entry_id: StringName) -> DatabaseEntry:
	if entry_id == StringName():
		return null
	for entry in entries:
		if entry != null and entry.id == entry_id:
			return entry
	return null

func has_id(entry_id: StringName) -> bool:
	return get_by_id(entry_id) != null
