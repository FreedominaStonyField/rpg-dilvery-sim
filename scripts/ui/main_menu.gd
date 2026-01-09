extends Control

@onready var start_button: Button = $UI_Layer/LayoutRoot/Split/MenuColumn/StartBtn
@onready var quit_button: Button = $UI_Layer/LayoutRoot/Split/MenuColumn/QuitBtn
@onready var load_button: Button = $UI_Layer/LayoutRoot/Split/MenuColumn/LoadBtn
@onready var slot_list: ItemList = $UI_Layer/LayoutRoot/Split/MenuColumn/SlotList

func _ready() -> void:
	get_tree().paused = false
	GameState.set_mode(GameState.Mode.MENU)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	start_button.grab_focus()
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	load_button.pressed.connect(_on_load_pressed)
	slot_list.item_activated.connect(_on_slot_activated)
	_refresh_slot_list()

func _on_start_pressed() -> void:
	GameState.set_mode(GameState.Mode.PLAYING)
	get_tree().change_scene_to_file("res://scenes/world/World.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_load_pressed() -> void:
	var slot_name = _get_selected_slot_name()
	if slot_name == "":
		return
	SaveSystem.load_slot(slot_name)

func _on_slot_activated(index: int) -> void:
	slot_list.select(index)
	_on_load_pressed()

func _refresh_slot_list() -> void:
	slot_list.clear()
	var slots = SaveSystem.list_slots()
	for slot in slots:
		var name = str(slot.get("file_name", ""))
		var day = str(slot.get("current_day", 0))
		var money = str(slot.get("money", 0))
		var label = "%s | Day %s | $%s" % [name, day, money]
		slot_list.add_item(label)
		var index = slot_list.get_item_count() - 1
		slot_list.set_item_metadata(index, name)
	load_button.disabled = slot_list.item_count == 0
	if slot_list.item_count > 0:
		slot_list.select(0)

func _get_selected_slot_name() -> String:
	var index = slot_list.get_selected_items()
	if index.is_empty():
		return ""
	var slot_name = slot_list.get_item_metadata(index[0])
	return str(slot_name)
