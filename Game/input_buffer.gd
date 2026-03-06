class_name InputBuffer
extends Resource

@export var BUFFER_WINDOW_MS = 150

var _buffer: Dictionary = {}

func press(action: StringName) -> void:
	_buffer[action] = Time.get_ticks_msec()

func has(action: StringName) -> bool:
	if not _buffer.has(action):
			return false
	return Time.get_ticks_msec() - _buffer[action] <= BUFFER_WINDOW_MS

func consume(action: StringName) -> bool:
	if not has(action):
			return false
	_buffer.erase(action)
	return true
