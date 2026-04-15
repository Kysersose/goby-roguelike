extends Area2D

const SPEED: float = 320.0
const MAX_RANGE: float = 520.0
const BASE_DAMAGE: float = 2.0

var _direction: Vector2 = Vector2.RIGHT
var _traveled: float = 0.0
var _damage: float = BASE_DAMAGE

func setup(dir: Vector2, bonus_damage: float = 0.0) -> void:
	_direction = dir.normalized()
	_damage = BASE_DAMAGE + bonus_damage

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	var step := _direction * SPEED * delta
	position += step
	_traveled += step.length()
	if _traveled >= MAX_RANGE:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		body.take_damage(_damage)
		queue_free()
