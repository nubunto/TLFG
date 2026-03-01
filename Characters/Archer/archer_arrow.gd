extends Hitbox

@export var speed := 200.0
@export var piercing := false
@export var lifetime_in_seconds := 10.0
@export var min_lifetime := 3.0

@onready var lifetime: Timer = $Lifetime
@onready var sprite: Sprite2D = $Sprite2D
@onready var arrow_tip: Marker2D = $ArrowTip

var direction := 0

func _ready() -> void:
	lifetime.wait_time = max(lifetime_in_seconds, min_lifetime)
	lifetime.start()
	if direction == 0:
		direction = 1
	if direction == -1:
		sprite.flip_h = true
		arrow_tip.position.x *= -1

func _process(delta: float) -> void:
	position.x += (direction * speed) * delta

func _on_timer_timeout() -> void:
	queue_free()

func on_hit(node) -> void:
	node.on_damage(self.damage)
	for effect in hit_effects:
		var instance = effect.trigger(self, arrow_tip.global_position)
		if instance and instance.process_material:
			instance.process_material.direction.x = direction
	queue_free()

func on_hit_solid(_node) -> void:
	queue_free()
