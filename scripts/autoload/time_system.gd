extends Node

signal time_changed(day_time: float)
signal curfew_started
signal mugged
signal new_morning

@export var day_length: float = 900.0
@export var curfew_ratio: float = 1.0
@export var mug_delay: float = 3.0

var day_time: float = 0.0
var current_day: int = 0
var outdoors: bool = true
var inn_paused: bool = false
var pending_curfew: bool = false
var day_complete: bool = false
var _mug_timer: float = 30.0

func _ready() -> void:
	day_time = 0.0
	time_changed.emit(day_time)

func _process(delta: float) -> void:
	if not GameState.is_playing():
		return
	if inn_paused:
		return
	_advance_time(delta)
	if day_complete:
		return
	_check_curfew(delta)

func set_outdoors(value: bool) -> void:
	outdoors = value
	if not outdoors and pending_curfew:
		pending_curfew = false
		_mug_timer = 0.0
	if outdoors and day_time >= curfew_ratio and not pending_curfew:
		_start_curfew_timer()

func set_inn_paused(value: bool) -> void:
	inn_paused = value

func reset_day() -> void:
	start_new_day()

func start_new_day() -> void:
	day_time = 0.0
	day_complete = false
	pending_curfew = false
	_mug_timer = 0.0
	current_day += 1
	time_changed.emit(day_time)
	new_morning.emit()

func get_time_ratio() -> float:
	return day_time

func _advance_time(delta: float) -> void:
	if day_complete:
		return
	var delta_ratio := delta / day_length
	day_time = clamp(day_time + delta_ratio, 0.0, 1.0)
	time_changed.emit(day_time)

func _check_curfew(delta: float) -> void:
	if day_time >= curfew_ratio and not pending_curfew and outdoors:
		_start_curfew_timer()
	if pending_curfew and outdoors and not inn_paused:
		_mug_timer -= delta
		if _mug_timer <= 0.0:
			_trigger_mugged()

func _start_curfew_timer() -> void:
	if not outdoors:
		return
	pending_curfew = true
	_mug_timer = mug_delay
	UIEvents.show_message("Curfew! Get indoors.")
	curfew_started.emit()

func _trigger_mugged() -> void:
	if day_complete:
		return
	day_complete = true
	pending_curfew = false
	GameState.set_mode(GameState.Mode.MUGGED)
	mugged.emit()
