extends Node2D

const SPAWN_OFFSET: float = 35.0

func get_spawn_position() -> Vector2:
	return global_position + Vector2(
		randf_range(-SPAWN_OFFSET, SPAWN_OFFSET),
		randf_range(-SPAWN_OFFSET, SPAWN_OFFSET)
	)

func _draw() -> void:
	# 4 tall green rectangle stalks, scaled 5x
	var stalks := [
		Rect2(-70, -290, 35, 290),
		Rect2(-25, -360, 35, 360),
		Rect2(20,  -315, 35, 315),
		Rect2(65,  -250, 35, 250),
	]
	for r in stalks:
		draw_rect(r, Color(0.13, 0.62, 0.22))
