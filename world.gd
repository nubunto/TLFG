extends Node2D

@export var screenshake_noise: FastNoiseLite
@export var event_bus: EventBus

@onready var main_camera: Camera2D = $MainCamera
var _original_offset: Vector2
var _in_screenshake := false

func _ready() -> void:
	DamageDirector.damage.connect(_on_screenshake_damage)
	event_bus.screen.screen_shake.connect(_on_screenshake)
	_original_offset = main_camera.offset

func _process(_delta: float) -> void:
	if Input.is_key_pressed(KEY_F1):
		DamageDirector.damage.emit(1)
	if Input.is_key_pressed(KEY_F2):
		event_bus.screen.screen_shake.emit()

func _on_screenshake() -> void:
	if _in_screenshake: return
	make_screenshake()

func _on_screenshake_damage(_damage: int) -> void:
	if _in_screenshake: return
	make_screenshake()

func make_screenshake() -> void:
	_original_offset = main_camera.offset
	_in_screenshake = true
	var tween := create_tween()
	tween.tween_method(_make_screenshake, .3, .8, .4)
	await tween.finished
	_in_screenshake = false
	_reset_camera()
	
func _reset_camera() -> void:
	main_camera.offset = _original_offset

func _make_screenshake(intensity_scalar: float) -> void:
	var x_offset := screenshake_noise.get_noise_2d(randf_range(0, 128), randf_range(0, 128))
	var y_offset := screenshake_noise.get_noise_2d(randf_range(0, 128), randf_range(0, 128))
	main_camera.offset.x += (x_offset * intensity_scalar)
	main_camera.offset.y += (y_offset * intensity_scalar)
