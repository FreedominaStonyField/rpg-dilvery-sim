extends Node3D

class_name DropoffSite

@export var site_id: StringName
@export var display_name: String = ""
@export var hint_text: String = ""
@export var enabled: bool = true
@export var snapshot_enabled: bool = false
@export var completion_sfx: AudioStream = preload("res://assets/audio/ui/bong_001.ogg")

@onready var snapshot_camera: Camera3D = get_node_or_null("SnapshotCamera")
@onready var snapshot_viewport: SubViewport = get_node_or_null("SnapshotViewport")
@onready var snapshot_viewport_camera: Camera3D = get_node_or_null(
    "SnapshotViewport/SnapshotViewportCamera"
)
@onready var label_3d: Label3D = get_node_or_null("Label3D")
@onready var label_area: Area3D = get_node_or_null("LabelArea")

var _snapshot_texture: Texture2D
var _player_in_label_range: bool = false

func _enter_tree() -> void:
	add_to_group("dropoff_sites")

func _exit_tree() -> void:
	remove_from_group("dropoff_sites")

func _ready() -> void:
	if site_id == &"":
		site_id = StringName(name)
		push_warning(
			"DropoffSite '%s' missing site_id. Defaulting to node name." % name
		)
	if label_3d != null:
		label_3d.visible = false
		_update_label_text()
	if label_area != null:
		label_area.body_entered.connect(_on_label_body_entered)
		label_area.body_exited.connect(_on_label_body_exited)
	Jobs.job_started.connect(_on_job_state_changed)
	Jobs.job_completed.connect(_on_job_state_changed)
	_update_label_visibility()

func capture_snapshot() -> Texture2D:
	if not snapshot_enabled:
		return null
	if snapshot_camera == null or snapshot_viewport == null:
		push_warning("DropoffSite '%s' missing snapshot camera or viewport." % name)
		return null
	if snapshot_viewport_camera == null:
		push_warning("DropoffSite '%s' missing snapshot viewport camera." % name)
		return null
	var main_viewport := get_viewport()
	snapshot_viewport.world_3d = main_viewport.world_3d
	snapshot_viewport.size = main_viewport.size
	_copy_camera_settings(snapshot_camera, snapshot_viewport_camera)
	var main_camera := main_viewport.get_camera_3d()
	if main_camera != null:
		snapshot_viewport_camera.environment = main_camera.environment
		snapshot_viewport_camera.attributes = main_camera.attributes
	snapshot_viewport_camera.current = true
	snapshot_viewport_camera.global_transform = snapshot_camera.global_transform
	snapshot_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await get_tree().process_frame
	snapshot_viewport_camera.global_transform = snapshot_camera.global_transform
	snapshot_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var viewport_texture := snapshot_viewport.get_texture()
	if viewport_texture == null:
		return null
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		return null
	_snapshot_texture = ImageTexture.create_from_image(image)
	return _snapshot_texture

func _copy_camera_settings(source: Camera3D, target: Camera3D) -> void:
	target.projection = source.projection
	target.fov = source.fov
	target.size = source.size
	target.near = source.near
	target.far = source.far
	target.keep_aspect = source.keep_aspect
	target.cull_mask = source.cull_mask

func _on_label_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in_label_range = true
		_update_label_visibility()

func _on_label_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in_label_range = false
		_update_label_visibility()

func _on_job_state_changed(_payload = null) -> void:
	_update_label_visibility()

func _update_label_visibility() -> void:
	if label_3d == null:
		return
	var should_show := _player_in_label_range
	if Jobs.has_active_job():
		should_show = should_show and Jobs.current_dropoff == self
	label_3d.visible = should_show

func _update_label_text() -> void:
	if label_3d == null:
		return
	label_3d.text = display_name if display_name != "" else name
