extends RefCounted

class_name DatabaseLoader

static func load_table(folder_path: String) -> DatabaseTable:
	var table := DatabaseTable.new()
	var dir := DirAccess.open(folder_path)
	if dir == null:
		push_error("DatabaseLoader: Missing folder %s" % folder_path)
		return table
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path = folder_path.path_join(file_name)
			var entry = load(path)
			if entry is DatabaseEntry:
				table.entries.append(entry)
			else:
				push_error("DatabaseLoader: %s is not a DatabaseEntry." % path)
		file_name = dir.get_next()
	dir.list_dir_end()
	_validate_unique_ids(table, folder_path)
	return table

static func _validate_unique_ids(table: DatabaseTable, folder_path: String) -> void:
	var seen: Dictionary = {}
	for entry in table.entries:
		if entry == null:
			continue
		var entry_id = String(entry.id)
		if entry_id == "":
			push_error("DatabaseLoader: Entry missing id in %s" % folder_path)
			continue
		if seen.has(entry_id):
			push_error("DatabaseLoader: Duplicate id '%s' in %s" % [entry_id, folder_path])
			continue
		seen[entry_id] = true
