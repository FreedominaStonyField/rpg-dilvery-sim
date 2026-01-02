extends Resource

class_name JobRecord

@export var site_id: StringName
@export var display_name: String = ""
@export var hint_text: String = ""
@export var snapshot: Texture2D
@export var completion_sfx: AudioStream
@export var reward: int = 0
@export var distance_m: float = 0.0

var snapshot_jpg_b64: String = ""

func cache_snapshot(max_size: int = 256, quality: float = 0.6) -> void:
	if snapshot == null:
		snapshot_jpg_b64 = ""
		return
	var image = snapshot.get_image()
	if image == null or image.is_empty():
		snapshot_jpg_b64 = ""
		return
	if image.get_width() > max_size or image.get_height() > max_size:
		var width = image.get_width()
		var height = image.get_height()
		var scale = float(max_size) / float(max(width, height))
		var target_width = max(1, int(round(width * scale)))
		var target_height = max(1, int(round(height * scale)))
		image.resize(target_width, target_height, Image.INTERPOLATE_LANCZOS)
	var buffer = image.save_jpg_to_buffer(quality)
	snapshot_jpg_b64 = Marshalls.raw_to_base64(buffer)
