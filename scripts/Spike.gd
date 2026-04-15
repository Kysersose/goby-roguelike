extends Area2D

const SPEED: float = 200.0
const MAX_DISTANCE: float = 320.0
const DAMAGE: int = 4

var direction: Vector2 = Vector2.RIGHT
var source: Node = null

var _traveled: float = 0.0

func _ready() -> void:
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	var step := direction * SPEED * delta
	position += step
	_traveled += step.length()
	if _traveled >= MAX_DISTANCE:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body == source:
		return
	if body.is_in_group("player"):
		body.take_damage(DAMAGE)
		queue_free()
	elif body.is_in_group("normal_enemies"):
		body.take_damage(999.0, false)
		queue_free()
