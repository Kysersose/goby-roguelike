extends Node2D

const FLOAT_SPEED: float = 55.0
const LIFETIME: float = 0.9
const FONT_SIZE: int = 16

var _timer: float = 0.0
var _text: String = ""
var _color: Color = Color.WHITE

func setup(amount, dmg_color: Color = Color.WHITE) -> void:
	_text = str(amount)
	_color = dmg_color

func _ready() -> void:
	z_index = 100

func _process(delta: float) -> void:
	_timer += delta
	position.y -= FLOAT_SPEED * delta
	modulate.a = maxf(1.0 - (_timer / LIFETIME), 0.0)
	queue_redraw()
	if _timer >= LIFETIME:
		queue_free()

func _draw() -> void:
	if _text.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	draw_string_outline(font, Vector2.ZERO, _text, HORIZONTAL_ALIGNMENT_CENTER, -1, FONT_SIZE, 3, Color.BLACK)
	draw_string(font, Vector2.ZERO, _text, HORIZONTAL_ALIGNMENT_CENTER, -1, FONT_SIZE, _color)
