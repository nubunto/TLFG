extends Node2D

var noise: FastNoiseLite = FastNoiseLite.new()

func _ready() -> void:
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.05

func _process(_delta: float) -> void:
	var noise_value = noise.get_noise_1d(randf() * 1.5)
	print(noise_value, " ", noise_value)
