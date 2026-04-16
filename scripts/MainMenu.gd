extends Control

@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	_apply_custom_cursor()

# Builds a 48x48 hollow red ring and sets it as the OS cursor.
# Persists across scene changes for the rest of the session.
func _apply_custom_cursor() -> void:
	var size := 48
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5 - 0.5, size * 0.5 - 0.5)
	var outer_radius := 12.0
	var inner_radius := 9.0
	var ring_color := Color(1.0, 0.15, 0.15, 1.0)
	var transparent := Color(1, 1, 1, 0)
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(center)
			if d > inner_radius and d <= outer_radius:
				img.set_pixel(x, y, ring_color)
			else:
				img.set_pixel(x, y, transparent)
	var tex := ImageTexture.create_from_image(img)
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, Vector2(size * 0.5, size * 0.5))

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_settings_pressed() -> void:
	# Placeholder — settings menu will be implemented later.
	pass

func _on_quit_pressed() -> void:
	get_tree().quit()
