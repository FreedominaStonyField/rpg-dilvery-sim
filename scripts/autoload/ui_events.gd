extends Node

signal notify(message: String, duration: float)
signal sleep_sequence_requested(message: String)

func show_message(message: String, duration: float = 2.0) -> void:
    notify.emit(message, duration)

func request_sleep_sequence(message: String = "You got a good night's sleep.") -> void:
    sleep_sequence_requested.emit(message)
