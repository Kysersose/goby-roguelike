extends CharacterBody2D

const SPEED: float = 150.0

func _physics_process(_delta: float) -> void:
	var input_vector := Vector2(
		float(int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A))),
		float(int(Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_W)))
	)

	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()

	velocity = input_vector * SPEED
	move_and_slide()

	if input_vector != Vector2.ZERO:
		rotation = input_vector.angle()
