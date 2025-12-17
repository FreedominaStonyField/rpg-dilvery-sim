extends Node

signal notify(message: String, duration: float)

func show_message(message: String, duration: float = 2.0) -> void:
    notify.emit(message, duration)
