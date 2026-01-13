extends Control

signal close_requested

@onready var close_button: Button = $SnapshotPanel/SnapshotMargin/SnapshotVBox/SnapshotHeader/SnapshotCloseButton
@onready var snapshot_rect: TextureRect = (
	$SnapshotPanel/SnapshotMargin/SnapshotVBox/SnapshotRect
)

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	close_button.pressed.connect(func() -> void:
		close_requested.emit()
	)

func open(texture: Texture2D) -> void:
	if texture == null:
		return
	snapshot_rect.texture = texture
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.grab_focus()

func close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
