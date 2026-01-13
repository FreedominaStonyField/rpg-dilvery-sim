extends Control

signal resume_requested
signal save_requested
signal menu_requested

@onready var resume_button: Button = $PauseCenter/Panel/PauseMargin/PauseVBox/ResumeButton
@onready var save_button: Button = $PauseCenter/Panel/PauseMargin/PauseVBox/SaveButton
@onready var menu_button: Button = $PauseCenter/Panel/PauseMargin/PauseVBox/MenuButton

var fade_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resume_button.pressed.connect(func() -> void:
		resume_requested.emit()
	)
	save_button.pressed.connect(func() -> void:
		save_requested.emit()
	)
	menu_button.pressed.connect(func() -> void:
		menu_requested.emit()
	)

func show_menu(duration: float) -> void:
	if fade_tween:
		fade_tween.kill()
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true
	modulate = Color(1, 1, 1, 0)
	fade_tween = create_tween()
	fade_tween.tween_property(
		self,
		"modulate:a",
		1.0,
		duration
	).set_trans(Tween.TRANS_SINE)

func hide_menu(duration: float) -> void:
	if fade_tween:
		fade_tween.kill()
	if not visible:
		return
	fade_tween = create_tween()
	fade_tween.tween_property(
		self,
		"modulate:a",
		0.0,
		duration
	).set_trans(Tween.TRANS_SINE)
	fade_tween.tween_callback(func() -> void:
		visible = false
		modulate = Color(1, 1, 1, 1)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	)
