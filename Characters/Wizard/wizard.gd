extends AbstractCharacter

var attacking := false

func make_attack() -> void:
	super.make_attack()
	attacking = true

func disable_attacking() -> void:
	attacking = false

func is_attacking() -> bool:
	return attacking

func is_dead() -> bool:
	return false

func took_damage() -> bool:
	return false
