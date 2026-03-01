extends GPUParticles2D

@onready var timer: Timer = $Timer

func _ready() -> void:
	self.emitting = true
	self.one_shot = true
	timer.start()

func on_finished() -> void:
	queue_free()
