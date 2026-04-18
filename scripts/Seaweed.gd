extends Node2D

const SPAWN_OFFSET: float = 35.0
const HEAL_CONTACT_TIME: float = 1.0
const HEAL_AMOUNT: int = 4
const COLOR_ACTIVE: Color = Color(0.13, 0.62, 0.22)
const COLOR_DEPLETED: Color = Color(0.4, 0.25, 0.1)

var _depleted: bool = false
var _player_inside: bool = false
var _contact_timer: float = 0.0
var _draw_color: Color = COLOR_ACTIVE

@onready var _area: Area2D = $Area2D

func _ready() -> void:
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		_contact_timer = 0.0

func _process(delta: float) -> void:
	if _depleted or not _player_inside:
		return
	_contact_timer += delta
	if _contact_timer >= HEAL_CONTACT_TIME:
		var player := get_tree().get_first_node_in_group("player")
		if player != null:
			player.heal(HEAL_AMOUNT)
		_depleted = true
		_player_inside = false
		_draw_color = COLOR_DEPLETED
		queue_redraw()

func get_spawn_position() -> Vector2:
	return global_position + Vector2(
		randf_range(-SPAWN_OFFSET, SPAWN_OFFSET),
		randf_range(-SPAWN_OFFSET, SPAWN_OFFSET)
	)

func _draw() -> void:
	var stalks := [
		Rect2(-70, -290, 35, 290),
		Rect2(-25, -360, 35, 360),
		Rect2(20,  -315, 35, 315),
		Rect2(65,  -250, 35, 250),
	]
	for r in stalks:
		draw_rect(r, _draw_color)
