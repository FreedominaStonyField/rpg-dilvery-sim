extends Control

@onready var package_center: Control = $PackageCenter
@onready var package_menu: Control = $PackageCenter/PackageMenu
@onready var completion_audio: AudioStreamPlayer = (
	$PackageCenter/PackageMenu/CompletionAudioPlayer
)

var open_tween: Tween
var fade_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	package_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	package_menu.visible = false
	_set_menu_mouse_state(false)

func is_menu_visible() -> bool:
	return package_menu.visible

func show_menu(duration: float) -> void:
	if open_tween:
		open_tween.kill()
	package_menu.visible = true
	_set_menu_mouse_state(true)
	package_menu.modulate = Color(1, 1, 1, 0)
	open_tween = create_tween()
	open_tween.tween_property(
		package_menu,
		"modulate:a",
		1.0,
		duration
	).set_trans(Tween.TRANS_SINE)

func hide_menu(duration: float) -> void:
	if open_tween:
		open_tween.kill()
	if fade_tween:
		fade_tween.kill()
		fade_tween = null
	if duration <= 0.0:
		_reset_menu()
		return
	open_tween = create_tween()
	open_tween.tween_property(
		package_menu,
		"modulate:a",
		0.0,
		duration
	).set_trans(Tween.TRANS_SINE)
	open_tween.tween_callback(func() -> void:
		_reset_menu()
	)

func flash_fade(duration: float) -> void:
	if fade_tween:
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.tween_property(
		package_menu,
		"modulate:a",
		0.0,
		duration
	).set_trans(Tween.TRANS_SINE)
	fade_tween.tween_callback(func() -> void:
		_reset_menu()
		fade_tween = null
	)

func clear_override() -> void:
	if package_menu.has_method("clear_override"):
		package_menu.call("clear_override")

func focus_default() -> void:
	if package_menu.has_method("focus_default"):
		package_menu.call("focus_default")

func show_completed_job(job: JobRecord) -> void:
	if package_menu.has_method("show_completed_job"):
		package_menu.call("show_completed_job", job)

func hide_snapshot_overlay() -> void:
	var external_overlay = get_node_or_null("SnapshotOverlay")
	if external_overlay != null and external_overlay.has_method("close"):
		external_overlay.call("close")

func play_completion_sfx(job: JobRecord) -> void:
	if completion_audio == null or job == null:
		return
	if job.completion_sfx == null:
		return
	completion_audio.stream = job.completion_sfx
	completion_audio.play()

func _reset_menu() -> void:
	package_menu.visible = false
	package_menu.modulate = Color(1, 1, 1, 1)
	_set_menu_mouse_state(false)
	clear_override()

func _set_menu_mouse_state(visible: bool) -> void:
	var filter = Control.MOUSE_FILTER_STOP if visible else Control.MOUSE_FILTER_IGNORE
	package_center.mouse_filter = filter
	package_menu.mouse_filter = filter
