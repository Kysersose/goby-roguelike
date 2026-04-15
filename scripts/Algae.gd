extends Area2D

const HEAL_AMOUNT: int = 5

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.heal(HEAL_AMOUNT)
		queue_free()
