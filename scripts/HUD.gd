extends CanvasLayer

@onready var health_bar: ProgressBar = $Control/HealthBar
@onready var health_label: Label = $Control/HealthLabel
@onready var xp_label: Label = $Control/XPLabel
@onready var level_label: Label = $Control/LevelLabel
@onready var game_over_label: Label = $Control/GameOverLabel

func _ready() -> void:
	var fill = StyleBoxFlat.new()
	fill.bg_color = Color.RED
	health_bar.add_theme_stylebox_override("fill", fill)

func update_health(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "%d / %d" % [current, maximum]

func update_experience(current: int, needed: int) -> void:
	xp_label.text = "XP: %d / %d" % [current, needed]

func update_level(lvl: int) -> void:
	level_label.text = "Level: %d" % lvl

func show_game_over() -> void:
	game_over_label.visible = true
	get_tree().paused = true
