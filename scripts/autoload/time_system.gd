extends Node

signal time_changed(day_time: float)
signal curfew_started
signal mugged
signal new_morning

@export var day_length: float = 180.0
@export var curfew_ratio: float = 0.8
@export var mug_delay: float = 3.0

var day_time: float = 0.0
var outdoors: bool = true
var inn_paused: bool = false
var pending_curfew: bool = false
var _mug_timer: float = 0.0

func _ready() -> void:
    day_time = 0.0
    time_changed.emit(day_time)

func _process(delta: float) -> void:
    if not GameState.is_playing():
        return
    if inn_paused:
        return
    _advance_time(delta)
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
    day_time = 0.0
    pending_curfew = false
    _mug_timer = 0.0
    time_changed.emit(day_time)
    new_morning.emit()

func _advance_time(delta: float) -> void:
    var delta_ratio := delta / day_length
    day_time = clamp(day_time + delta_ratio, 0.0, 1.0)
    time_changed.emit(day_time)
    if day_time >= 1.0 and not pending_curfew:
        reset_day()

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
    pending_curfew = false
    mugged.emit()
    PlayerData.reset_money()
    PlayerData.clear_carrying()
    Jobs.cancel_job()
    UIEvents.show_message("Mugged! Money lost.")
    GameState.set_mode(GameState.Mode.MUGGED)
    reset_day()
    GameState.set_mode(GameState.Mode.PLAYING)
