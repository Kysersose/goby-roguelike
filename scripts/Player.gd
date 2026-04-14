extends CharacterBody2D

const SPEED: float = 150.0
const TARGET_SIZE: float = 128.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _last_anim: String = "swim_down"

func _ready() -> void:
	var tex := sprite.sprite_frames.get_frame_texture(_last_anim, 0)
	if tex != null:
		var size := tex.get_size()
		var longest := maxf(size.x, size.y)
		if longest > 0.0:
			var s := TARGET_SIZE / longest
			sprite.scale = Vector2(s, s)
	sprite.play(_last_anim)
	sprite.pause()

func _physics_process(_delta: float) -> void:
	var to_mouse := get_global_mouse_position() - global_position
	var holding := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	if holding and to_mouse.length() > 1.0:
		var dir := to_mouse.normalized()
		velocity = dir * SPEED

		var anim: String
		if absf(dir.x) > absf(dir.y):
			anim = "swim_right" if dir.x > 0.0 else "swim_left"
		else:
			anim = "swim_down" if dir.y > 0.0 else "swim_up"

		if anim != _last_anim:
			_last_anim = anim
			sprite.play(anim)
		elif not sprite.is_playing():
			sprite.play(anim)
	else:
		velocity = Vector2.ZERO
		sprite.pause()

	move_and_slide()
