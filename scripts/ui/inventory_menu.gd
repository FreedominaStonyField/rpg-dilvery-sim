extends PanelContainer

@onready var item_list: ItemList = $MenuMargin/MenuVBox/BodyRow/ItemPanel/ItemMargin/ItemVBox/ItemList
@onready var detail_text: RichTextLabel = (
	$MenuMargin/MenuVBox/BodyRow/DetailPanel/DetailMargin/DetailVBox/DetailText
)
@onready var discard_button: Button = (
	$MenuMargin/MenuVBox/BodyRow/DetailPanel/DetailMargin/DetailVBox/ActionRow/DiscardButton
)
@onready var close_button: Button = (
	$MenuMargin/MenuVBox/BodyRow/DetailPanel/DetailMargin/DetailVBox/ActionRow/CloseButton
)

var selected_item_id: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InventorySystem.inventory_changed.connect(_refresh)
	item_list.item_selected.connect(_on_item_selected)
	item_list.item_activated.connect(_on_item_activated)
	discard_button.pressed.connect(_on_discard_pressed)
	close_button.pressed.connect(_on_close_pressed)
	_refresh()

func focus_default() -> void:
	if item_list.item_count > 0:
		item_list.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("move_forward"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("move_backward"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		_on_discard_pressed()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func _refresh() -> void:
	item_list.clear()
	selected_item_id = ""
	for item in InventorySystem.items:
		var label = str(item.get("name", "Unknown"))
		var quantity = int(item.get("quantity", 1))
		if quantity > 1:
			label += " x%d" % quantity
		item_list.add_item(label)
	if item_list.item_count > 0:
		item_list.select(0)
		_on_item_selected(0)
	else:
		detail_text.text = "No items."
		discard_button.disabled = true

func _on_item_selected(index: int) -> void:
	var item = InventorySystem.get_item(index)
	selected_item_id = str(item.get("id", ""))
	var item_name = str(item.get("name", "Unknown"))
	var item_desc = str(item.get("description", ""))
	detail_text.text = "[b]%s[/b]\n\n%s" % [item_name, item_desc]
	discard_button.disabled = selected_item_id == ""

func _on_item_activated(_index: int) -> void:
	_on_discard_pressed()

func _on_discard_pressed() -> void:
	if selected_item_id == "":
		return
	InventorySystem.discard_item(selected_item_id)
	UIEvents.show_message("Discarded item.")

func _on_close_pressed() -> void:
	UIEvents.request_inventory_menu(false)

func _move_selection(delta: int) -> void:
	if item_list.item_count == 0:
		return
	var selected = item_list.get_selected_items()
	var index = selected[0] if selected.size() > 0 else 0
	index = clamp(index + delta, 0, item_list.item_count - 1)
	item_list.select(index)
	_on_item_selected(index)
