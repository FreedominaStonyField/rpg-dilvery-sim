extends Control

signal midpoint_reached
signal finished

@onready var fade_rect: ColorRect = $FadeRect
@onready var transition_panel: PanelContainer = $TransitionPanel
@onready var transition_label: Label = $TransitionPanel/TransitionMargin/TransitionLabel

var transition_tween: Tween

func _ready() -> void:
	visible = true
	fade_rect.visible = false
	fade_rect.color = Color(0, 0, 0, 0)
	transition_panel.visible = false
	transition_panel.modulate = Color(1, 1, 1, 0)

func play_transition(
	message: String,
	is_mugged: bool,
	fade_duration: float,
	hold_duration: float,
	alert_text_color: Color,
	rest_text_color: Color
) -> void:
	fade_rect.visible = true
	fade_rect.color = Color(0, 0, 0, 0)
	transition_panel.visible = true
	transition_label.text = message
	transition_label.modulate = Color(1, 1, 1, 1)
	transition_label.add_theme_color_override(
		"font_color",
		alert_text_color if is_mugged else rest_text_color
	)
	transition_panel.modulate = Color(1, 1, 1, 0)
	if transition_tween:
		transition_tween.kill()
	transition_tween = create_tween()
	transition_tween.tween_property(fade_rect, "color:a", 1.0, fade_duration)
	transition_tween.tween_property(transition_panel, "modulate:a", 1.0, 0.25)
	transition_tween.tween_callback(func() -> void:
		midpoint_reached.emit()
	)
	transition_tween.tween_interval(hold_duration)
	transition_tween.tween_property(fade_rect, "color:a", 0.0, fade_duration)
	transition_tween.tween_property(transition_panel, "modulate:a", 0.0, 0.2)
	transition_tween.tween_callback(_finish_transition)

func _finish_transition() -> void:
	fade_rect.visible = false
	transition_panel.visible = false
	finished.emit()
