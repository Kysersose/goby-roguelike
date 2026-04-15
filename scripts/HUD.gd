extends CanvasLayer

@onready var health_bar: ProgressBar = $Control/HealthBar
@onready var health_label: Label = $Control/HealthLabel
@onready var mana_bar: ProgressBar = $Control/ManaBar
@onready var mana_label: Label = $Control/ManaLabel
@onready var xp_label: Label = $Control/XPLabel
@onready var level_label: Label = $Control/LevelLabel
@onready var game_over_label: Label = $Control/GameOverLabel
@onready var pause_menu: Control = $Control/PauseMenu

var _game_over: bool = false

func _ready() -> void:
	var hp_fill = StyleBoxFlat.new()
	hp_fill.bg_color = Color.RED
	health_bar.add_theme_stylebox_override("fill", hp_fill)

	var mp_fill = StyleBoxFlat.new()
	mp_fill.bg_color = Color(0.2, 0.5, 1.0)
	mana_bar.add_theme_stylebox_override("fill", mp_fill)
	$Control/PauseMenu/ResumeButton.pressed.connect(_on_resume_pressed)
	$Control/PauseMenu/SaveRunButton.pressed.connect(_on_save_run_pressed)
	$Control/PauseMenu/SettingsButton.pressed.connect(_on_settings_pressed)
	$Control/PauseMenu/ExitButton.pressed.connect(_on_exit_pressed)

func update_health(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "%d / %d" % [current, maximum]

func update_mana(current: int, maximum: int) -> void:
	mana_bar.max_value = maximum
	mana_bar.value = current
	mana_label.text = "%d / %d MP" % [current, maximum]

func update_experience(current: int, needed: int) -> void:
	xp_label.text = "XP: %d / %d" % [current, needed]

func update_level(lvl: int) -> void:
	level_label.text = "Level: %d" % lvl

func show_game_over() -> void:
	_game_over = true
	game_over_label.visible = true
	get_tree().paused = true

func toggle_pause_menu() -> void:
	if _game_over:
		return
	var pausing := not get_tree().paused
	get_tree().paused = pausing
	pause_menu.visible = pausing

func _on_resume_pressed() -> void:
	toggle_pause_menu()

func _on_save_run_pressed() -> void:
	pass # TODO: implement save system

func _on_settings_pressed() -> void:
	pass # TODO: implement settings screen

func _on_exit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/Game.tscn")
