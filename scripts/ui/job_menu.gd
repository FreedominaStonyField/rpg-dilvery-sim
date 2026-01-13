extends PanelContainer

@onready var status_value: Label = $PackageMargin/PackageVBox/ManifestRow/DetailsPanel/DetailsMargin/DetailsVBox/StatusValue
@onready var location_value: Label = $PackageMargin/PackageVBox/ManifestRow/DetailsPanel/DetailsMargin/DetailsVBox/LocationValue
@onready var note_value: Label = $PackageMargin/PackageVBox/ManifestRow/DetailsPanel/DetailsMargin/DetailsVBox/NoteValue
@onready var reward_value: Label = $PackageMargin/PackageVBox/ManifestRow/DetailsPanel/DetailsMargin/DetailsVBox/RewardRow/RewardValue
@onready var snapshot_location: Label = $PackageMargin/PackageVBox/ManifestRow/SnapshotPanel/SnapshotMargin/SnapshotVBox/SnapshotLocation
@onready var snapshot_rect: TextureRect = $PackageMargin/PackageVBox/ManifestRow/SnapshotPanel/SnapshotMargin/SnapshotVBox/SnapshotRect
@onready var snapshot_button: Button = $PackageMargin/PackageVBox/ManifestRow/SnapshotPanel/SnapshotMargin/SnapshotVBox/SnapshotButton
@onready var no_active_block: Control = $PackageMargin/PackageVBox/ManifestRow/DetailsPanel/DetailsMargin/DetailsVBox/NoActiveBlock
@onready var offers_block: Control = $PackageMargin/PackageVBox/OffersBlock
@onready var offers_list: ItemList = $PackageMargin/PackageVBox/OffersBlock/OffersMargin/OffersVBox/OffersList
@onready var offers_empty: Label = $PackageMargin/PackageVBox/OffersBlock/OffersMargin/OffersVBox/OffersEmpty
@onready var offers_hint: Label = $PackageMargin/PackageVBox/OffersBlock/OffersMargin/OffersVBox/OffersHint
@onready var completed_list: ItemList = $PackageMargin/PackageVBox/CompletedBlock/CompletedMargin/CompletedVBox/CompletedList
@onready var completed_empty: Label = $PackageMargin/PackageVBox/CompletedBlock/CompletedMargin/CompletedVBox/CompletedEmpty
const SNAPSHOT_OVERLAY_SCENE: PackedScene = preload(
	"res://scenes/ui/screens/SnapshotOverlay.tscn"
)

const NO_JOB_STATUS = "NO ACTIVE JOB"
const ACTIVE_STATUS = "ACTIVE DELIVERY"
const COMPLETED_STATUS = "COMPLETED DELIVERY"
const AVAILABLE_STATUS = "JOB AVAILABLE"
const DROP_OFF_NONE = "--"
const NOTE_NONE = "--"
const REWARD_NONE = "--"

var override_job: JobRecord
var snapshot_overlay: Control

func _ready() -> void:
	Jobs.job_started.connect(_on_job_started)
	Jobs.job_completed.connect(_on_job_completed)
	Jobs.job_available.connect(_on_job_available)
	Jobs.job_snapshot_ready.connect(_on_job_snapshot_ready)
	Jobs.job_offers_updated.connect(_on_job_offers_updated)
	Jobs.jobs_restored.connect(_on_jobs_restored)
	offers_list.item_activated.connect(_on_offer_activated)
	snapshot_button.pressed.connect(_open_snapshot_overlay)
	visibility_changed.connect(_on_visibility_changed)
	mouse_filter = Control.MOUSE_FILTER_STOP
	offers_list.focus_mode = Control.FOCUS_ALL
	offers_list.mouse_filter = Control.MOUSE_FILTER_STOP
	completed_list.mouse_filter = Control.MOUSE_FILTER_STOP
	_configure_snapshot_rect()
	_refresh()
	_refresh_completed_list()
	_refresh_offers()

func focus_default() -> void:
	if offers_list.get_item_count() > 0:
		offers_list.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if snapshot_overlay != null and snapshot_overlay.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_snapshot_overlay()
		get_viewport().set_input_as_handled()
		return
	var wheel_event := event as InputEventMouseButton
	if wheel_event and wheel_event.pressed:
		if wheel_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_move_offer_selection(-1)
			get_viewport().set_input_as_handled()
			return
		if wheel_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_move_offer_selection(1)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up"):
		_move_offer_selection(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("move_backward") or event.is_action_pressed("ui_down"):
		_move_offer_selection(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		_activate_selected_offer()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		UIEvents.request_package_menu(false)
		get_viewport().set_input_as_handled()

func _refresh() -> void:
	if override_job != null:
		_set_completed(override_job)
		return
	if Jobs.has_active_job() and Jobs.current_dropoff != null:
		_set_active(Jobs.current_dropoff)
		return
	_set_idle(NO_JOB_STATUS)
	_refresh_offers()

func _set_active(dropoff: Node3D) -> void:
	status_value.text = ACTIVE_STATUS
	location_value.text = _get_dropoff_display_name(dropoff)
	note_value.text = _get_dropoff_note_text(dropoff)
	reward_value.text = _format_reward(Jobs.get_active_reward())
	snapshot_location.text = location_value.text
	snapshot_rect.texture = Jobs.get_active_snapshot()
	snapshot_rect.visible = snapshot_rect.texture != null
	snapshot_button.visible = snapshot_rect.visible
	_set_no_active_visible(false)
	offers_block.visible = false

func _set_completed(job: JobRecord) -> void:
	status_value.text = COMPLETED_STATUS
	location_value.text = _get_job_display_name(job)
	note_value.text = _get_job_note_text(job)
	reward_value.text = _format_reward(job.reward)
	snapshot_location.text = location_value.text
	snapshot_rect.texture = job.snapshot
	snapshot_rect.visible = snapshot_rect.texture != null
	snapshot_button.visible = snapshot_rect.visible
	_set_no_active_visible(false)
	offers_block.visible = false

func _set_idle(status_text: String) -> void:
	status_value.text = status_text
	location_value.text = DROP_OFF_NONE
	note_value.text = NOTE_NONE
	reward_value.text = REWARD_NONE
	snapshot_location.text = DROP_OFF_NONE
	snapshot_rect.texture = null
	snapshot_rect.visible = false
	snapshot_button.visible = false
	_set_no_active_visible(true)
	offers_block.visible = false

func _on_job_started(dropoff: Node3D) -> void:
	override_job = null
	_set_active(dropoff)
	_refresh_offers()

func _on_job_completed(_job: JobRecord) -> void:
	_refresh_completed_list()
	_refresh_offers()

func _on_job_available() -> void:
	if override_job != null:
		return
	if Jobs.has_active_job():
		return
	_set_idle(AVAILABLE_STATUS)
	_refresh_offers()

func _get_dropoff_display_name(dropoff: Node3D) -> String:
	if dropoff is DropoffSite:
		var site = dropoff as DropoffSite
		if site.display_name != "":
			return site.display_name
	return dropoff.name

func _get_dropoff_note_text(dropoff: Node3D) -> String:
	if dropoff is DropoffSite:
		var site = dropoff as DropoffSite
		if site.hint_text != "":
			return site.hint_text
	var hint_text = Jobs.get_active_hint_text()
	if hint_text != "":
		return hint_text
	return NOTE_NONE

func _on_job_snapshot_ready(snapshot: Texture2D) -> void:
	if override_job != null:
		return
	snapshot_rect.texture = snapshot
	snapshot_rect.visible = snapshot != null
	snapshot_button.visible = snapshot_rect.visible

func _on_jobs_restored() -> void:
	_refresh()
	_refresh_completed_list()
	_refresh_offers()

func _configure_snapshot_rect() -> void:
	snapshot_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	snapshot_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	snapshot_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	snapshot_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL

func show_completed_job(job: JobRecord) -> void:
	override_job = job
	if job != null:
		_set_completed(job)

func clear_override() -> void:
	override_job = null
	_refresh()

func _refresh_completed_list() -> void:
	completed_list.clear()
	for job in Jobs.get_completed_jobs():
		var label = "%s  [COMPLETED]" % _get_job_display_name(job)
		var icon = job.snapshot
		completed_list.add_item(label, icon)
		var index = completed_list.get_item_count() - 1
		completed_list.set_item_tooltip(index, _get_job_tooltip(job))
		completed_list.set_item_metadata(index, job)
	_update_completed_empty()

func _refresh_offers() -> void:
	offers_block.visible = false
	offers_list.clear()
	offers_list.visible = false
	offers_empty.visible = false
	offers_hint.visible = false

func _update_offer_hint() -> void:
	return

func _on_offer_activated(index: int) -> void:
	Jobs.accept_job_offer(index)

func _on_job_offers_updated() -> void:
	_refresh_offers()

func _move_offer_selection(delta: int) -> void:
	if offers_list.get_item_count() == 0:
		return
	var selected = offers_list.get_selected_items()
	var index = selected[0] if selected.size() > 0 else 0
	index = clamp(index + delta, 0, offers_list.get_item_count() - 1)
	offers_list.select(index)
	if offers_list.has_method("ensure_current_is_visible"):
		offers_list.ensure_current_is_visible()

func _activate_selected_offer() -> void:
	if offers_list.get_item_count() == 0:
		return
	var selected = offers_list.get_selected_items()
	var index = selected[0] if selected.size() > 0 else 0
	_on_offer_activated(index)

func _get_job_display_name(job: JobRecord) -> String:
	if job == null:
		return "--"
	if job.display_name != "":
		return job.display_name
	return "--"

func _get_job_note_text(job: JobRecord) -> String:
	if job == null:
		return NOTE_NONE
	if job.hint_text != "":
		return job.hint_text
	return NOTE_NONE

func _get_job_tooltip(job: JobRecord) -> String:
	var note = _get_job_note_text(job)
	if note == NOTE_NONE:
		return "NOTE: --"
	return "NOTE: %s" % note

func _format_reward(reward: int) -> String:
	if reward <= 0:
		return REWARD_NONE
	return "%d G" % reward

func _set_no_active_visible(visible: bool) -> void:
	if no_active_block:
		no_active_block.visible = visible

func _update_completed_empty() -> void:
	if completed_empty:
		completed_empty.visible = completed_list.get_item_count() == 0

func _open_snapshot_overlay() -> void:
	if snapshot_rect.texture == null:
		return
	if snapshot_overlay == null:
		snapshot_overlay = SNAPSHOT_OVERLAY_SCENE.instantiate()
		snapshot_overlay.name = "SnapshotOverlay"
		var screen_root = get_node_or_null("../..")
		if screen_root == null:
			add_child(snapshot_overlay)
		else:
			screen_root.add_child(snapshot_overlay)
		if snapshot_overlay.has_signal("close_requested"):
			snapshot_overlay.close_requested.connect(_close_snapshot_overlay)
	if snapshot_overlay.has_method("open"):
		snapshot_overlay.call("open", snapshot_rect.texture)

func _close_snapshot_overlay() -> void:
	if snapshot_overlay != null and snapshot_overlay.has_method("close"):
		snapshot_overlay.call("close")

func _on_visibility_changed() -> void:
	if not visible:
		if snapshot_overlay != null and snapshot_overlay.has_method("close"):
			snapshot_overlay.call("close")
