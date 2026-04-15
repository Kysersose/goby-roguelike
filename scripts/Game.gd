extends Node2D

const SPAWN_RANGE: float = 450.0
const MIN_SPAWN_DIST: float = 150.0
const KELP_INTERVAL: float = 28.0
const ALGAE_INTERVAL: float = 30.0
const MINNOW_BASE_INTERVAL: float = 5.0
const SPAWN_SCALE_INTERVAL: float = 3.0

@onready var player = $Player
@onready var hud = $HUD

var _kelp_timer: float = KELP_INTERVAL
var _algae_timer: float = ALGAE_INTERVAL
var _minnow_timer: float = MINNOW_BASE_INTERVAL
var _minnow_interval: float = MINNOW_BASE_INTERVAL
var _spawn_scale_timer: float = SPAWN_SCALE_INTERVAL

var _normal_kills: int = 0
var _next_elite_at: int = 8

var _kelp_scene: PackedScene        = preload("res://scenes/Kelp.tscn")
var _algae_scene: PackedScene       = preload("res://scenes/Algae.tscn")
var _minnow_scene: PackedScene      = preload("res://scenes/Minnow.tscn")
var _spiked_snail_scene: PackedScene = preload("res://scenes/SpikedSnail.tscn")
var _upgrade_menu_scene: PackedScene = preload("res://scenes/UpgradeMenu.tscn")

func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_create_boundaries()
	player.health_changed.connect(hud.update_health)
	player.mana_changed.connect(hud.update_mana)
	player.experience_changed.connect(hud.update_experience)
	player.level_changed.connect(hud.update_level)
	player.level_changed.connect(_on_level_up)
	player.died.connect(hud.show_game_over)
	hud.set_player(player)

func _create_boundaries() -> void:
	var walls := [
		[Vector2(-2010, 0),  Vector2(20, 4040)],
		[Vector2(2010, 0),   Vector2(20, 4040)],
		[Vector2(0, -2010),  Vector2(4040, 20)],
		[Vector2(0, 2010),   Vector2(4040, 20)],
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

func _on_level_up(_level: int) -> void:
	get_tree().paused = true
	var menu := _upgrade_menu_scene.instantiate()
	menu.upgrade_chosen.connect(_on_upgrade_chosen)
	add_child(menu)

func _on_upgrade_chosen(stat: String, amount: float) -> void:
	player.apply_upgrade(stat, amount)
	get_tree().paused = false

func _on_normal_enemy_died(counted: bool) -> void:
	if not counted:
		return
	_normal_kills += 1
	if _normal_kills >= _next_elite_at:
		_spawn(_spiked_snail_scene)
		_next_elite_at += 8

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_P and event.pressed and not event.echo:
		hud.toggle_pause_menu()

func _process(delta: float) -> void:
	# Scale up spawn rate 3% every 3 seconds
	_spawn_scale_timer -= delta
	if _spawn_scale_timer <= 0.0:
		_minnow_interval = maxf(_minnow_interval * 0.98, 0.5)
		_spawn_scale_timer = SPAWN_SCALE_INTERVAL

	_kelp_timer -= delta
	if _kelp_timer <= 0.0:
		_spawn(_kelp_scene)
		_kelp_timer = KELP_INTERVAL

	_algae_timer -= delta
	if _algae_timer <= 0.0:
		_spawn(_algae_scene)
		_algae_timer = ALGAE_INTERVAL

	_minnow_timer -= delta
	if _minnow_timer <= 0.0:
		_spawn(_minnow_scene)
		_minnow_timer = _minnow_interval

func _spawn(scene: PackedScene) -> void:
	var instance = scene.instantiate()
	instance.position = _random_position()
	add_child(instance)
	if instance.is_in_group("normal_enemies") and instance.has_signal("died"):
		instance.died.connect(_on_normal_enemy_died)

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
