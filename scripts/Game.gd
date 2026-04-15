extends Node2D

const SPAWN_RANGE: float = 450.0
const MIN_SPAWN_DIST: float = 150.0
const ALGAE_INTERVAL: float = 10.0
const MINNOW_INTERVAL: float = 5.0

@onready var player = $Player
@onready var hud = $HUD

var _algae_timer: float = ALGAE_INTERVAL
var _minnow_timer: float = MINNOW_INTERVAL

var _algae_scene: PackedScene = preload("res://scenes/Algae.tscn")
var _minnow_scene: PackedScene = preload("res://scenes/Minnow.tscn")

func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_create_boundaries()
	player.health_changed.connect(hud.update_health)
	player.experience_changed.connect(hud.update_experience)
	player.level_changed.connect(hud.update_level)
	player.died.connect(hud.show_game_over)

func _create_boundaries() -> void:
	var walls := [
		[Vector2(-2010, 0),  Vector2(20, 4040)],  # left
		[Vector2(2010, 0),   Vector2(20, 4040)],  # right
		[Vector2(0, -2010),  Vector2(4040, 20)],  # top
		[Vector2(0, 2010),   Vector2(4040, 20)],  # bottom
	]
	for wall in walls:
		var body := StaticBody2D.new()
		body.position = wall[0]
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = wall[1]
		col.shape = shape
		body.add_child(col)
		add_child(body)

func _process(delta: float) -> void:
	_algae_timer -= delta
	if _algae_timer <= 0.0:
		_spawn(_algae_scene)
		_algae_timer = ALGAE_INTERVAL

	_minnow_timer -= delta
	if _minnow_timer <= 0.0:
		_spawn(_minnow_scene)
		_minnow_timer = MINNOW_INTERVAL

func _spawn(scene: PackedScene) -> void:
	var instance = scene.instantiate()
	instance.position = _random_position()
	add_child(instance)

func _random_position() -> Vector2:
	var pos: Vector2
	for _i in 30:
		pos = Vector2(
			randf_range(-SPAWN_RANGE, SPAWN_RANGE),
			randf_range(-SPAWN_RANGE, SPAWN_RANGE)
		)
		if player.global_position.distance_to(pos) >= MIN_SPAWN_DIST:
			return pos
	return pos
