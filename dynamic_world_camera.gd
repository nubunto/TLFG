extends Camera2D


@export var players: Array[CharacterBody2D]
@export var zoom_scale: Vector2
@export var zoom_timing: float
@export var position_timing: float
@export var distance_threshold: float

var original_zoom: Vector2

func _ready() -> void:
	original_zoom = zoom

func _process(_delta: float) -> void:
	if players.size() < 1:
		return

	var p1 := players[0]
	if players.size() == 1:
		global_position = global_position.lerp(p1.global_position, position_timing)
		return

	var p2 := players[1]
	
	global_position = global_position.lerp(p1.global_position, position_timing)

	var distance := p1.global_position.distance_squared_to(p2.global_position)
	if distance > distance_threshold:
		print_debug(distance)
		var tween = create_tween()
		tween.tween_property(self, "zoom", zoom_scale, zoom_timing)
	else:
		var tween = create_tween()
		tween.tween_property(self, "zoom", original_zoom, zoom_timing)
