extends Control

@onready var offer_center: Control = $OfferCenter
@onready var job_offer_menu: Control = $OfferCenter/JobOfferMenu

var open_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	job_offer_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	job_offer_menu.visible = false
	_set_menu_mouse_state(false)

func show_menu(duration: float) -> void:
	if open_tween:
		open_tween.kill()
	job_offer_menu.visible = true
	_set_menu_mouse_state(true)
	job_offer_menu.modulate = Color(1, 1, 1, 0)
	if job_offer_menu.has_method("focus_default"):
		job_offer_menu.call("focus_default")
	open_tween = create_tween()
	open_tween.tween_property(
		job_offer_menu,
		"modulate:a",
		1.0,
		duration
	).set_trans(Tween.TRANS_SINE)

func hide_menu(duration: float) -> void:
	if open_tween:
		open_tween.kill()
	if duration <= 0.0:
		_reset_menu()
		return
	open_tween = create_tween()
	open_tween.tween_property(
		job_offer_menu,
		"modulate:a",
		0.0,
		duration
	).set_trans(Tween.TRANS_SINE)
	open_tween.tween_callback(func() -> void:
		_reset_menu()
	)

func is_menu_visible() -> bool:
	return job_offer_menu.visible

func _reset_menu() -> void:
	job_offer_menu.visible = false
	job_offer_menu.modulate = Color(1, 1, 1, 1)
	_set_menu_mouse_state(false)

func _set_menu_mouse_state(visible: bool) -> void:
	var filter = Control.MOUSE_FILTER_STOP if visible else Control.MOUSE_FILTER_IGNORE
	offer_center.mouse_filter = filter
	job_offer_menu.mouse_filter = filter
