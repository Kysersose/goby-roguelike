extends Control

# 0.0 = ready (nothing drawn), 1.0 = full cooldown (full dark circle)
var progress: float = 0.0 : set = _set_progress

func _set_progress(val: float) -> void:
	progress = clampf(val, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	if progress <= 0.0:
		return
	var center := size / 2.0
	# Radius large enough to cover the full square slot
	var radius := (size * 1.05).length() / 2.0
	var start_angle := -PI / 2.0
	var sweep := progress * TAU
	var steps := 48
	var points := PackedVector2Array()
	points.append(center)
	for i in steps + 1:
		var angle := start_angle + sweep * float(i) / float(steps)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.65))
