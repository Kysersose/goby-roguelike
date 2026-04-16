extends Control

@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_settings_pressed() -> void:
	# Placeholder — settings menu will be implemented later.
	pass

func _on_quit_pressed() -> void:
	get_tree().quit()
