extends PanelContainer

@onready var offers_list: ItemList = $OfferMargin/OfferVBox/OfferRow/LeftColumn/OffersList
@onready var offers_empty: Label = $OfferMargin/OfferVBox/OfferRow/LeftColumn/OffersEmpty
@onready var snapshot_rect: TextureRect = $OfferMargin/OfferVBox/OfferRow/RightColumn/SnapshotPanel/SnapshotRect
@onready var reward_label: Label = $OfferMargin/OfferVBox/OfferRow/RightColumn/RewardLabel
@onready var accept_button: Button = $OfferMargin/OfferVBox/ButtonsRow/AcceptButton
@onready var cancel_button: Button = $OfferMargin/OfferVBox/ButtonsRow/CancelButton
@onready var warning_layer: Control = $WarningLayer
@onready var warning_snapshot: TextureRect = (
	$WarningLayer/WarningPanel/WarningMargin/WarningVBox/WarningSnapshot
)
@onready var warning_text: Label = $WarningLayer/WarningPanel/WarningMargin/WarningVBox/WarningText
@onready var warning_hint: Label = $WarningLayer/WarningPanel/WarningMargin/WarningVBox/WarningHint
@onready var warning_accept: Button = (
	$WarningLayer/WarningPanel/WarningMargin/WarningVBox/WarningButtons/ConfirmButton
)
@onready var warning_back: Button = (
	$WarningLayer/WarningPanel/WarningMargin/WarningVBox/WarningButtons/BackButton
)

var selected_index: int = -1

func _ready() -> void:
	Jobs.job_offers_updated.connect(_refresh_offers)
	Jobs.job_available.connect(_refresh_offers)
	Jobs.job_started.connect(_on_job_started)
	offers_list.item_selected.connect(_on_offer_selected)
	offers_list.item_activated.connect(_on_offer_activated)
	accept_button.pressed.connect(_on_accept_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	warning_accept.pressed.connect(_on_warning_accept)
	warning_back.pressed.connect(_on_warning_back)
	mouse_filter = Control.MOUSE_FILTER_STOP
	offers_list.focus_mode = Control.FOCUS_ALL
	offers_list.mouse_filter = Control.MOUSE_FILTER_STOP
	_configure_snapshot(snapshot_rect)
	_configure_snapshot(warning_snapshot)
	_refresh_offers()
	_hide_warning()

func focus_default() -> void:
	if offers_list.get_item_count() > 0:
		offers_list.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if warning_layer.visible:
		if event.is_action_pressed("ui_cancel"):
			_hide_warning()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		UIEvents.request_job_offer_menu(false)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		_on_accept_pressed()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_up"):
		_move_offer_selection(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_down"):
		_move_offer_selection(1)
		get_viewport().set_input_as_handled()
		return

func _refresh_offers() -> void:
	offers_list.clear()
	selected_index = -1
	if Jobs.has_active_job():
		_set_empty_state("Finish your current job before taking another.")
		return
	if not Jobs.has_offer_pickup():
		_set_empty_state("Find a parcel pickup to browse dispatch offers.")
		return
	var offers = Jobs.get_job_offer_records()
	if offers.is_empty():
		_set_empty_state("No offers yet. Try another pickup.")
		return
	offers_empty.visible = false
	offers_list.visible = true
	for job in offers:
		var label = "$%d  %s" % [job.reward, _get_job_display_name(job)]
		offers_list.add_item(label, job.snapshot)
	if offers_list.get_item_count() > 0:
		selected_index = 0
		offers_list.select(0)
	_update_selected_offer()

func _set_empty_state(message: String) -> void:
	offers_list.visible = false
	offers_empty.visible = true
	offers_empty.text = message
	snapshot_rect.texture = null
	reward_label.text = "Reward: --"
	accept_button.disabled = true

func _update_selected_offer() -> void:
	var job = _get_selected_job()
	if job == null:
		snapshot_rect.texture = null
		reward_label.text = "Reward: --"
		accept_button.disabled = true
		return
	snapshot_rect.texture = job.snapshot
	reward_label.text = "Reward: $%d" % job.reward
	accept_button.disabled = false

func _on_offer_selected(index: int) -> void:
	selected_index = index
	_update_selected_offer()

func _on_offer_activated(index: int) -> void:
	selected_index = index
	_show_warning_for_selected()

func _on_accept_pressed() -> void:
	_show_warning_for_selected()

func _on_cancel_pressed() -> void:
	UIEvents.request_job_offer_menu(false)

func _show_warning_for_selected() -> void:
	var job = _get_selected_job()
	if job == null:
		return
	warning_snapshot.texture = job.snapshot
	warning_text.text = "Accepting locks you in. You cannot take another job until complete."
	warning_hint.text = "Lost? Head to the tower or any high point to get your bearings."
	warning_layer.visible = true
	warning_accept.grab_focus()

func _hide_warning() -> void:
	warning_layer.visible = false

func _on_warning_accept() -> void:
	if selected_index < 0:
		return
	var accepted = Jobs.accept_job_offer(selected_index)
	if accepted:
		_hide_warning()
		UIEvents.request_job_offer_menu(false)

func _on_warning_back() -> void:
	_hide_warning()
	offers_list.grab_focus()

func _move_offer_selection(delta: int) -> void:
	if offers_list.get_item_count() == 0:
		return
	var index = selected_index if selected_index >= 0 else 0
	index = clamp(index + delta, 0, offers_list.get_item_count() - 1)
	selected_index = index
	offers_list.select(index)
	if offers_list.has_method("ensure_current_is_visible"):
		offers_list.ensure_current_is_visible()
	_update_selected_offer()

func _on_job_started(_dropoff: Node3D) -> void:
	_refresh_offers()

func _get_selected_job() -> JobRecord:
	if selected_index < 0:
		return null
	var offers = Jobs.get_job_offer_records()
	if selected_index >= offers.size():
		return null
	return offers[selected_index]

func _get_job_display_name(job: JobRecord) -> String:
	if job == null:
		return "--"
	if job.display_name != "":
		return job.display_name
	return "--"

func _configure_snapshot(rect: TextureRect) -> void:
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
