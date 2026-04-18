extends Node2D

const SPAWN_RANGE: float = 450.0
const MIN_SPAWN_DIST: float = 150.0
const MINNOW_BASE_INTERVAL: float = 5.5
const SPAWN_SCALE_INTERVAL: float = 3.0
const BOSS_SPAWN_TIME: float = 300.0
const SEAWEED_COUNT: int = 10
const SEAWEED_MAP_RANGE: float = 1600.0
const SEAWEED_MIN_DIST: float = 250.0
const SEAWEED_SPACING: float = 400.0

@onready var player = $Player
@onready var hud = $HUD

var _minnow_timer: float = MINNOW_BASE_INTERVAL
var _minnow_interval: float = MINNOW_BASE_INTERVAL
var _spawn_scale_timer: float = SPAWN_SCALE_INTERVAL

var _normal_kills: int = 0
var _next_elite_at: int = 8

var _minnow_scene: PackedScene        = preload("res://scenes/Minnow.tscn")
var _seaweed_scene: PackedScene       = preload("res://scenes/Seaweed.tscn")
var _barracuda_scene: PackedScene     = preload("res://scenes/Barracuda.tscn")
var _spiked_snail_scene: PackedScene  = preload("res://scenes/SpikedSnail.tscn")
var _upgrade_menu_scene: PackedScene  = preload("res://scenes/UpgradeMenu.tscn")
var _boss_reward_scene: PackedScene   = preload("res://scenes/BossRewardMenu.tscn")

var _seaweed_nodes: Array = []
var _boss_timer: float = BOSS_SPAWN_TIME
var _boss_spawned: bool = false
var _boss_active: bool = false

func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_create_boundaries()
	_place_seaweed()
	player.health_changed.connect(hud.update_health)
	player.mana_changed.connect(hud.update_mana)
	player.stamina_changed.connect(hud.update_stamina)
	player.experience_changed.connect(hud.update_experience)
	player.level_changed.connect(hud.update_level)
	player.level_changed.connect(_on_level_up)
	player.died.connect(hud.show_game_over)
	player.ability_slot_changed.connect(hud.update_ability_slot)
	hud.set_player(player)

func _place_seaweed() -> void:
	var placed: Array = []
	for _i in SEAWEED_COUNT:
		var pos := _random_seaweed_position(placed)
		var sw := _seaweed_scene.instantiate()
		sw.position = pos
		add_child(sw)
		_seaweed_nodes.append(sw)
		placed.append(pos)

func _random_seaweed_position(existing: Array) -> Vector2:
	for _i in 60:
		var pos := Vector2(
			randf_range(-SEAWEED_MAP_RANGE, SEAWEED_MAP_RANGE),
			randf_range(-SEAWEED_MAP_RANGE, SEAWEED_MAP_RANGE)
		)
		if pos.length() < SEAWEED_MIN_DIST:
			continue
		var too_close := false
		for other in existing:
			if pos.distance_to(other) < SEAWEED_SPACING:
				too_close = true
				break
		if not too_close:
			return pos
	return Vector2(SEAWEED_MAP_RANGE, SEAWEED_MAP_RANGE)

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
	menu.luck = player.luck
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
	# Scale up spawn rate 1% every 3 seconds
	_spawn_scale_timer -= delta
	if _spawn_scale_timer <= 0.0:
		_minnow_interval = maxf(_minnow_interval * 0.99, 0.5)
		_spawn_scale_timer = SPAWN_SCALE_INTERVAL

	if not _boss_active:
		_minnow_timer -= delta
		if _minnow_timer <= 0.0:
			_spawn_minnow()
			_minnow_timer = _minnow_interval

	if not _boss_spawned:
		_boss_timer -= delta
		if _boss_timer <= 0.0:
			_boss_spawned = true
			_spawn_barracuda()

func _spawn_barracuda() -> void:
	_boss_active = true
	_dismiss_enemies()
	var boss := _barracuda_scene.instantiate()
	boss.position = _random_position()
	add_child(boss)
	boss.died.connect(_on_barracuda_died)

func _dismiss_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if enemy.is_in_group("normal_enemies") and enemy.has_method("flee"):
			enemy.flee()
		elif enemy.is_in_group("elite_enemies") and enemy.has_method("hide_in_sand"):
			enemy.hide_in_sand()

func _spawn_minnow() -> void:
	if _seaweed_nodes.is_empty():
		return
	var sw: Node2D = _seaweed_nodes[randi() % _seaweed_nodes.size()]
	if not is_instance_valid(sw):
		return
	var m := _minnow_scene.instantiate()
	m.position = sw.get_spawn_position()
	add_child(m)
	m.died.connect(_on_normal_enemy_died)

func _spawn(scene: PackedScene) -> void:
	var instance = scene.instantiate()
	instance.position = _random_position()
	add_child(instance)
	if instance.is_in_group("normal_enemies") and instance.has_signal("died"):
		instance.died.connect(_on_normal_enemy_died)

func _on_barracuda_died() -> void:
	_boss_active = false
	get_tree().paused = true
	var menu := _boss_reward_scene.instantiate()
	menu.setup(player)
	menu.reward_chosen.connect(_on_boss_reward_chosen)
	add_child(menu)

func _on_boss_reward_chosen(type: String, slot: int) -> void:
	match type:
		"rapid_dash":
			player.has_rapid_dash = true
		"chomp":
			player.assign_ability_to_slot(slot, "chomp")
		"status_upgrade":
			# Reuse level-up upgrade menu as a free pick
			var menu := _upgrade_menu_scene.instantiate()
			menu.luck = player.luck
			menu.upgrade_chosen.connect(_on_upgrade_chosen)
			add_child(menu)
			return  # stay paused until upgrade is chosen
	get_tree().paused = false

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
