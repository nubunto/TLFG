extends Node2D


@export_range(1, 10) var enemy_count := 10
@export var horizontal_range := 150.0
@export var EnemyScene: PackedScene

func _ready():
	for i in range(0, enemy_count):
		var enemy = EnemyScene.instantiate()
		self.add_child(enemy)
		enemy.position.x = randf_range(-horizontal_range, horizontal_range)
