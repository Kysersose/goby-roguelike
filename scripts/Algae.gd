extends Area2D

const MANA_AMOUNT: int = 3

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.restore_mana(MANA_AMOUNT)
		queue_free()
